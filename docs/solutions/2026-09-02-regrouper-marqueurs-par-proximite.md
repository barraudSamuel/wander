---
title: "Regrouper les marqueurs sociaux par proximité géographique"
date: 2026-09-02
last_updated: 2026-09-08
category: architecture
tags: [solution, mapkit, clustering, core-location, annotations, ux]
related_plan: "../plans/2026-09-02-garantir-clusters-h3-visibles.md"
---

# Regrouper les marqueurs sociaux par proximité géographique

## Problem

Le compte courant, les amis et les événements représentant un même lieu réel
devaient rester regroupés à tous les niveaux de zoom. À l'inverse, deux lieux
distincts devaient rester séparés même si leurs marqueurs se superposaient à un
fort dézoom.

## Root cause

Le clustering natif de MapKit répond à la collision de vues en points et non à
une distance géographique. Sa composition change donc avec la caméra. Une
cellule H3 de résolution 10 est stable géographiquement mais trop grande pour
représenter un établissement et introduit une frontière arbitraire entre deux
positions proches.

Construire directement un `MKClusterAnnotation` ne remplace pas ce mécanisme :
ce type et son identifiant interne appartiennent à MapKit. Un groupe métier
stable doit être une annotation applicative ordinaire.

## Solution

Depuis l'extraction locale du sprint 01, `MapSocialProximityState` possède les
règles, l'historique des paires, l'identité des groupes et le membre sélectionné.
`MapSocialProximityController` conserve les annotations sources séparément des
représentants attachés à la carte et possède la sélection/restauration native.
`MapWithFogView.Coordinator` assemble les sources et les présentations puis lui
transmet les callbacks, sans conserver un second état des groupes.
À chaque changement de composition ou de coordonnées sociales :

1. les distances Core Location de chaque paire sont calculées une seule fois ;
2. les groupes sont fusionnés de façon déterministe seulement si chaque paire
   de la fusion respecte sa limite, ce qui interdit les chaînes de proximité ;
3. une paire nouvelle peut se regrouper jusqu'à 20 mètres ;
4. une paire déjà regroupée reste liée jusqu'à 25 mètres pour absorber le bruit
   GPS ;
5. les associations déjà retenues sont reconstruites en priorité afin qu'un
   nouveau voisin ne déstabilise pas un groupe encore valide ;
6. un groupe d'au moins deux membres devient un
   `MapSocialProximityGroupAnnotation`, tandis qu'un membre isolé conserve son
   annotation source ;
7. un représentant existant est réutilisé selon le recouvrement de ses membres
   pour conserver l'état ouvert et éviter les clignotements.

Les sources sont comparées dans un ordre canonique. Leurs distances de paires
sont réutilisées lors des changements de focus ; la révision de l'état évite
de réappliquer une composition inchangée à MapKit. Les callbacks de caméra
rafraîchissent les vues sans recalculer la proximité. Un geste qui désélectionne
un membre peut toutefois restaurer sa composition : l'indépendance au zoom ne
signifie pas que toute action de caméra doit ignorer le cycle de sélection.

Toutes les vues sociales ont `clusteringIdentifier = nil` et une priorité
requise. `MapSocialClusterAnnotationView` conserve sa pile compacte et sa liste
verticale, mais elle présente désormais l'annotation applicative. Lorsqu'un
membre est choisi, sa vraie annotation est temporairement attachée séparément ;
les autres membres gardent leur représentant et le groupe complet est restauré
à la désélection.

## What did not work

- Le clustering visuel natif : sa composition varie avec le zoom.
- H3 résolution 10 : sa zone est trop large pour signifier « même café ».
- Une résolution H3 plus fine : deux personnes proches peuvent rester de part
  et d'autre d'une frontière de cellule.
- Une simple connexité à 20 mètres : une chaîne de personnes peut réunir des
  extrémités éloignées de plus de 20 mètres.
- Un seuil unique : les oscillations GPS autour de la limite font clignoter le
  groupe.
- Des `MKClusterAnnotation` construites par l'application : leur gestion interne
  appartient à MapKit.

## Validation historique du 2 septembre 2026

- Build Debug réussi pour le simulateur iOS.
- Fixture temporaire validée sur l'iPhone 17 Simulator iOS 26.3 puis retirée.
- Groupe mixte compte, ami et événement créé à 19 mètres.
- Composition inchangée aux zooms rue, ville et monde.
- Groupe conservé à 24 mètres puis séparé à 26 mètres.
- Paire initiale à 21 mètres laissée indépendante.
- Cas 0 m / 15 m / 30 m validé sans groupe unique par effet de chaîne.
- Tous les représentants sont restés visibles avec priorité requise.
- Build final réussi après le retrait complet de la fixture, puis application
  réinstallée et lancée normalement sur le simulateur actif.
- `git diff --check` réussi après la revue finale.

## Validation de l'extraction du 5 septembre 2026

La cible `wanderTests` contient 18 tests de règles et 7 tests d'intégration
utilisant un vrai `MKMapView`, les annotations et les vues de groupe. Les
25 tests et l'analyse Xcode passent sur l'iPhone 17 Pro existant, iOS 26.3.
La compilation finale des tests ne produit plus de diagnostic Swift.

Les tests ont révélé deux contraintes du cycle natif : une annotation déjà
visible ne produit pas forcément de callback `didAdd` lors de sa sélection,
et la libération d'un contrôleur à destruction isolée synthétisée peut planter
sur le runtime utilisé. La sélection reprend donc immédiatement si la vue
existe ; un `nonisolated deinit` explicite évite le chemin Swift défaillant,
tandis que `tearDown` conserve le nettoyage sur l'acteur principal.
La trace et le contournement correspondent à
[swiftlang/swift#88036](https://github.com/swiftlang/swift/issues/88036).

Ces tests ne passent pas par l'observateur de taps du Coordinator ni par les
callbacks produit de `ContentView`. Les gestes réels et VoiceOver restent à
confirmer : le lancement normal du simulateur affiche la connexion Apple.
Cette validation partielle et les commandes exactes sont consignées dans
le [plan du sprint 01](../plans/2026-09-05-architecture-carte-sociale-sprint-01.md).
L'extraction est locale, sans commit ni publication à ce stade.

## Historique du correctif local du 7 septembre 2026

Cette section décrit la validation disponible le 7 septembre. Les retours
suivants ont montré que ce correctif ne suffisait pas ; la reproduction tactile
et son résultat actuel sont consignés plus bas.

Une vidéo utilisateur montre une sélection qui revient au groupe. La lecture
du contrôleur révèle que le passage direct A → B restaure d'abord un groupe
sans focus, ce qui retire A et B de MapKit, puis focalise B sans synchronisation.
Les tests existants utilisaient surtout un groupe de trois membres ; ils ne
couvraient pas cette transition d'une paire ni le remplacement de l'objet
natif déjà sélectionné.

Le correctif local dans `MapSocialProximityController` remplace cette séquence
par `changeFocus(to:on:)` : publier le membre final, désélectionner l'ancien,
appliquer une seule composition, puis notifier sa fermeture produit. La source
remplaçante de même identifiant reprend la sélection native sans fermer sa fiche.
Une génération invalide les actions différées périmées ; la demande reste
en attente jusqu'à son activation native. La désélection native est réévaluée
sur la file principale, après une éventuelle sélection du membre suivant.
Le passage membre → groupe libère explicitement l'ancien focus et sa fiche ;
le passage groupe → membre ferme explicitement le groupe ouvert. Ces transitions
ne dépendent donc pas d'un ancien callback invalidé par la génération suivante.

`MapWithFogView.Coordinator` ne ferme plus directement la fiche depuis chaque
`didDeselect`. Il reçoit `onDeselectMember` du contrôleur. Il distingue les
gestes actifs de la carte des recentrages automatiques ; le délai d'une seconde
qui protégeait auparavant la caméra est supprimé. Le tap sur le fond appelle
explicitement `collapse`, même si la sélection native est encore en attente.

Sept tests de régression s'ajoutent aux sept tests d'intégration du contrôleur.
La compilation finale de l'app et des tests réussit sans diagnostic.
Leur exécution, la reproduction causale de la vidéo, le pont de gestes complet
et VoiceOver restent à effectuer : Samuel a choisi de poursuivre sans tests
sur simulateur. Les résultats du 2 et du 5 septembre ci-dessus sont historiques,
et ne prouvent pas ce nouveau correctif. Les commandes de compilation et la revue
sont consignées dans le plan du sprint 01 et le todo 025.

## Historique de la première reprise tactile du 8 septembre 2026

Cette première reprise précède le scénario local approuvé. Le retour suivant
de Samuel signale une dégradation ; les tests cités ici ne validaient pas le
parcours tactile complet.

La nouvelle vidéo montre que la fiche du deuxième événement se referme encore
avant l'édition. Avec deux lignes, la deuxième recouvre presque entièrement
les bounds natifs du marqueur compact, contrairement à la première. La ligne
et la carte peuvent donc traiter le même toucher ; une désélection native
après activation suffit à reformer le groupe. Cet ordre précis des callbacks
reste une hypothèse à confirmer sur l'iPhone.

Chaque rangée possède maintenant un `UITapGestureRecognizer` dont le delegate
donne priorité au tap de la rangée sur ceux de ses vues ancêtres. Le recognizer
active la ligne et annule la livraison physique de `touchUpInside` ; le
target/action du contrôle et les actions VoiceOver restent disponibles.
Ce traitement n'introduit pas de temporisation et ne remplace aucun delegate
interne MapKit. Les gestes qui ne sont pas des taps n'attendent pas la rangée.

Deux nouveaux tests couvrent la sélection via chaque contrôle, la priorité
gestuelle et le retrait de chaque événement exactement superposé. Ils sont
compilés sans être exécutés et ne synthétisent pas le tap physique. Le rapport
de validation exact figure dans le plan du sprint 01. Cette maintenance de la
note ne constitue pas un nouvel apprentissage déclaré vérifié.

Le retour suivant de Samuel signale un tap de fond ignoré immédiatement après
l'ouverture du groupe. L'observateur passif se terminait en `.failed` après
chaque tap valide, état que UIKit peut conserver jusqu'à la fin de la séquence.
Il reste maintenant `.possible` après le callback et conserve ses échecs sur
déplacement, second doigt et annulation. Cette modification ne force pas de
reset UIKit et ne désactive aucun geste MapKit.

Trois tests de callbacks passent sur l'iPhone avant le changement : ils ne
reproduisent pas l'arbitrage natif et ne prouvent pas la résolution du délai.
Après la modification, les 37 tests de carte sociale passent sur l'iPhone
le 8 septembre à 09:58:54 et l'app est relancée sans débogueur.
La validation physique de la fermeture immédiate reste nécessaire, avec le
double tap, le panoramique et le pincement. Le plan conserve le résultat exact
des suites et les limites du diagnostic.

## Réouverture native reproduite sur simulateur le 8 septembre 2026

Le scénario `DebugSocialMapScenario` permet de rejouer les gestes sur la vraie
carte, avec les vraies fiches et le formulaire d'événement, y compris la
confirmation d'annulation. Il est compilé seulement en Debug sur simulateur
et activé par `-debug-social-map`. Les utilisateurs, événements, opérations et
le conteneur SwiftData restent en mémoire. Les services réels et
l'authentification restent les valeurs par défaut du lancement normal.

La trace avant correction montre que `touchesEnded` reçoit le deuxième tap,
63 ms puis 113 ms après l'ouverture. La fermeture synchrone appelle `collapse`,
puis MapKit émet `didDeselect` et `didSelect` pour le même groupe, qui se rouvre.
Cette trace invalide l'hypothèse d'un deuxième toucher absent. Preuve :
`/private/tmp/wander-rapid-native-reselection-before.log`.

La fermeture est désormais exécutée par `DispatchQueue.main.async`, après le
traitement synchrone de la séquence, sans délai fixe.
`socialPressGeneration` et `presentationRevision` empêchent une fermeture
périmée après un nouvel appui, une sélection de membre, une action accessible
ou le démontage de la carte. Le maintien de l'observateur en `.possible` après
un tap valide reste en place, mais ne résolvait pas seul cette réouverture.
Toutes les traces temporaires sont retirées du code final.

La correction passe onze cycles d'ouverture et fermeture d'événements avec
37 à 336 ms entre touches et onze cycles mixtes avec 537 à 643 ms. Les logs
sont `/private/tmp/wander-scenario-deferred-console.log` et
`/private/tmp/wander-scenario-mixed-console.log`. Le pilotage manuel valide
également la sélection d'Amina puis la fermeture par le fond. Les trois
premiers tests UI passent, avec annulation complète des événements dans les
deux ordres et fermeture par le fond :
`/private/tmp/wander-scenario-ui-tests.xcresult`.

La compilation Release passe et son binaire ne contient ni le scénario ni
l'argument de lancement : `/private/tmp/wander-scenario-release-build.log`.
Les avertissements préexistants concernent les versions d'extensions
`15`/`27` par rapport à l'app `35` et les métadonnées AppIntents.
Les revues ont fait stabiliser les dates des amis fictifs et calculer leurs
présentations une seule fois ; la revue indépendante finale ne relève aucun
défaut matériel supplémentaire.

Les 37 tests existants et cinq tests UI passent dans
`/private/tmp/wander-scenario-final-tests.xcresult`. Le sixième test échoue
initialement sur un sélecteur XCTest absent, avant son geste. Le test final
mesure la distance entre deux marqueurs, indépendante du centre de pincement
et de la rotation, et attend l'animation MapKit. Pincement et double tap passent
ensuite dans `/private/tmp/wander-scenario-zoom-final.xcresult`, code 0.
Les 43 tests distincts sont validés sur ces deux exécutions. Le premier rapport
conserve son échec ; il n'est pas présenté comme une suite entièrement verte.
Le correctif produit reste inchangé pendant les ajustements du test.

Le lancement normal sans argument affiche la connexion Apple. La version
normale est compilée, installée et lancée sur l'iPhone de Samuel, sans débogueur,
à 10:43:58. Trois cycles rapides supplémentaires passent sur simulateur dans
la version finale sans traces. Les trois notes Obsidian sont actualisées et
leur rendu vérifié. Les tests UI couvrent la typographie par défaut ; le
scénario ne valide pas Firebase, la réconciliation de `ContentView`, VoiceOver
ou les groupes longs. Le sprint reste `in_progress` et le todo 025 `ready` pour
ces validations. Le plan conserve les commandes, captures et vidéos.

## Reusable lesson and prevention

Une notion produit exprimée en mètres doit être modélisée en mètres, pas avec
la collision de vues ni une grille choisie pour un autre domaine. Pré-calculer
les distances de paires, imposer une contrainte complète au groupe et séparer
les seuils d'entrée et de sortie donne un regroupement stable, testable et
indépendant de la caméra.

La frontière d'extraction doit inclure les transitions sources, groupes,
sélection et restauration. Isoler uniquement le calcul laisserait au
Coordinator les états interdépendants qui compliquent l'ajout de fonctionnalités.
Les tests des règles protègent la géométrie ; les tests avec de vrais objets
MapKit protègent le cycle natif. Aucun des deux ne remplace les vérifications
des gestes de l'écran complet.

Un test qui appelle directement `touchesEnded` avec un `UITouch` de test ne
prouve pas l'arbitrage des gestes UIKit. Ici, les trois tests de callbacks
passaient avant le changement du recognizer, alors que le défaut persistait.
De même, XCTest attend l'inactivité de l'app et peut espacer les taps assez
longtemps pour masquer ce défaut. Il faut compléter ces tests par de vrais
taps rapprochés sur l'écran et mesurer leur réception dans la même trace que
`didSelect` et `didDeselect`. La séquence avant/après prouve ici la fermeture
puis réouverture native et l'effet de la fermeture différée, au lieu de déduire
la cause d'une simple réussite de suite.

Aucune règle supplémentaire n'est ajoutée à `AGENTS.md` : les seuils et le
comportement restent spécifiques à la carte sociale de Wander.

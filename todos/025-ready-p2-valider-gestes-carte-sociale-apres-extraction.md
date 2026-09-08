---
id: "025"
title: "Valider les gestes de carte sociale après extraction"
status: ready
priority: P2
source: review
created: 2026-09-05
updated: 2026-09-08
tags: [todo, mapkit, architecture, accessibility, validation]
---

# Valider les gestes de carte sociale après extraction

## Finding

Le scénario local approuvé le 8 septembre reproduit la fermeture suivie d'une
réouverture native du groupe. Le correctif passe les cycles de touches
rapprochées sur simulateur et les trois premiers tests UI. La suite finale
locale est terminée. VoiceOver et les parcours de production, avec les
callbacks de `ContentView` et Firebase, restent à valider avant de clore le
sprint. Le statut de ce suivi reste donc `ready`.

Le constat initial du 5 septembre portait sur 25 tests et l'analyse Xcode
réussis, sans exécution des gestes complets du Coordinator. Les 37 tests
réussis sur iPhone le 8 septembre à 09:58:54 ne prouvaient pas davantage
l'arbitrage des gestes UIKit.

## Evidence

- [Plan approuvé et résultats exacts](../docs/plans/2026-09-05-architecture-carte-sociale-sprint-01.md).
- `wanderTests/MapSocialProximityControllerTests.swift` utilise un vrai
  `MKMapView` et les vraies vues de groupe, avec des marqueurs individuels de test.
- Le lancement normal sur l'iPhone 17 Pro, iOS 26.3, le 5 septembre 2026,
  s'arrête à l'écran « Continue with Apple » ; la carte n'est pas accessible
  sans connexion du propriétaire.
- La trace `/private/tmp/wander-rapid-native-reselection-before.log` reçoit le
  deuxième tap à 63/113 ms, puis montre `collapse` → `didDeselect` → `didSelect`
  du même groupe. L'hypothèse d'un deuxième toucher non reçu est invalidée.
- Après fermeture différée sur la file principale, onze cycles d'événements
  passent à 37–336 ms et onze cycles mixtes à 537–643 ms. Logs :
  `/private/tmp/wander-scenario-deferred-console.log` et
  `/private/tmp/wander-scenario-mixed-console.log`.
- Les trois premiers tests UI passent :
  `/private/tmp/wander-scenario-ui-tests.xcresult`. Le rapport final
  `/private/tmp/wander-scenario-final-tests.xcresult` contient 37 tests et cinq
  tests UI réussis, puis `/private/tmp/wander-scenario-zoom-final.xcresult`
  valide le sixième test après correction de sa mesure de zoom.

## Acceptance criteria

- [ ] Après connexion, un tap sur un groupe l'ouvre ; un tap sur un membre
      déclenche une seule action produit, malgré le callback natif qui suit.
- [ ] Un tap sur le fond restaure le membre dans son groupe sans doublon.
- [ ] Double tap, panoramique et zoom restent disponibles, y compris pendant
      un recentrage animé ; les groupes restent indépendants du niveau de zoom.
- [ ] VoiceOver ouvre le groupe, choisit un membre et permet de quitter la
      sélection ; les états sélectionné/ouvert sont annoncés correctement.
- [x] Mettre à jour le plan et les trois notes Obsidian avec le résultat runtime réel.

## Resolution notes

### Reproduction sur simulateur du 8 septembre, reprise approuvée

Le scénario `DebugSocialMapScenario` est limité à Debug sur simulateur et
à l'argument `-debug-social-map`. Il emploie des utilisateurs et événements
fictifs, SwiftData en mémoire et des opérations locales. Il conserve la vraie
carte, les fiches et le formulaire d'annulation avec sa confirmation. Il ne
valide pas la synchronisation Firebase ni les callbacks de `ContentView`.
L'authentification et les services réels restent les valeurs par défaut.

La fermeture synchrone dans `touchesEnded` déclenchait la désélection puis la
resélection native du même groupe. La fermeture est maintenant exécutée par
`DispatchQueue.main.async`, sans délai fixe. Les générations d'appui et de
présentation invalident cette action si une interaction plus récente ou le
démontage de la carte intervient. Le maintien en `.possible` est conservé,
mais était insuffisant seul. Toutes les traces temporaires sont retirées.

Les cycles rapides et mixtes décrits ci-dessus passent. Le pilotage manuel
valide aussi la sélection d'Amina puis le retour par le fond. Les tests UI
valident l'annulation complète des deux événements dans chaque ordre et le tap
sur le fond. La compilation Release passe et la recherche de chaînes du
binaire ne retrouve ni le scénario ni son argument :
`/private/tmp/wander-scenario-release-build.log`.

La revue de réutilisation ne relève rien à corriger. Les dates des amis
fictifs sont stabilisées et leurs présentations calculées une seule fois après
les revues qualité et efficacité. La revue indépendante finale ne relève aucun
défaut matériel. Les tests UI utilisent la typographie par défaut ; leurs
assertions de titre et de marqueur contrôlent la destination des taps par
coordonnées. Les avertissements préexistants de versions d'extensions
`15`/`27` face à l'app `35` et de métadonnées AppIntents restent consignés.

Les 37 tests existants et les six tests UI sont validés sur deux exécutions.
Le premier rapport contient un échec du test de zoom, corrigé en ciblant la
fenêtre et en mesurant la distance entre marqueurs après l'animation native.
Le rapport final dédié au zoom passe, code 0. Aucun changement du correctif
produit n'a été nécessaire pendant ces ajustements de test.
Le lancement normal affiche l'authentification Apple. La version normale est
compilée, installée et lancée sans débogueur sur l'iPhone à 10:43:58. Les trois
notes Obsidian sont actualisées et vérifiées en mode lecture. Les preuves et
commandes restent dans le plan. VoiceOver, les grands groupes défilants et les
parcours de production avec Firebase restent nécessaires ; ce suivi n'est pas clos.

### Historique de la première reprise du 8 septembre

Les paragraphes suivants décrivent les essais antérieurs au scénario local.
Samuel a ensuite signalé une dégradation. La reproduction plus haut remplace
l'hypothèse de réception du deuxième tap et les attentes de validation de cette
étape ; les réussites automatisées historiques restent limitées aux tests cités.

Le retour de 09:31 précise le défaut résiduel : ouvrir le groupe puis toucher
immédiatement le fond ne ferme pas ; attendre environ deux secondes puis
retoucher fonctionne. L'app reste utilisable. Le correctif conserve
`PassiveMapTapObserver` en `.possible` après un tap valide, car `.failed` peut
durer jusqu'à la fin de la séquence UIKit. Les échecs par déplacement et second
doigt restent inchangés. La durée exacte et l'arbitrage MapKit restent à valider.

Trois tests de callbacks passent déjà avant cette modification sur l'iPhone ;
ils ne reproduisent donc pas l'anomalie native. Après le changement, les 37 tests
de carte sociale passent sur l'iPhone le 8 septembre à 09:58:54, code 0.
La version corrigée est relancée sans débogueur ; le parcours physique de
fermeture immédiate reste à confirmer. Les traces temporaires sont retirées.
Le gel rencontré pendant un essai venait d'un script LLDB, supprimé après
diagnostic ; il ne constitue pas une preuve du défaut produit.

La nouvelle vidéo montre trois ouvertures brèves de la fiche Café, deuxième
ligne d'une paire superposée, puis retour au groupe avant toute édition.
Le correctif du 7 septembre ne suffit pas à ce cas. Aucun crash de processus
ni suppression n'est visible dans cette vidéo.

Le correctif tactile ajoute un tap à chaque rangée avec priorité sur les taps
ancêtres, puis annule le touchUpInside physique pour conserver une activation
unique. Aucun délai de grâce et aucune modification des callbacks de fermeture
existants. Les deux nouveaux tests utilisent les vrais contrôles de ligne et
retirent chaque événement aux mêmes coordonnées ; ils vérifient aussi le
contrat de priorité du geste. App et tests compilent, avec les deux
avertissements de version d'extension préexistants.

Les points de trace LLDB temporaires n'ont reçu aucun essai exploitable et ont
été retirés. La cause native exacte et la disparition du problème restent
non vérifiées. Le test par target/action n'est pas un toucher physique ; les
critères restent ouverts. Rejouer chaque ligne, la fermeture par le fond,
le défilement d'un groupe long, le zoom et VoiceOver sur l'iPhone.

La version corrigée a été recompilée, installée et lancée par Xcode sur
l'iPhone physique de Samuel. Aucun résultat utilisateur du parcours n'est
encore reçu. Les trois notes Obsidian sont actualisées et leurs sections
modifiées vérifiées en mode lecture ; le sprint reste ouvert pour la validation
des gestes.

Revue statique indépendante : aucun défaut matériel identifié. Le protocole
automatisé ce-code-review demeure indisponible pour la raison documentée dans
le plan. Rapports dans `/private/tmp/wander-row-touch-review-lxcxjen9/`.

### Correctif du 7 septembre

Le 7 septembre, une vidéo utilisateur montre des retours au groupe après
sélection d'un événement ou de Sam. La lecture du code a identifié une
transition A → B qui reconstruisait le groupe et détachait B avant sa sélection,
ainsi qu'un remplacement de source qui ne reprenait pas la sélection native.
Le correctif local publie le focus final avant les callbacks et conserve la
sélection en attente jusqu'à sa sélection native. La fermeture produit est
émise par le contrôleur lors d'un changement de membre ; un ancien callback
de désélection ne ferme plus directement une fiche SwiftUI.

Les callbacks de caméra distinguent désormais un geste actif de la carte
d'un recentrage automatique. Le fond annule explicitement toute sélection
en attente. Sept tests de régression sont ajoutés aux sept tests du contrôleur.
Ils couvrent le passage A → B, le remplacement d'objet à ID constant, les
sélections rapides, la caméra automatique/utilisateur et l'annulation avant
exécution différée, ainsi que les passages membre → groupe et groupe → membre.
Ils ne simulent pas les touches physiques du Coordinator.

La revue statique indépendante a relevé trois constats P2, corrigés dans le
diff final : libérer l'ancien membre avant d'ouvrir un groupe, fermer le groupe
avant d'activer un membre et attendre les callbacks différés avant les
assertions des tests. Aucun défaut matériel résiduel identifié par cette revue.
Le protocole automatisé de `ce-code-review` n'a pas pu terminer ; sa limite et
le rapport de la revue équivalente sont consignés dans le plan.

La compilation finale de l'app et des tests (`build-for-testing`, destination
simulateur générique) termine avec le code 0, sans diagnostic dans
`/private/tmp/wander-selection-reviewed-build.log`. Les trois notes Obsidian
sont actualisées et leurs sections affectées vérifiées en mode lecture.

Tous les simulateurs sont arrêtés. Samuel a choisi « Continuer sans tests sur
simulateur » : aucun XCTest, geste réel ou parcours VoiceOver n'est exécuté
le 7 septembre. La compilation ne remplace pas ces critères, qui restent ouverts.

Lors d'une prochaine validation autorisée, utiliser l'appareil existant puis
vérifier la connexion Apple et rejouer la vidéo, notamment les paires et les
gestes pendant/après recentrage. Aucun appareil ou runtime n'a été créé.
Ce suivi appartient au sprint 01, sans autoriser de sprint supplémentaire.

---
title: "Regrouper les marqueurs sociaux par proximité géographique"
date: 2026-09-02
last_updated: 2026-09-05
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

Aucune règle supplémentaire n'est ajoutée à `AGENTS.md` : les seuils et le
comportement restent spécifiques à la carte sociale de Wander.

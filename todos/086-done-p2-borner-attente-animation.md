---
id: "086"
title: Borner l'attente de fin d'animation du test de zoom
status: done
priority: P2
source: ponytail-review
created: 2026-10-25
completed_at: 2026-10-25
tags: [todo, tests, map]
---

## Constat et preuve

`testOverlappingPhotosStayVisibleDuringZoomOutAndCoordinateUpdates`, dans
`wanderTests/SavedPlaceAnnotationTests.swift`, attendait `finished` dans une boucle
sans limite. Si le callback de la caméra ne se produisait pas, le test ne terminait
pas de lui-même. Le fichier possède déjà `waitUntil`, limité à cinq secondes.

## Critères de résolution

- [x] Réutiliser waitUntil, conserver l'assertion de visibilité à chaque passage.
- [x] Le test de zoom et les tests voisins passent sur le simulateur autorisé.

## Résolution

Correction appliquée, compilation réussie, revue indépendante sans constat.
42 tests natifs et 4 parcours UI réussis sur l'iPhone 18 Pro autorisé,
dans `/private/tmp/wander-ponytail-tests.xcresult`, sans échec ni test ignoré.
Plan : [simplification Ponytail](../docs/plans/2026-10-25-simplifier-pins-ponytail.md).

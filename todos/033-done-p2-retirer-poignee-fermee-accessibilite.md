---
id: "033"
title: "Retirer la poignée fermée de l'accessibilité"
status: done
priority: P2
source: ui-test
created: 2026-09-08
resolved: 2026-09-08
tags: [todo, map, accessibility]
---

# Retirer la poignée fermée de l'accessibilité

## Constat

Avec une hauteur nulle et `accessibilityHidden`, la poignée restait détectable
par XCTest après la fermeture. Une commande de redimensionnement sans fiche
ne doit plus être exposée.

## Résolution et preuves

La poignée est retirée conditionnellement dans son propre emplacement SwiftUI.
La carte conserve son emplacement structurel et récupère toute la hauteur.

- [x] La poignée et la fiche disparaissent de l'arbre d'accessibilité après fermeture.
- [x] La carte retrouve sa hauteur initiale.
- [x] `testResizeButtonCyclesSizesAndCloseRestoresMap` passe dans la suite finale.

Résultat : `/tmp/wander-split-tests-final.xcresult`.
Voir le [plan](../docs/plans/2026-09-08-fiches-carte-ecran-partage.md).

---
id: "035"
title: "Stabiliser la surface MapKit sur iPhone"
status: done
priority: P1
source: device-crash
created: 2026-09-08
completed_at: 2026-09-08
tags: [todo, map, metal, ios]
---

# Stabiliser la surface MapKit sur iPhone

## Constat

L'iPhone 12 mini s'arrête sur SIGABRT pendant la transition de fiche. La pile
relie `MKMapView.setFrame` à `CAMetalLayer.setDrawableSize`, puis à la destruction
d'une texture encore requise par un command buffer. Les tests de gestes sur
simulateur n'avaient pas reproduit ce crash GPU.

## Résolution

`MapViewportView` conserve les dimensions de la carte native pendant que sa
fenêtre visible change de taille. Les coordonnées des groupes et indicateurs
suivent cette fenêtre. La validation Metal reste active.

- [x] Régression UI rouge avant correction : 678,67 pt deviennent 317,33 pt.
- [x] Régression corrigée et trois tests directs du viewport réussis.
- [x] Version finale testée sur iPhone 12 mini iOS 26.5.2 : quatre cycles
  ouverture/fermeture, douze positions et quatre glissements sans crash.
- [x] Journal de cette exécution : `Metal API Validation Enabled`, aucune
  assertion échouée, aucun SIGABRT ni exception fatale.

Résultat physique final : `/tmp/wander-iphone-metal-final.xcresult`.
Voir le [plan](../docs/plans/2026-09-08-corriger-crash-metal-et-arrondir-fiches.md)
et la [solution](../docs/solutions/2026-09-08-stabiliser-rendu-mapkit-pendant-fiche.md).

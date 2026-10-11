---
id: "079"
title: Recalculer les adresses quand la zone visible change
status: done
priority: P2
source: review
created: 2026-10-11
tags: [todo, map, naver]
---

# Constat

Le drawable Mapbox reste stable pendant le redimensionnement des panneaux.
Un recalcul limité aux mouvements de caméra et à updateUIView pouvait donc
utiliser l'ancien viewport, puis laisser des adresses masquées sans nouvel événement.

# Résolution et validation

- [x] `viewport.onViewportChange` recalcule les présentations après le layout.
- [x] `testViewportExpansionRevealsAddressesWithoutChangingCamera` vérifie la
  révélation et le masquage d'une adresse lorsque seul le viewport change.
- [x] `testNativeMapRenderSizeStaysStableAcrossPaneChanges` passe sur le simulateur.

Plan : `docs/plans/2026-10-11-adresses-progressives.md`.

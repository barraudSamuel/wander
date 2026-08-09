---
id: "003"
title: "Synchroniser les métadonnées détaillées d'exploration"
status: ready
priority: P2
source: review
created: 2026-08-09
tags: [todo, firebase, exploration, migration]
---

# Synchroniser les métadonnées détaillées d'exploration

## Finding

Firestore conserve actuellement uniquement l'identifiant H3 et `sharedAt`.
Un nouvel appareil retrouve donc les zones et leur date approximative, mais pas
la durée, le nombre de visites ni les dates exactes de première et dernière
découverte utilisées par la heat map locale.

## Evidence

- `wander/FriendSyncService.swift` écrit seulement `sharedAt` dans chaque
  document `explorations/{uid}/cells/{cellID}`.
- `wander/DiscoveredCellStore.swift` initialise les cases uniquement distantes
  avec les valeurs par défaut de `DiscoveredCell`.

## Acceptance criteria

- [ ] Définir un schéma Firestore versionné pour `firstSeenAt`, `lastSeenAt`,
  `duration` et `visitCount`, avec une stratégie de migration des documents
  existants.
- [ ] Définir des règles de fusion qui empêchent le double comptage entre
  appareils et préservent les valeurs les plus récentes.
- [ ] Vérifier la restauration de la heat map sur un second appareil.
- [ ] Le build et les tests de réconciliation passent.

## Resolution notes

À planifier séparément : la restauration actuelle garantit volontairement les
zones découvertes, pas la fidélité de leurs statistiques.

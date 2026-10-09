---
id: "003"
title: "Synchroniser les métadonnées détaillées d'exploration"
status: done
resolved: 2026-10-09
resolution: obsolete
priority: P2
source: review
created: 2026-08-09
tags: [todo, firebase, exploration, migration]
---

# Synchroniser les métadonnées détaillées d'exploration

## Finding

Ce besoin est abandonné avec la suppression de la heatmap approuvée le
9 octobre 2026. Il ne correspond pas à une synchronisation implémentée.

Au moment du constat, Firestore conservait uniquement l'identifiant H3 et
`sharedAt`. Un nouvel appareil retrouvait les zones et leur date approximative,
mais pas les durées et compteurs utilisés par la heatmap locale.

## Evidence

- `wander/FriendSyncService.swift` écrit seulement `sharedAt` dans chaque
  document `explorations/{uid}/cells/{cellID}`.
- `wander/DiscoveredCellStore.swift` initialise les cases uniquement distantes
  avec les valeurs par défaut de `DiscoveredCell`.

## Resolution notes

Le modèle actif ne conserve plus `duration` ni `visitCount`. Les dates locales
de découverte restent préservées, et Firestore continue de restaurer les zones
avec `sharedAt` comme date de secours. Aucun nouveau schéma Firestore ni règle
de fusion des compteurs n'est nécessaire.

La migration et ses validations sont suivies dans
[le plan de suppression](../docs/plans/2026-10-09-supprimer-heatmap.md).
Le chemin de ce constat est conservé pour les liens des plans historiques.

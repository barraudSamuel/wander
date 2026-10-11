---
id: "078"
title: Préserver les adresses masquées pendant la synchronisation
status: done
priority: P1
source: review
created: 2026-10-11
tags: [todo, map, naver]
---

# Constat

La première version de la sélection selon la densité masquait des adresses via
`native.visible`. `MapAnnotationStore.synchronizeCoordinates()` remettait ensuite
ce champ à true pour toute coordonnée valide, notamment lors de la synchronisation
des marqueurs sociaux après la mise à jour des favoris.

# Résolution

`Entry.requestedVisibility` conserve la décision d'affichage. La visibilité
native effective combine cette décision avec la validité des coordonnées.
Les marqueurs sociaux continuent de demander leur visibilité par défaut.

# Validation

- [x] Le test `testHiddenSavedPlaceStaysHiddenAfterCoordinateSynchronization`
  échoue avant correction à l'assertion de masquage, puis passe après correction.
- [x] Les coordonnées invalides masquent le marqueur ; leur correction restaure
  la visibilité uniquement lorsqu'elle est demandée.
- [x] Suite `MapSocialProximityControllerTests` réussie.
- [x] Parcours UI de quartier dense réussi, sans chevauchement.

Plan : `docs/plans/2026-10-11-adresses-progressives.md`.

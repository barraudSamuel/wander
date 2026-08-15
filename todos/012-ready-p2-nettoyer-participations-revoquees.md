---
id: "012"
title: "Nettoyer les participations après révocation d'amitié"
status: ready
priority: P2
source: review
created: 2026-08-15
tags: [todo, firestore, friends, participation]
---

# Nettoyer les participations après révocation d'amitié

## Finding

La suppression d'une amitié ne supprime pas les participations associées. Le
compte révoqué perd correctement son accès et l'organisateur filtre son entrée,
mais les autres participants peuvent continuer à voir son avatar et à le
compter jusqu'à l'expiration du document.

## Evidence

- `wander/FriendSyncService.swift` supprime seulement le document d'amitié.
- `wander/ContentView.swift` filtre les UID acceptés pour la vue organisateur,
  mais pas pour la vue d'un autre participant.
- Les documents `attendees` persistent sous le plan jusqu'à suppression ou TTL.

## Acceptance criteria

- [ ] Révoquer une amitié retire les participations courantes des deux côtés.
- [ ] Organisateur et participants voient le même total après la révocation.
- [ ] Les règles et un test multi-compte empêchent toute réapparition résiduelle.

## Resolution notes

Finding reporté comme dette connue lors de la clôture demandée du Sprint 6 :
`docs/plans/2026-08-15-sorties-prevues-sprint-06-participation.md`.

---
id: "011"
title: "Retenter les notifications FCM en échec transitoire"
status: ready
priority: P1
source: review
created: 2026-08-15
tags: [todo, notifications, firebase, reliability]
---

# Retenter les notifications FCM en échec transitoire

## Finding

Le backend réserve un claim par appareil avant l'envoi. Si FCM retourne une
erreur transitoire, le claim reste en statut `failed` et l'erreur est absorbée.
Une relance du trigger ignore alors cet appareil comme déjà réclamé, ce qui peut
faire perdre définitivement une notification de participation.

## Evidence

- `functions/src/index.ts` crée le claim dans `claimTarget` avant l'envoi.
- `sendChunk` conserve le claim en `failed` et ne propage pas l'erreur.
- `claimTarget` ignore ensuite tout claim existant, quel que soit son statut.

## Acceptance criteria

- [ ] Une erreur FCM transitoire peut être reprise sans dupliquer un envoi déjà
      réussi.
- [ ] Une erreur permanente conserve le nettoyage actuel du token invalide.
- [ ] Les tests couvrent succès, échec transitoire, reprise et échec permanent.

## Resolution notes

Finding reporté comme dette connue lors de la clôture demandée du Sprint 6 :
`docs/plans/2026-08-15-sorties-prevues-sprint-06-participation.md`.

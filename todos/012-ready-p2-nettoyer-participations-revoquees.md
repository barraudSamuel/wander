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

La suppression d'une amitié ne supprimait pas les participations associées. Le
compte révoqué perdait correctement son accès et l'organisateur filtrait son
entrée, mais les autres participants pouvaient continuer à voir son avatar et
à le compter jusqu'à l'expiration du document.

## Evidence

- L'ancienne implémentation de `wander/FriendSyncService.swift` supprimait
  directement le document d'amitié.
- Les documents `attendees` persistaient sous l'événement jusqu'à sa
  suppression.
- La prévisualisation du roster par tous les amis acceptés a rendu nécessaire
  un nettoyage serveur, car un spectateur ne peut pas vérifier les relations
  des autres participants.

## Acceptance criteria

- [x] Révoquer une amitié déclenche le retrait des participations antérieures
      à `revokedAt` dans les deux directions.
- [ ] Organisateur et participants voient le même total après la révocation.
- [x] Les règles et un test multi-compte empêchent toute réapparition résiduelle.

## Resolution notes

Finding reporté comme dette connue lors de la clôture demandée du Sprint 6 :
`docs/plans/2026-08-15-sorties-prevues-sprint-06-participation.md`.

Implémentation locale préparée le 2026-09-01 :

- `FriendSyncService` écrit un tombstone `revoking` horodaté par le serveur et
  retire immédiatement la relation des états publiés ;
- les règles coupent tous les accès sociaux dès `revoking` et interdisent sa
  suppression prématurée par un client normal ;
- `cleanupRevokedFriendshipAttendances` nettoie les deux directions en lots,
  avec cutoff, retry idempotent et finalisation conditionnelle ;
- les règles simplifiées n'accordent l'accès aux groupes et la création d'une
  réponse qu'aux relations `accepted`, tout en laissant l'auteur supprimer son
  propre document après révocation ;
- 37/37 tests de règles réussissent avec cette matrice, dont les cas
  `revoking`, roster interdit et nettoyage personnel ; les 43/43 tests
  Functions actifs avaient réussi lors de la préparation du nettoyage.

Le finding reste `ready` tant que le scénario interactif A/B/C n'a pas confirmé
les totaux sur plusieurs comptes et que les règles et la fonction ne sont pas
déployées par une opération séparément approuvée.

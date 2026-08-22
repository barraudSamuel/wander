---
title: "Nettoyage automatique des événements"
status: completed
date: 2026-08-22
completed_at: 2026-08-22
owner: "Samuel"
related: []
tags: [plan, events, firebase]
---

# Nettoyage automatique des événements

## Outcome

Supprimer automatiquement les événements Firestore 24 heures après leur
dernière publication, avec une exécution planifiée toutes les heures. Un
événement est donc supprimé entre 24 et 25 heures après son `publishedAt`.

## Context

Les événements sont stockés sous `users/{ownerId}/events/{eventId}` et portent
déjà un timestamp serveur `publishedAt`, renouvelé lors d'une modification. La
fonction `cleanupEventAttendances` supprime déjà les documents de la
sous-collection `attendees` lorsqu'un événement disparaît.

## Scope

- Inclus : une Cloud Function planifiée, l'index de groupe de collections
  nécessaire sur `events.publishedAt`, des tests unitaires de la limite de
  24 heures et la documentation associée.
- Non inclus : champ `expiresAt`, politique TTL, modification Swift ou des
  règles Firestore, déploiement Firebase et validation en production.

## Proposed approach

Une fonction `cleanupExpiredEvents`, exécutée toutes les 60 minutes dans
`asia-northeast3`, interroge le groupe de collections `events` avec
`publishedAt <= maintenant - 24 h`, puis supprime les résultats par lots. Les
suppressions déclenchent la fonction existante `cleanupEventAttendances`.

## Affected files

- `functions/src/index.ts` — déclarer la fonction planifiée et supprimer les
  événements expirés par lots.
- `functions/src/eventCleanupLogic.ts` — centraliser le calcul pur de la limite
  de rétention.
- `functions/src/eventCleanupLogic.test.ts` — tester la limite de 24 heures.
- `firebase.json` — déclarer le fichier d'index Firestore.
- `firestore.indexes.json` — ajouter l'index collection-group sur
  `events.publishedAt`.
- `docs/notifications-apns-configuration.md` — documenter le nettoyage et son
  déploiement séparé.
- `docs/plans/2026-08-22-nettoyage-automatique-evenements.md` — suivre ce
  travail.
- `Backlog features.md`, `Documentation technique.md`, `Documentation UX.md`
  et `00 - Wander.md` dans le vault Obsidian Wander — refléter le nouveau cycle
  de vie et l'activation Firebase encore en attente.

## Implementation

- [x] Passer ce plan approuvé au statut `in_progress`.
- [x] Ajouter le calcul testé de la limite de 24 heures.
- [x] Ajouter la fonction planifiée et le traitement par lots.
- [x] Ajouter et référencer l'index Firestore requis.
- [x] Mettre à jour la documentation du dépôt et le vault Obsidian.
- [x] Compiler, tester et relire le diff sans déployer.

## Edge cases and risks

- L'exécution horaire implique une suppression entre 24 et 25 heures après
  `publishedAt`, et non exactement à la seconde des 24 heures.
- Une modification renouvelle `publishedAt` : les 24 heures repartent de cette
  dernière publication, conformément au comportement existant.
- La requête collection-group dépend du déploiement préalable de l'index ; le
  cron ne doit pas être déployé seul.
- Une exécution interrompue est reprise naturellement à l'exécution suivante ;
  supprimer un document déjà absent est sans effet fonctionnel.

## Validation

- [x] `npm test` réussit dans `functions/` : 28 réussites, 1 test d’émulateur
  ignoré, 0 échec.
- [x] `npm run build` réussit dans `functions/`.
- [x] Les fichiers JSON sont valides et la configuration référence l'index.
- [x] L’état distant des index a été lu sans mutation : aucun index composite ni
  override existant n’est omis par le nouveau fichier.
- [x] Ce travail ne modifie ni Swift ni les règles Firestore ; les changements
  Swift préexistants dans le worktree ont été préservés.
- [x] Les notes Obsidian affectées sont lisibles et cohérentes en mode Aperçu.
- [x] Aucun déploiement Firebase n'est effectué.

## Review notes

- Hardest decision: réutiliser `publishedAt` évite tout changement de modèle et
  maintient l'implémentation minimale.
- Rejected alternatives: TTL Firestore et tâche créée hors Firebase CLI.
- Least certain: le comportement réel restera à confirmer après le déploiement
  séparé de l'index et de la fonction planifiée.
- Review result: aucun finding bloquant ou prioritaire après compilation, tests,
  validation du manifeste planifié et relecture du diff.

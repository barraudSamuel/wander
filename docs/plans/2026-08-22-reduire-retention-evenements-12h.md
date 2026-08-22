---
title: "Réduire la rétention des événements à 12 heures"
status: completed
date: 2026-08-22
completed_at: 2026-08-22
owner: "Samuel"
related:
  - "2026-08-22-nettoyage-automatique-evenements"
tags: [plan, events, firebase]
---

# Réduire la rétention des événements à 12 heures

## Outcome

Faire supprimer les événements par le cron existant entre 12 et 13 heures
après leur dernière publication, au lieu de 24 à 25 heures.

## Scope

- Inclus : constante de rétention, tests et documentation correspondante.
- Non inclus : fréquence horaire, requête Firestore, index, règles, code Swift
  et déploiement Firebase.

## Affected files

- `functions/src/eventCleanupLogic.ts` — passer la rétention à 12 heures.
- `functions/src/eventCleanupLogic.test.ts` — adapter la limite testée.
- `docs/notifications-apns-configuration.md` — documenter 12 à 13 heures.
- `docs/plans/2026-08-22-reduire-retention-evenements-12h.md` — suivre le
  changement.
- `Backlog features.md`, `Documentation technique.md`, `Documentation UX.md`
  et `00 - Wander.md` dans le vault Obsidian — aligner le comportement produit.

## Implementation

- [x] Passer le plan approuvé au statut `in_progress`.
- [x] Modifier la constante et les tests.
- [x] Mettre à jour la documentation du dépôt et Obsidian.
- [x] Compiler, tester et relire le diff.

## Edge cases and risks

- Le cron reste horaire : la suppression intervient entre 12 et 13 heures, pas
  exactement à 12 heures.
- Une modification renouvelle `publishedAt` et relance la période de 12 heures.
- La fonction déjà en production conserve 24 heures tant que la nouvelle
  version n'est pas redéployée manuellement.

## Validation

- [x] `npm test` réussit dans `functions/` : 28 réussites, 1 test d'émulateur
  ignoré, 0 échec.
- [x] Le manifeste planifié reste `every 60 minutes`.
- [x] L'index et les règles Firestore ne sont pas modifiés par ce changement.
- [x] `00 - Wander.md`, `Backlog features.md` et `Documentation technique.md`
  sont validés en mode Aperçu ; `Documentation UX.md`, dont seul un paragraphe
  simple change, est validé par son frontmatter, son texte et ses wikilinks car
  l'utilisateur a repris Obsidian pendant le contrôle visuel.
- [x] Aucun déploiement Firebase n'est effectué par Codex.

## Review notes

- Hardest decision: conserver le cron horaire maintient le changement minimal.
- Rejected alternatives: augmenter la fréquence du cron ou ajouter un nouveau
  champ d'expiration.
- Least certain: la première suppression à 12 heures dépendra du moment du
  redéploiement et de la prochaine exécution horaire.
- Review result: aucun nouveau finding ; les findings déjà acceptés sur la
  suppression concurrente, les retries et la couverture d'intégration restent
  inchangés.

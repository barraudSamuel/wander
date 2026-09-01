---
title: "Corriger le batch de première participation"
status: completed
date: 2026-09-01
approved_at: 2026-09-01T15:11:07+09:00
completed_at: 2026-09-01T15:13:45+09:00
owner: "Samuel"
related:
  - "../../todos/023-done-p1-corriger-batch-participation.md"
  - "./2026-09-01-simplifier-regles-firestore.md"
tags: [plan, firebase, firestore, participation, bugfix]
---

# Corriger le batch de première participation

## Outcome

Permettre à un ami accepté d'envoyer sa première réponse à une sortie lorsque
le batch client supprime d'abord la réponse opposée absente, sans lui permettre
de supprimer la réponse existante d'un autre participant.

## Context

`OutingAttendanceService.setResponse` écrit une réponse avec un batch atomique :
il supprime le document opposé sous `attendees` ou `declines`, puis crée la
nouvelle réponse. Lors d'une première réponse, le document supprimé n'existe
pas. La règle actuelle consulte alors `resource.data.participantId`, provoque
une erreur sur la ressource absente et refuse tout le batch.

La reproduction locale exacte échoue avec `permission-denied` et
`Null value error for delete`. La couverture précédente testait les opérations
séparément, pas ce batch.

## Scope

- Included:
  - autoriser le `delete` sans effet d'une réponse absente pour un ami accepté ;
  - exiger que l'événement parent existe dans ce cas ;
  - préserver le droit du propriétaire et de l'auteur de supprimer une réponse
    existante ;
  - préserver le refus de suppression d'une réponse existante appartenant à un
    autre participant ;
  - reproduire les transitions réelles dans l'émulateur.
- Not included:
  - modification du service Swift ou de l'interface ;
  - déploiement Firebase ;
  - migration ou modification de données distantes ;
  - refonte supplémentaire des règles.

## Dependencies

- Règles simplifiées du plan
  `docs/plans/2026-09-01-simplifier-regles-firestore.md`.
- Firebase CLI local sous `firebase-tests` et JDK 21.

## Affected files

- `docs/plans/2026-09-01-corriger-batch-participation.md` — suivi du correctif.
- `firestore.rules` — autorisation du `delete` absent sans ouvrir les réponses
  existantes.
- `firebase-tests/tests/outing-event-attendances.rules.test.mjs` — batch réel et
  tests négatifs.
- `todos/023-done-p1-corriger-batch-participation.md` — finding résolu.
- `docs/solutions/2026-09-01-autoriser-delete-idempotent-firestore.md` — leçon
  réutilisable après validation.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md`
  — statut du correctif de participation.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md`
  — sémantique des batches et des suppressions absentes.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`
  — restauration de la première réponse à une sortie.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/00 - Wander.md`
  — état du correctif Firebase.

Le vault Obsidian est actuellement lisible mais non inscriptible. Si cette
limite persiste, les sections exactes resteront consignées ici et aucune copie
du vault ne sera créée.

## Implementation checklist

- [x] Autoriser une suppression absente uniquement pour un ami accepté et un
      événement existant.
- [x] Préserver les suppressions existantes du propriétaire et de l'auteur.
- [x] Ajouter les tests du premier choix et du changement de réponse.
- [x] Ajouter le refus de suppression de la réponse existante d'un autre compte.
- [x] Documenter et revoir le correctif.

## Risks

- Une condition trop large permettrait à un ami de supprimer la réponse d'un
  autre compte. Le branchement absent doit donc être séparé du branchement qui
  lit `resource.data.participantId`.
- L'autorisation d'un `delete` absent ne doit pas permettre de répondre sous un
  événement supprimé.
- Les règles déployées resteront inchangées tant qu'un déploiement séparé n'est
  pas exécuté.

## Validation

- [x] Le batch première participation réussit quand `declines` est absent.
- [x] Le batch premier refus réussit quand `attendees` est absent.
- [x] Les changements participation vers refus et refus vers participation
      réussissent atomiquement.
- [x] Un ami ne peut pas supprimer la réponse existante d'un autre compte.
- [x] Un étranger, une relation non acceptée et un événement absent restent
      refusés.
- [x] Toute la suite Firestore réussit sous JDK 21.
- [x] `git diff --check` réussit et la revue ne trouve aucune ouverture croisée.
- [x] Les limites Obsidian et de déploiement sont consignées exactement.

### Résultats

- 38/38 tests réussissent sur 7 suites avec Firebase Emulator Suite et JDK 21.
- Le test positif rejoue la première participation, le passage au refus, le
  retour à la participation et le premier refus d'un second ami.
- Les tests négatifs refusent la suppression d'une réponse existante étrangère,
  les suppressions absentes par une relation `pending`, `revoking` ou étrangère,
  et tous les batches visant un événement absent.
- `git diff --check` réussit. Aucun changement Swift ne nécessitait un nouveau
  build iOS ; le correctif porte uniquement sur les règles, leurs tests et la
  documentation.
- Aucun déploiement Firebase et aucune donnée distante n'ont été modifiés.

### Validation externe restante

Le vault Obsidian reste lisible mais non inscriptible ; sa validation en reading
view n'a pas réussi et aucune copie de substitution n'a été créée. Les mises à
jour exactes restantes sont :

- `Backlog features.md` — consigner le finding P1 comme corrigé localement et
  conserver le déploiement comme étape séparée ;
- `Documentation technique.md` — documenter dans « Événements et
  participations » le batch idempotent et dans « Validation et outils » le
  résultat 38/38 ;
- `Documentation UX.md` — préciser dans « Sorties prévues » que la première
  réponse et le changement de réponse sont restaurés après déploiement ;
- `00 - Wander.md` — actualiser `updated` et « État du projet » avec le statut
  local du correctif.

La validation sur l'appareil reste à effectuer après le déploiement explicitement
demandé par le propriétaire.

## Acceptance criteria

- Le batch exact de `OutingAttendanceService` réussit pour une première réponse.
- La règle n'accorde aucun droit supplémentaire sur un document existant.
- Aucun service Swift, aucune donnée distante et aucun travail local existant ne
  sont modifiés ou supprimés.

## Review notes

- Hardest decision: autoriser uniquement un `delete` réellement absent sans
  déduire l'identité depuis un chemin flexible ni ouvrir les documents existants.
- Rejected alternatives: supprimer conditionnellement côté Swift, ajouter une
  lecture réseau préalable, ou autoriser un ami accepté à supprimer toutes les
  réponses du groupe.
- Residual risk: l'appareil continuera à utiliser les règles actuellement
  déployées jusqu'au prochain déploiement manuel.

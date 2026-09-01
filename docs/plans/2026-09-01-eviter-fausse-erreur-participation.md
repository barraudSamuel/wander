---
title: "Éviter la fausse erreur après une participation enregistrée"
status: completed
date: 2026-09-01
completed_at: 2026-09-01T16:16:07+09:00
owner: "Samuel"
related:
  - "../../todos/024-done-p1-eviter-fausse-erreur-participation.md"
  - "./2026-09-01-corriger-batch-participation.md"
tags: [plan, ios, firestore, participation, bugfix]
---

# Éviter la fausse erreur après une participation enregistrée

## Outcome

Ne plus afficher « Participation impossible » lorsqu'une réponse a déjà été
enregistrée par Firestore mais que sa confirmation immédiate échoue. Seul un
échec du commit doit être présenté comme un échec de modification ; les
listeners existants restent la source de vérité pour l'état affiché.

## Context

Après `batch.commit()`, `OutingAttendanceService.setResponse` relit le document
depuis le serveur puis le décode strictement. Toute erreur de réseau, de lecture
ou de validation remonte jusqu'à `ContentView`, qui affiche un message générique
affirmant à tort que la modification a échoué. Sur l'appareil, la réponse est
bien visible malgré cette popup.

Le batch, sa relecture et les règles réussissent dans l'émulateur. L'écart
restant concerne donc le traitement client d'une confirmation secondaire, pas
l'autorisation de l'écriture.

## Scope

- Included:
  - conserver le `batch.commit()` comme frontière d'échec de l'action ;
  - rendre la relecture et le décodage post-commit opportunistes et non
    bloquants ;
  - appliquer immédiatement la réponse si la confirmation est valide ;
  - sinon laisser les listeners personnels réconcilier l'état ;
  - préserver les erreurs réelles antérieures ou liées au commit.
- Not included:
  - nouvelle modification des règles Firestore ;
  - changement de schéma ou migration de données ;
  - déploiement Firebase ou distribution de l'application ;
  - ajout d'une target XCTest dans cet incrément.

## Dependencies

- Correctif du batch documenté dans
  `docs/plans/2026-09-01-corriger-batch-participation.md`.
- Listeners personnels `attendees` et `declines` déjà actifs pour chaque sortie
  d'ami observée.

## Affected files

- `docs/plans/2026-09-01-eviter-fausse-erreur-participation.md` — suivi du
  correctif.
- `wander/OutingAttendanceService.swift` — confirmation post-commit non
  bloquante.
- `todos/024-done-p1-eviter-fausse-erreur-participation.md` — finding résolu.
- `docs/solutions/2026-09-01-separer-commit-et-confirmation-firestore.md` —
  leçon réutilisable après validation.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md`
  — statut du faux message de participation.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md`
  — séparation entre commit et réconciliation par listeners.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`
  — comportement des erreurs de participation.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/00 - Wander.md`
  — état du correctif local.

Le vault Obsidian est lisible mais non inscriptible depuis cet environnement.
Si cette limite persiste, les sections exactes seront consignées sans créer de
copie du vault.

## Implementation checklist

- [x] Extraire la confirmation immédiate dans une méthode non lançante.
- [x] Conserver l'application immédiate d'un document confirmé et valide.
- [x] Laisser les listeners réconcilier tout échec de confirmation secondaire.
- [x] Préserver la propagation des erreurs avant et pendant le commit.
- [x] Compiler, revoir et documenter le correctif.

## Risks

- Sans confirmation immédiate, l'interface peut conserver brièvement son ancien
  état jusqu'au prochain snapshot serveur ; les listeners sont déjà conçus pour
  cette transition.
- Avaler une erreur du commit masquerait un véritable échec. Le bloc non
  bloquant doit impérativement commencer après `try await batch.commit()`.
- Une réponse invalide doit rester rejetée par les handlers de snapshots et
  conduire à l'état indisponible, pas être injectée dans l'état publié.

## Validation

- [x] `batch.commit()` reste une opération lançante.
- [x] Les erreurs de relecture ou de décodage après le commit ne remontent plus
      comme un échec de modification.
- [x] Une confirmation valide met encore immédiatement à jour l'état local.
- [x] Les handlers de snapshots continuent à valider les documents distants.
- [x] Le build Debug générique réussit sans nouvel avertissement.
- [x] `git diff --check` réussit et le diff est revu.
- [x] Les limites Obsidian et de validation sur appareil sont consignées.

### Résultats

- `try await batch.commit()` reste dans la méthode lançante et précède la phase
  de confirmation.
- `confirmCommittedResponseIfAvailable` est non lançante : ses lectures et
  décodages emploient `try?`, appliquent uniquement un document entièrement
  valide et retournent sinon vers les listeners existants.
- Les handlers de snapshots n'ont pas été assouplis et conservent toutes leurs
  validations de document et de contexte social.
- Le build Debug générique réussit avec `CODE_SIGNING_ALLOWED=NO`. Les seuls
  diagnostics sont les avertissements préexistants de `CFBundleVersion` 15 et
  27 pour des extensions dont l'application parente est en version 28.
- `git diff --check` réussit. Aucune règle Firestore et aucune donnée distante
  ne sont modifiées par cet incrément.

### Validation externe restante

Le vault Obsidian reste lisible mais non inscriptible ; la validation en reading
view n'a pas réussi et aucune copie de substitution n'a été créée. Les mises à
jour exactes restantes sont :

- `Backlog features.md` — consigner le finding P1 comme corrigé localement et
  la validation appareil comme restante ;
- `Documentation technique.md` — documenter dans « Événements et
  participations » la séparation entre commit, confirmation opportuniste et
  listeners ;
- `Documentation UX.md` — préciser dans « Sorties prévues » et « États UX
  essentiels » qu'une confirmation secondaire ne déclenche plus un faux échec ;
- `00 - Wander.md` — actualiser `updated` et « État du projet » avec ce correctif
  local.

La disparition réelle de la popup doit être confirmée après reconstruction et
installation de cette version sur l'appareil du scénario signalé.

## Acceptance criteria

- Une participation enregistrée ne peut plus produire la popup générique à
  cause de la seule confirmation post-commit.
- Un véritable refus ou échec du commit continue à produire une erreur.
- Aucune règle Firestore et aucune donnée distante ne sont modifiées.

## Review notes

- Hardest decision: préserver l'actualisation immédiate sans laisser une
  confirmation secondaire redéfinir le résultat de la mutation.
- Rejected alternatives: supprimer toute confirmation immédiate, masquer toutes
  les erreurs de `setResponse`, ou relâcher encore les règles Firestore.
- Least certain: la cause exacte de la confirmation secondaire sur les données
  réelles reste masquée par l'ancien fallback générique ; elle n'affecte plus le
  résultat utilisateur, mais la validation appareil reste nécessaire.

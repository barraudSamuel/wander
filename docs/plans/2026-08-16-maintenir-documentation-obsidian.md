---
title: "Rendre obligatoire la maintenance de la documentation Obsidian"
status: completed
date: 2026-08-16
approved_at: "2026-08-16"
in_progress_at: "2026-08-16"
completed_at: "2026-08-16T19:59:58+09:00"
owner: "Samuel Barraud"
related:
  - "2026-08-16-obsidian-backlog-documentation.md"
tags: [plan, documentation, obsidian, workflow]
---

# Rendre obligatoire la maintenance de la documentation Obsidian

## Outcome

Les instructions durables du dépôt obligent les agents à inclure et mettre à
jour les notes Obsidian Wander pertinentes lorsqu'une modification affecte le
backlog, l'architecture technique ou l'expérience utilisateur.

## Context

Le dossier Obsidian existe à l'emplacement suivant :

`/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander`

Le `AGENTS.md` actuel gouverne `docs/`, `todos/` et `docs/solutions/`, mais ne
mentionne ni ce chemin ni la maintenance des quatre notes Wander. Le
propriétaire a explicitement approuvé ce plan le 16 août 2026.

## Scope

- Included:
  - ajouter une règle durable dans `AGENTS.md` ;
  - définir les déclencheurs propres au backlog, à la technique, à l'UX et au
    dashboard ;
  - imposer la mise à jour de la propriété `updated` et la vérification du rendu
    Obsidian ;
  - définir le comportement lorsque le vault iCloud n'est pas accessible.
- Not included:
  - modifier les quatre notes Obsidian ;
  - modifier le code, Firebase, les règles ou le projet Xcode ;
  - imposer une mise à jour pour une refactorisation sans impact documentaire.

## Proposed approach

Ajouter une section `Obsidian Wander Documentation` après les règles Compound
Engineering. Elle nommera le chemin absolu, expliquera quelle note correspond
à chaque type de changement et demandera d'inclure les notes pertinentes dans
le périmètre du plan avant implémentation. Elle préservera le rôle du dépôt
comme source détaillée et empêchera la création d'un faux vault de secours.

## Affected files

- `AGENTS.md` — nouvelle règle durable de maintenance documentaire.
- `docs/plans/2026-08-16-maintenir-documentation-obsidian.md` — suivi du travail.

## Implementation

- [x] Passer le plan à `in_progress` avant de modifier `AGENTS.md`.
- [x] Ajouter le chemin et la table de routage des quatre notes.
- [x] Définir les déclencheurs, les exclusions et le comportement hors vault.
- [x] Définir la validation Obsidian minimale.
- [x] Relire la règle contre le workflow d'approbation existant.

## Edge cases and risks

- Le chemin absolu est propre à la machine du propriétaire — si le vault est
  absent ou non inscriptible, l'agent doit consigner la mise à jour requise et
  la signaler sans créer un autre dossier.
- Une obligation trop large produirait du bruit — les refactorisations internes
  sans impact sur les documents sont explicitement exclues.
- Les notes externes ne doivent pas échapper au plan approval gate — les notes
  pertinentes doivent être listées dans le plan approuvé avant modification.
- Le worktree contient des changements utilisateur — ne modifier aucun fichier
  existant hors de `AGENTS.md`.

## Validation

- [x] Le chemin du vault et les quatre noms de notes figurent dans `AGENTS.md`.
- [x] Les déclencheurs technique, UX et backlog sont explicites.
- [x] Le cas d'un vault indisponible est couvert.
- [x] La règle reste cohérente avec le plan approval gate.
- [x] `git diff --check -- AGENTS.md docs/plans/2026-08-16-maintenir-documentation-obsidian.md` réussit.
- [x] Aucun fichier applicatif, Firebase, Xcode ou Obsidian n'est modifié.

## Acceptance criteria

- [x] Un agent sait déterminer quelle note Obsidian mettre à jour.
- [x] Une modification documentaire est annoncée dans le plan avant le travail.
- [x] La propriété `updated`, les wikilinks, tableaux, callouts et Mermaid sont
  vérifiés lorsque la note concernée les utilise.
- [x] Une refactorisation sans impact documentaire ne déclenche pas de mise à
  jour artificielle.
- [x] L'indisponibilité du vault ne provoque ni faux dossier ni blocage caché.

## Validation results

- Le chemin absolu du vault et les quatre noms de notes sont présents dans
  `AGENTS.md`.
- La règle route séparément les changements de backlog, d'architecture, d'UX
  et de dashboard.
- La propriété `updated` et la vérification Obsidian des propriétés, liens,
  tableaux, callouts, code fences et diagrammes Mermaid sont obligatoires.
- Le cas absent ou non inscriptible interdit tout dossier de substitution et
  impose un signalement explicite dans le plan ou la revue.
- `git diff --check -- AGENTS.md docs/plans/2026-08-16-maintenir-documentation-obsidian.md`
  réussit.
- Aucun build n'a été lancé, car aucun fichier applicatif ou de configuration
  n'a été modifié par ce plan.

## Review notes

- Hardest decision: rendre la règle obligatoire tout en évitant des mises à
  jour artificielles lors de refactorisations sans impact documentaire.
- Rejected alternatives: un rappel générique sans table de routage et une mise
  à jour Obsidian imposée après chaque changement, trop imprécis ou trop bruyant.
- Least certain: le chemin absolu ne sera pas disponible sur toutes les
  machines ; la règle rend donc ce cas visible sans créer de copie divergente.

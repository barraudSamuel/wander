---
title: "Créer le backlog et la documentation Wander dans Obsidian"
status: completed
date: 2026-08-16
approved_at: "2026-08-16"
in_progress_at: "2026-08-16"
completed_at: "2026-08-16T17:42:18+09:00"
owner: "Samuel Barraud"
related: []
tags: [plan, documentation, obsidian]
---

# Créer le backlog et la documentation Wander dans Obsidian

## Outcome

Le vault Obsidian `sam` contient un dossier `wander` autonome et synchronisable
par iCloud avec un tableau de bord, un backlog des fonctionnalités et deux
documents de référence couvrant l'architecture technique et l'expérience UX
actuelles du projet.

## Context

Le dépôt conserve son système Compound Engineering existant dans `docs/` et
`todos/`. L'espace Obsidian est une synthèse produit destinée à la consultation
et à la maintenance manuelle ; il ne remplace pas les plans et findings du
dépôt.

Le propriétaire a explicitement approuvé ce plan le 16 août 2026.

## Scope

- Included:
  - créer le dossier `wander` dans le vault Obsidian `sam` ;
  - créer un dashboard avec des wikilinks vers les trois notes principales ;
  - synthétiser les fonctionnalités ouvertes dans un backlog lisible ;
  - documenter l'architecture, les données, les services et la validation ;
  - documenter les parcours, états UX et principes d'accessibilité ;
  - vérifier le rendu Obsidian des notes.
- Not included:
  - déplacer ou synchroniser automatiquement `docs/` et `todos/` ;
  - modifier l'application, Firebase, les règles ou le projet Xcode ;
  - installer ou configurer un plugin Obsidian ;
  - inventer une roadmap produit au-delà des éléments déjà documentés.

## Proposed approach

Créer quatre notes Obsidian physiques avec un frontmatter homogène, des tags
`wander/*`, des wikilinks internes, des callouts ciblés et un diagramme Mermaid
pour l'architecture. Le backlog distinguera les fonctionnalités produit des
travaux de fiabilité et des dépendances externes.

## Affected files

- `docs/plans/2026-08-16-obsidian-backlog-documentation.md` — suivi du travail.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/00 - Wander.md` — dashboard.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md` — backlog.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md` — référence technique.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md` — référence UX.

## Implementation

- [x] Passer le plan à `in_progress` avant la création des notes.
- [x] Recenser les fonctionnalités, les flux UX et les composants techniques.
- [x] Créer le dashboard et les trois notes Obsidian.
- [x] Vérifier le frontmatter, les wikilinks et le diagramme Mermaid.
- [x] Ouvrir les notes dans Obsidian et contrôler le rendu.
- [x] Revoir le contenu contre le code et les artefacts du dépôt.

## Edge cases and risks

- La synthèse Obsidian peut dériver du dépôt — afficher sa date de mise à jour
  et rappeler que les plans et todos du dépôt restent la source détaillée.
- Un élément de backlog peut être une dette plutôt qu'une fonctionnalité —
  séparer explicitement produit, fiabilité et dépendances externes.
- Le vault est hors du workspace — demander l'autorisation d'écriture ciblée
  uniquement pour le nouveau dossier `wander`.
- Le worktree contient déjà des changements utilisateur — ne modifier aucun
  fichier existant hors de ce plan.

## Validation

- [x] Les quatre fichiers existent dans le dossier Obsidian attendu.
- [x] Le frontmatter est un YAML valide et les tags sont cohérents.
- [x] Tous les wikilinks internes ciblent une note existante.
- [x] Le diagramme Mermaid utilise une syntaxe valide.
- [x] Le rendu est vérifié dans Obsidian en mode lecture.
- [x] `git diff --check` réussit pour le plan du dépôt.
- [x] Les modifications utilisateur préexistantes sont préservées.

## Acceptance criteria

- [x] Le dashboard permet d'ouvrir immédiatement le backlog et les deux docs.
- [x] Le backlog reflète les fonctionnalités et travaux ouverts connus au
  16 août 2026 sans présenter les éléments terminés comme restant à faire.
- [x] La documentation technique permet de comprendre l'architecture et les
  flux de données sans parcourir tout le code.
- [x] La documentation UX décrit les parcours principaux, les états critiques
  et la direction visuelle native iOS.
- [x] Aucun fichier applicatif ou de configuration n'est modifié.

## Validation results

- Quatre fichiers Markdown physiques et aucun lien symbolique sont présents
  dans le dossier `wander` du vault.
- `Psych.safe_load` valide le frontmatter des quatre notes.
- Le contrôle des wikilinks ne trouve aucune cible interne manquante.
- Les copies finales correspondent octet par octet aux fichiers relus.
- Obsidian 1.13.4 rend le dashboard, les propriétés, callouts, tableaux,
  checklists, liens et le diagramme Mermaid compact sans erreur visible.
- `git diff --check -- docs/plans/2026-08-16-obsidian-backlog-documentation.md`
  réussit.
- Aucun build Xcode n'a été lancé : aucun fichier applicatif, Firebase ou de
  configuration n'a été modifié par ce plan.

## Review notes

- Hardest decision: maintenir une synthèse Obsidian utile sans la présenter
  comme un remplacement des plans et findings versionnés dans le dépôt.
- Rejected alternatives: migration complète du système Markdown, liens
  symboliques vers le dépôt et Base Obsidian ; ces options dépassaient le
  périmètre réduit approuvé.
- Least certain: la documentation Obsidian peut dériver si elle n'est pas mise
  à jour après les prochaines fonctionnalités ; chaque note porte donc une date
  `updated` et le dashboard rappelle explicitement la source de vérité.

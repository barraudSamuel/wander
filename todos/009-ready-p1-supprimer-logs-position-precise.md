---
id: "009"
title: "Supprimer les logs de position précise"
status: ready
priority: P1
source: review
created: 2026-08-14
tags: [todo, privacy, location, logging]
---

# Supprimer les logs de position précise

## Finding

`LocationTracker` écrit des coordonnées exactes et des identifiants de cellule
dans les logs applicatifs sans garde de compilation. Ces données sensibles
peuvent donc être exposées dans une build distribuée, contrairement à la règle
de confidentialité du dépôt.

## Evidence

- `wander/LocationTracker.swift` journalise latitude, longitude et précision
  lors des visites et des positions acceptées.
- `AGENTS.md` interdit de journaliser des positions précises ou des identifiants
  d’authentification.

## Acceptance criteria

- [ ] Aucun log applicatif ne contient latitude, longitude ou identifiant H3.
- [ ] Les diagnostics restants utilisent seulement des états agrégés non
  sensibles.
- [ ] Le build Debug pour simulateur réussit.

## Resolution notes

Constaté pendant la revue du plan
`docs/plans/2026-08-14-position-ami-persistante.md`. La correction reste hors du
périmètre fonctionnel approuvé de ce sprint.

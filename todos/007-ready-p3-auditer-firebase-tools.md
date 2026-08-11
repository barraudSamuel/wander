---
id: "007"
title: "Réévaluer les dépendances transitives de Firebase CLI"
status: ready
priority: P3
source: review
created: 2026-08-10
tags: [todo, firebase, security, tooling]
---

# Réévaluer les dépendances transitives de Firebase CLI

## Finding

`npm audit` signale cinq vulnérabilités modérées transitives sous
`firebase-tools@15.26.0`. Cette dépendance sert uniquement à l'émulateur local
des règles et n'est pas embarquée dans l'application iOS. La correction
automatique proposée rétrograde Firebase CLI vers une version qui a produit
des alertes plus sévères pendant la revue ; elle n'est donc pas appliquée.

## Evidence

- `firebase-tests/package.json` épingle `firebase-tools@15.26.0`.
- `npm audit --json` remonte `@opentelemetry/core`, `gaxios` et `uuid` via
  `firebase-tools`, avec une sévérité globale modérée.
- `npm --prefix firebase-tests run test:rules` réussit avec 18 tests sur 18.

## Acceptance criteria

- [ ] Une version maintenue de Firebase CLI ne remonte plus ces avis, sans
      introduire d'alerte de sévérité supérieure.
- [ ] Les tests de règles passent toujours avec le JDK requis par cette version.

## Resolution notes

Mettre à jour uniquement après publication d'une version corrigée et relancer
`npm audit` ainsi que la suite complète de l'émulateur.

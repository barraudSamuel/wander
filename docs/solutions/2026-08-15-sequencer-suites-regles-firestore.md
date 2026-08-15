---
title: "Séquencer les suites de règles Firestore partageant un émulateur"
date: 2026-08-15
category: testing
tags: [solution, firebase, firestore, node, concurrency]
related_plan: "../plans/2026-08-15-sorties-prevues-sprint-06-participation.md"
---

# Séquencer les suites de règles Firestore partageant un émulateur

## Problem

Une nouvelle suite de règles réussissait lorsqu'elle était exécutée seule mais
échouait de manière variable dans la commande complète. Des documents préparés
avec les règles désactivées disparaissaient entre leur création et l'assertion.

## Root cause

`node --test tests/**/*.test.mjs` peut exécuter plusieurs fichiers en parallèle.
Toutes les suites utilisaient le même projet `demo-wander`, le même émulateur et
appelaient `clearFirestore()` dans leur propre `beforeEach`. Une suite pouvait
donc effacer les fixtures d'une autre suite en cours d'exécution.

Les refus observés ressemblaient à des défauts de règles valides : parent de
plan absent, amitié supprimée ou requête retournant soudainement zéro document.

## Solution

La commande de test impose désormais `--test-concurrency=1` :

```text
node --test --test-concurrency=1 tests/**/*.test.mjs
```

Les tests internes à chaque fichier conservent leur isolation avec
`clearFirestore()`. Le projet `demo-wander` et l'émulateur local restent
partagés, mais une seule suite de fichier les manipule à la fois.

## What did not work

- Diagnostiquer uniquement les lignes de refus des règles masquait la
  disparition concurrente des fixtures.
- Relancer toute la matrice sans contrôler la concurrence reproduisait des
  échecs différents selon l'ordonnancement.
- Une exécution isolée prouvait la validité de la nouvelle suite, mais pas la
  stabilité de la commande utilisée en intégration continue.

## Validation

- La nouvelle suite isolée réussit avec 18 tests sur 18.
- La commande complète séquentielle réussit avec 49 tests sur 49.
- Les suites conservent le projet d'émulation explicite `demo-wander` et
  n'accèdent à aucun service Firebase distant.

## Reusable lesson and prevention

Lorsque plusieurs fichiers de tests Firestore partagent un projet d'émulation
et réinitialisent sa base, imposer une concurrence de fichier égale à un ou
attribuer un projet d'émulation indépendant à chaque worker. Toujours comparer
un échec complet à une exécution isolée avant d'assouplir une règle de sécurité.

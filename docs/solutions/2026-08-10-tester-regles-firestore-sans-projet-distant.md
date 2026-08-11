---
title: "Tester les règles Firestore sans projet distant"
date: 2026-08-10
category: testing
tags: [solution, firebase, firestore, security]
related_plan: "../plans/2026-08-10-sorties-prevues-sprint-01-fondations.md"
---

# Tester les règles Firestore sans projet distant

## Problem

Les règles Firestore doivent être testées avec des identités et documents
réalistes, sans risquer de lire ou modifier le projet Firebase configuré dans
`.firebaserc`.

## Root cause

Le SDK de test a besoin d'un émulateur Firestore actif. Une commande utilisant
implicitement le projet par défaut peut rendre la frontière entre validation
locale et environnement distant difficile à vérifier. Les versions récentes de
Firebase CLI exigent également un JDK 21 ou supérieur pour l'émulateur.

## Solution

Les tests sont isolés dans `firebase-tests/` et la commande emploie explicitement
`--project demo-wander`. Firebase traite les identifiants `demo-*` comme des
projets d'émulation : toute tentative d'accès à un service non émulé échoue.
L'émulateur écoute uniquement sur `127.0.0.1:8980`, le port 8080 étant occupé
localement par OrbStack.

Les tests chargent directement `firestore.rules`, recréent leur état avant
chaque cas et utilisent `withSecurityRulesDisabled` uniquement pour préparer
les fixtures. Toutes les opérations vérifiées passent ensuite par les règles.

## What did not work

- Firebase CLI 15 ne démarre pas avec le JDK 17 installé sur la machine.
- Le port 8080 était déjà réservé par OrbStack.
- Rétrograder Firebase CLI pour conserver JDK 17 introduisait des avis de
  sécurité plus sévères dans l'outillage de développement.

## Validation

- 18 tests de règles réussis avec le projet `demo-wander`.
- Le journal de l'émulateur confirme que les services non émulés sont bloqués.
- Aucun déploiement Firebase n'a été exécuté.

## Reusable lesson and prevention

Toujours lancer les tests de règles avec un identifiant `demo-*` explicite,
conserver l'hôte en loopback et séparer la commande de test de la commande de
déploiement. Vérifier le JDK requis lors des mises à jour de Firebase CLI.

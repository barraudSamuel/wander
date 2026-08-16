---
title: "Créer des amis fictifs Firestore sans comptes Apple"
date: 2026-08-16
category: testing
tags: [solution, firebase, firestore, friends, fixtures]
related_plan: "../plans/2026-08-16-seed-amis-test-firestore.md"
---

# Créer des amis fictifs Firestore sans comptes Apple

## Problem

Tester une interface sociale iOS exige plusieurs profils, relations et
positions. Wander n'accepte toutefois que Sign in with Apple et vérifie aussi
l'état du credential Apple. Créer des utilisateurs Firebase Auth administratifs
ne produit donc pas des comptes capables d'ouvrir l'application.

## Root cause

Un ami affiché par Wander n'a pas besoin d'une session active : le client lit
son profil, sa relation et sa dernière position depuis Firestore. Seul le compte
qui exécute l'application doit posséder un jeton Apple valide. Firebase Admin
peut préparer ces documents sans affaiblir les règles destinées aux clients.

## Solution

L'outil `testFriendFixtures` génère des UID et codes amis déterministes à partir
du hash du propriétaire. Chaque fixture contient :

- un profil avec pseudo de test, avatar et couleur valides ;
- un code ami cohérent ;
- une relation acceptée ou une demande entrante ;
- une position distincte sur un lieu public de Séoul.

Un manifeste `_testFriendFixtures/owner-<hash>` conserve les cibles exactes.
Une relance avec la même configuration ne duplique rien. Changer les quantités
exige un nettoyage préalable. La commande de nettoyage valide le manifeste,
supprime d'abord les relations, puis uniquement les profils, codes, positions
et registres de notification dérivés de ces fixtures.

Toutes les commandes sont en lecture seule sans `--apply`. Le projet Firebase
et l'UID propriétaire sont obligatoires et ne sont jamais affichés par l'outil.
Les demandes entrantes sur un projet distant exigent aussi
`--allow-notifications`, car leur création peut envoyer une vraie notification.

## Usage

Les credentials Firebase Admin doivent rester hors du dépôt. Utiliser des
Application Default Credentials ou une variable
`GOOGLE_APPLICATION_CREDENTIALS` pointant vers un fichier local protégé.

Simuler puis créer huit amis acceptés :

```bash
npm --prefix functions run seed:test-friends -- \
  --project wander-1954f \
  --owner-uid "<UID_FIREBASE>"

npm --prefix functions run seed:test-friends -- \
  --project wander-1954f \
  --owner-uid "<UID_FIREBASE>" \
  --apply
```

Ajouter des demandes entrantes demande un nettoyage préalable si un manifeste
existe déjà, puis une nouvelle création avec consentement aux notifications :

```bash
npm --prefix functions run seed:test-friends -- \
  --project wander-1954f \
  --owner-uid "<UID_FIREBASE>" \
  --accepted 8 \
  --pending 3 \
  --allow-notifications \
  --apply
```

Rafraîchir les positions afin qu'elles redeviennent récentes :

```bash
npm --prefix functions run refresh:test-friend-locations -- \
  --project wander-1954f \
  --owner-uid "<UID_FIREBASE>" \
  --apply
```

Simuler puis appliquer le nettoyage :

```bash
npm --prefix functions run cleanup:test-friends -- \
  --project wander-1954f \
  --owner-uid "<UID_FIREBASE>"

npm --prefix functions run cleanup:test-friends -- \
  --project wander-1954f \
  --owner-uid "<UID_FIREBASE>" \
  --apply
```

## Validation

- compilation TypeScript stricte réussie ;
- 24 tests réussis avec le projet d'émulation `demo-wander-fixture-lifecycle` ;
- cycle complet vérifié : collision refusée, simulation sans écriture, création,
  relance idempotente, rafraîchissement, simulation du nettoyage et nettoyage ;
- le profil propriétaire et un document étranger restent présents après le
  nettoyage ;
- les trois aides CLI ont été exécutées ;
- aucun déploiement ni accès au projet Firebase distant.

## Limitations

- les profils fictifs ne peuvent pas se connecter ou agir eux-mêmes ;
- une position reste visible comme dernière position connue, mais devient
  ancienne après trente minutes sans rafraîchissement ;
- les demandes entrantes peuvent déclencher les Cloud Functions et notifications
  de production ;
- le manifeste est volontairement requis pour tout nettoyage : s'il est supprimé
  manuellement, l'outil refuse de deviner les documents à effacer.

## Reusable lesson and prevention

Pour tester un graphe social, séparer l'identité interactive des données de
présentation. Lorsque les comptes secondaires n'ont pas besoin d'agir, des
fixtures Admin déterministes sont plus simples que de faux fournisseurs Auth.
Toute fixture distante doit toutefois avoir un namespace stable, une simulation
par défaut, un consentement d'écriture explicite et un manifeste exact servant
de frontière de nettoyage.

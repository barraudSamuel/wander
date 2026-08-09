---
title: "Supprimer un compte Apple Firebase sans restaurer ses données"
date: 2026-08-09
category: architecture
tags: [solution, authentication, firebase, apple, firestore, swiftdata]
related_plan: "../plans/2026-08-09-deconnexion-suppression-compte.md"
---

# Supprimer un compte Apple Firebase sans restaurer ses données

## Problem

Wander proposait seulement un effacement local. Le compte Firebase Auth, le
profil, le code ami, les relations, la position et l'exploration Firestore
restaient intacts ; une reconnexion pouvait donc restaurer les données que
l'utilisateur pensait avoir supprimées.

À l'inverse, une vraie déconnexion doit fermer la session sans modifier aucune
donnée afin que la reconnexion retrouve le compte.

## Root cause

L'interface confondait nettoyage local et gestion du compte. Aucun service
n'orchestrait la réauthentification Apple récente, la révocation du jeton, les
collections Firestore et Firebase Auth. La synchronisation d'exploration
effectuait en plus une union monotone : sans état de suppression explicite, les
cellules locales pouvaient être renvoyées pendant un nettoyage distant.

## Solution

- Séparer strictement `signOut()` de la suppression : la déconnexion n'appelle
  que Firebase Auth et conserve SwiftData, UserDefaults et Firestore.
- Demander une nouvelle autorisation Apple avec un nonce, réauthentifier le même
  utilisateur Firebase et conserver l'authorization code frais.
- Écrire `deletionRequestedAt` sur le profil depuis le serveur avant tout lot
  destructif. Le service suspend alors listeners, uploads et partage de position.
- Bloquer dans les règles les créations et mises à jour du profil, des relations,
  de la position et de l'exploration lorsque ce marqueur existe.
- Supprimer les cellules et relations par lots, puis la position, le code ami et
  le profil. Toutes les étapes tolèrent une nouvelle tentative.
- Révoquer l'autorisation Apple, supprimer Firebase Auth, puis effacer SwiftData,
  les préférences et le cache Firestore local.

## What did not work

- Supprimer uniquement Firebase Auth : les données Firestore seraient devenues
  orphelines et inaccessibles au client.
- Vider uniquement SwiftData : la restauration cloud les aurait réintroduites à
  la prochaine connexion.
- Autoriser la synchronisation jusqu'au dernier lot : une écriture concurrente
  pouvait recréer une cellule ou une position pendant la suppression.
- Utiliser le premier snapshot Firestore du cache pour activer le marqueur : un
  cache ancien aurait pu suspendre le bootstrap sans confirmation du serveur.

## Validation

- Build Debug pour le simulateur iOS réussi avec Firebase 12.15.
- `git diff --check` réussi après l'implémentation.
- Revue statique des collections, des lots de 400 documents, des barrières
  d'écriture, de l'annulation Apple et de la séparation de la déconnexion.
- L'interface emploie uniquement les composants Apple natifs et reste défilable
  avec Dynamic Type.
- Le parcours réel Apple/Firebase et les règles déployées restent à valider sur
  iPhone ; ils sont suivis dans `todos/001-blocked-p1-add-account-deletion.md`.

## Reusable lesson and prevention

Dans une application offline-first, la suppression de compte est un état de
synchronisation à part entière, pas une suite de `delete()` indépendants. Il
faut d'abord obtenir une preuve d'identité récente, confirmer un marqueur par le
serveur, bloquer tous les producteurs locaux, rendre le nettoyage idempotent,
puis seulement supprimer l'identité distante et les caches locaux.

Une suppression répartie entre Firestore et Firebase Auth ne devient strictement
atomique qu'avec un finaliseur backend. Tant qu'il n'existe pas, garder la
frontière finale aussi courte que possible et la suivre comme risque explicite.

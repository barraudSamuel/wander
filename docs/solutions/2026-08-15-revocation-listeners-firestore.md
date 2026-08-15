---
title: "Traiter une révocation entre listeners Firestore"
date: 2026-08-15
category: architecture
tags: [solution, firestore, listeners, friends, race-condition]
related_plan: "../plans/2026-08-15-revocation-amitie-sans-alerte.md"
---

# Traiter une révocation entre listeners Firestore

## Problem

Lorsqu'un utilisateur retirait un ami, l'ancien ami pouvait voir l'alerte
technique « Accès Firestore refusé » en ouvrant sa liste d'amis. Les données
sociales finissaient par disparaître, mais une révocation normale ressemblait à
une panne Firebase.

## Root cause

Le listener principal de `friendships` et les listeners dépendants du profil,
de la position et de l'exploration évoluent indépendamment. Les règles de ces
ressources consultent la relation d'amitié. Après sa suppression, Firestore peut
donc fermer un listener dépendant avec `permissionDenied` avant que le snapshot
principal ait retiré la relation de l'état local.

Le client vérifiait encore `isAcceptedFriend` avec cet état momentanément
obsolète, puis publiait le refus dans `errorMessage`. L'ordre de livraison entre
requêtes distinctes n'est pas une garantie exploitable.

## Solution

Les listeners dépendants délèguent leurs erreurs à un gestionnaire commun. Une
erreur autre que `FirestoreErrorCode.permissionDenied` conserve le comportement
existant.

Pour un refus d'accès, le gestionnaire retrouve le `pairID` local et effectue
une lecture serveur du document d'amitié. Une seule vérification par relation
peut être active. Les réponses sont gardées par l'UID authentifié, la génération
de session et l'identité de la relation afin qu'une déconnexion ou une nouvelle
relation ne reçoive pas le résultat d'une ancienne vérification.

- Document absent ou invalide : retirer silencieusement la relation, tous les
  listeners dépendants et leurs caches, puis reconstruire les listes publiées.
- Document toujours valide : présenter le refus comme auparavant, car les
  règles ou les données sont réellement incohérentes.

Le retrait de `acceptedFriends` entraîne également la réconciliation existante
des listeners de sorties prévues dans `ContentView`.

## What did not work

- Ignorer tous les `permissionDenied` masquerait une règle mal déployée.
- Attendre un délai arbitraire avant l'alerte ne garantit pas que le listener
  principal ait reçu son snapshot.
- Retirer immédiatement la relation locale sans confirmation ferait disparaître
  un ami lors d'une véritable erreur de permissions.

## Validation

- Le build Debug générique iOS Simulator réussit avec Xcode 26.3.
- Le build est installé et démarre sur l'iPhone 17 Simulator déjà actif.
- La revue statique confirme les deux branches : révocation silencieuse si le
  document est absent ou invalide, erreur visible s'il reste valide.
- Le scénario réel à deux comptes reste à rejouer : le simulateur disponible
  est déconnecté.
- Les tests de règles n'ont pas démarré, car Firebase CLI 15.26 exige Java 21 et
  l'environnement fournit uniquement Java 17 ; aucune règle n'a été modifiée.

## Reusable lesson and prevention

Quand plusieurs listeners Firestore dépendent d'un document d'autorisation, ne
pas supposer qu'ils observeront sa modification dans le même ordre. Traiter un
refus d'une ressource dépendante comme un candidat à la révocation, puis vérifier
la source d'autorisation par un chemin direct avant de décider entre nettoyage
silencieux et erreur utilisateur.

Une future cible XCTest ou un environnement Firestore émulé avec Java 21 devra
couvrir explicitement les deux ordres de livraison. Cette correction ne justifie
pas une nouvelle règle globale dans `AGENTS.md`.

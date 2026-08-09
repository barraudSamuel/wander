---
title: "Restaurer une exploration Firebase dans un cache SwiftData"
date: 2026-08-09
category: architecture
tags: [solution, firebase, firestore, swiftdata, synchronization]
related_plan: "../plans/2026-08-09-restauration-compte-multi-appareil.md"
---

# Restaurer une exploration Firebase dans un cache SwiftData

## Problem

Wander envoyait les identifiants H3 découverts dans Firestore, mais la carte et
la progression lisaient exclusivement SwiftData. Après connexion au même compte
sur un nouvel appareil, les données cloud existaient donc toujours sans jamais
être injectées dans le modèle local rendu par l'interface.

Le profil présentait un risque similaire : les valeurs locales initiales
pouvaient être comparées au profil Firestore avant que le serveur ne soit
établi comme autorité, avec le risque de remplacer un pseudo existant par la
valeur par défaut `Explorer`.

## Root cause

Le listener d'exploration du propriétaire utilisait les documents distants
uniquement comme index des cases déjà envoyées. Il ne publiait pas leurs
identifiants vers `LocationTracker` et ne distinguait pas un snapshot serveur
vide d'un snapshot de cache vide reçu pendant le démarrage.

La synchronisation de profil ne possédait pas non plus de barrière explicite
entre l'hydratation initiale et les écritures sortantes.

## Solution

- Attendre le premier snapshot Firestore qui ne provient pas du cache avant de
  déclarer l'exploration chargée ou de calculer les uploads manquants.
- Publier les cases du propriétaire et leur éventuel `sharedAt`, puis les
  fusionner dans SwiftData avec l'identifiant H3 comme clé.
- Appliquer une union monotone : les cases distantes sont ajoutées, les cases
  locales et leurs métadonnées sont conservées, et aucune absence distante ne
  provoque de suppression locale implicite.
- Republier le store dans `LocationTracker`, reconstruire la heat map et
  recalculer la progression après l'import.
- Renvoyer l'union vers Firestore seulement après le snapshot serveur initial.
- Bloquer les écritures de pseudo et de couleur jusqu'au profil serveur, tout
  en conservant une modification utilisateur explicite faite pendant l'attente.
- Exposer séparément les états chargement, prêt et erreur afin que l'interface
  ne transforme pas une panne réseau en historique vide.

Firestore demeure ainsi la source durable du compte et SwiftData le cache local
rapide et hors ligne utilisé par la carte.

## What did not work

- Considérer la présence des documents Firestore comme une restauration : un
  miroir d'upload ne modifie pas automatiquement le store lu par l'interface.
- Accepter le premier snapshot du cache : sur une installation vierge, un cache
  vide ne prouve pas que le compte ne contient aucune case.
- Remplacer l'ensemble local par l'ensemble distant : cette approche détruirait
  les métadonnées locales plus riches et transformerait une suppression réseau
  accidentelle en perte de données.
- Ajouter CloudKit en parallèle : une seconde source distante aurait introduit
  des conflits sans résoudre le défaut d'orchestration local.

## Validation

- Build Debug pour le simulateur iOS réussi après l'implémentation et la revue.
- `git diff --check` réussi.
- Revue statique des barrières cache/serveur, de l'union monotone, des lots de
  450 écritures et des changements de compte.
- L'écran d'authentification a été lancé et inspecté sur simulateur avec les
  composants iOS natifs.
- Le test complet avec le même compte Apple sur deux appareils reste une
  validation manuelle, faute de session Apple de test dans l'environnement.

## Reusable lesson and prevention

Une donnée sauvegardée dans le cloud n'est récupérable que si le flux inverse
jusqu'au store réellement lu par l'interface existe et est validé. Toute sync
offline-first doit modéliser séparément `non chargé`, `chargé et vide` et
`échec`, puis effectuer la réconciliation avant les écritures sortantes.

Pour les données monotones comme une exploration, préférer l'union et rendre la
suppression explicite. Pour les profils modifiables, hydrater depuis le serveur
avant d'autoriser les écritures locales par défaut.

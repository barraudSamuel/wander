---
title: "Synchroniser des avatars embarqués par identifiant"
date: 2026-08-14
category: architecture
tags: [solution, avatars, firestore, swiftui, migration]
related_plan: "../plans/2026-08-14-avatars-predéfinis.md"
---

# Synchroniser des avatars embarqués par identifiant

## Problem

Une image de profil enregistrée comme JPEG dans `UserDefaults` reste propre à
un appareil. Elle ne peut ni être restaurée après une nouvelle installation, ni
être présentée aux amis. Envoyer chaque image dans Firebase Storage aurait
résolu le transport, mais aurait ajouté un stockage distant, des règles, du
cache et un cycle de suppression inutiles pour un catalogue fixe.

## Root cause

Le modèle distant du profil ne possédait aucune identité d'avatar. Les vues du
propriétaire lisaient directement les octets locaux, tandis que les vues d'amis
ne disposaient que du pseudo et de la couleur.

## Solution

- Livrer les images dans `Assets.xcassets` et attribuer à chacune un identifiant
  immuable indépendant de son nom de fichier.
- Synchroniser uniquement `avatarID` dans `users/{uid}` et le valider par une
  liste fermée dans les règles Firestore.
- Générer aléatoirement l'identifiant d'un nouveau compte une seule fois, puis
  considérer Firestore comme source durable sur les autres appareils.
- Réutiliser la barrière d'hydratation du profil : ne pas écrire une valeur
  locale par défaut avant le premier snapshot serveur.
- Pour un document ancien sans champ, conserver l'avatar local généré, marquer
  la migration comme modification en attente et l'écrire après hydratation.
- Pour le rendu d'un ami ancien, dériver temporairement un identifiant stable de
  son UID afin d'éviter un avatar qui change à chaque reconstruction.
- Conserver un repli SF Symbol pour un identifiant absent ou inconnu.

Les règles autorisent encore la création d'un document sans `avatarID` afin de
ne pas casser une ancienne version de l'app pendant le déploiement. Elles
valident strictement le champ dès qu'il est présent et empêchent sa suppression
une fois migré.

## What did not work

- Générer des visuels sans attendre les ressources fournies par le propriétaire
  aurait modifié la direction artistique. Les assets finaux doivent provenir de
  la source explicitement choisie pour le produit.
- Utiliser `hashValue` pour le repli aurait été instable entre processus Swift.
  Un hachage déterministe explicite est requis.
- Stocker une URL publique ou les octets de l'image dans Firestore aurait ajouté
  du poids, de la bande passante et une surface de sécurité sans bénéfice ici.

## Validation

- Build Debug pour simulateur réussi avec les 12 images actuelles compilées par
  `actool`.
- 22 tests de règles Firestore réussis, dont création, migration, rejet d'un
  identifiant inconnu et lecture par un ami accepté.
- Sélecteur vérifié visuellement sur l'iPhone 17 Simulator : présélection,
  changement instantané, recadrage circulaire et état d'accessibilité.
- `git diff --check` et validation JSON des 12 imagesets réussis.

## Reusable lesson and prevention

Lorsqu'un choix visuel provient d'un catalogue livré avec tous les clients, le
cloud doit stocker son identité, pas le média. Séparer l'identifiant métier du
nom d'asset autorise les renommages locaux et garde le schéma stable.

Toute nouvelle propriété de profil doit suivre les mêmes protections que le
pseudo et la couleur : cache lié à l'UID, snapshot serveur faisant autorité,
modification explicite préservée pendant l'hydratation, migration des documents
anciens et propagation par les listeners d'amis.

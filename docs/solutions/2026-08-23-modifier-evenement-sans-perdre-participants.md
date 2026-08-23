---
title: "Modifier un événement sans perdre ses participants"
date: 2026-08-23
category: architecture
tags: [solution, events, firestore, reliability]
related_plan: "../plans/2026-08-23-modifier-evenement-sans-perdre-participants.md"
---

# Modifier un événement sans perdre ses participants

## Problem

Chaque appui sur « Enregistrer » renouvelait `publicationId`, y compris lorsque
le formulaire était inchangé. Le backend interprétait cette nouvelle identité
comme une republication : les amis recevaient un nouveau push et les
participations de la publication précédente devenaient invisibles puis étaient
nettoyées.

## Root cause

Le même chemin `setData` servait à la création et à la modification. Il
reconstruisait tout le document avec un nouveau `publicationId`. Les règles
exigeaient ce renouvellement et interdisaient en parallèle de modifier la
catégorie. Le compositeur ne comparait pas les valeurs éditables au document
chargé.

## Solution

La création et la mise à jour ont maintenant des chemins distincts :

1. la création génère un nouvel `eventId` et utilise cette valeur comme
   `publicationId` stable ;
2. la mise à jour emploie `updateData`, conserve les identités et renouvelle
   seulement le contenu et les timestamps serveur ;
3. les règles exigent que `eventId`, `ownerId` et `publicationId` restent
   identiques, mais autorisent la catégorie à changer ;
4. le compositeur compare la catégorie et la minute visible avant d’activer
   « Enregistrer », puis répète cette garde avant l’appel au service.

Le `publicationId` inchangé maintient les listeners de participation existants.
Les triggers de notification et de nettoyage voient la même publication et
ignorent donc une modification normale.

## What did not work

- Continuer à renouveler `publicationId` tout en conservant les documents
  `attendees` ne suffisait pas : le client filtre aussi les participations par
  publication courante.
- Supprimer immédiatement `publicationId` du schéma aurait nécessité une
  migration des documents, règles, listeners et payloads de notification.
- Comparer les `Date` à la seconde aurait activé le bouton pour une différence
  que le `DatePicker` n’affiche pas ; la minute est la bonne granularité UX.

## Validation

- Build Debug pour iOS Simulator réussi.
- 28 tests Cloud Functions réussis, avec un test d’intégration ignoré comme
  prévu.
- 31 tests de règles Firestore réussis sous un JDK 21 temporaire, dont la
  modification de catégorie avec `publicationId` stable et la conservation
  d’une participation existante.

## Reusable lesson and prevention

Une identité utilisée par des sous-ressources ne doit pas servir simultanément
de numéro de version renouvelé à chaque mutation. Séparer `create` et `update`,
protéger les champs d’identité dans les règles, puis tester explicitement la
continuité des enfants évite les suppressions implicites. Toute action dont le
backend possède des effets secondaires doit également refuser les mutations
sans changement avant l’écriture.

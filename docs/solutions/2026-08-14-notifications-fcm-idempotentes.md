---
title: "Rendre un dispatch FCM Firestore au plus une fois"
date: 2026-08-14
category: architecture
tags: [solution, firebase, fcm, idempotence, notifications]
related_plan: "../plans/2026-08-10-sorties-prevues-sprint-04-notifications.md"
---

# Rendre un dispatch FCM Firestore au plus une fois

## Problem

Un trigger Firestore peut recevoir plusieurs fois le même événement. Envoyer
directement un multicast FCM à chaque invocation peut donc notifier plusieurs
fois le même appareil pour une seule publication.

## Root cause

L’identifiant de l’événement Cloud Functions ne protège pas à lui seul l’effet
externe produit par FCM. Une vérification suivie d’une écriture n’est pas non
plus atomique : deux invocations concurrentes peuvent toutes les deux conclure
que l’envoi reste à faire.

## Solution

Le document de sortie porte un `publicationId` renouvelé à chaque publication.
Avant chaque envoi, la fonction crée avec la précondition `create` un registre
déterministe sous :

`notificationDispatches/{ownerId}__{publicationId}/devices/{recipientId}__{deviceId}`

Une seule invocation peut créer ce document. Les autres reçoivent
`already-exists` et n’envoient rien à cet appareil. La réservation est faite
avant FCM, ce qui privilégie explicitement la garantie « au plus une fois » :
un crash après réservation peut perdre un envoi, mais ne crée pas de doublon.

Les tokens identiques sont dédupliqués avant réservation, et les erreurs FCM
définitives suppriment le document d’appareil uniquement si son token n’a pas
été rafraîchi entre-temps.

## What did not work

- Marquer toute la publication comme envoyée avant le multicast empêche une
  reprise partielle par appareil.
- Marquer après le multicast laisse une fenêtre de crash pouvant renvoyer le
  même push.
- Se fier uniquement au nombre d’invocations ne protège pas contre leur
  exécution concurrente.

## Validation

- Les tests TypeScript couvrent le ciblage des amitiés acceptées, la
  déduplication des tokens et le contenu privé du message.
- TypeScript compile en mode strict.
- Les règles Firestore interdisent aux clients l’accès aux registres de
  dispatch, qui restent sous le refus global par défaut.

## Reusable lesson and prevention

Pour un effet externe déclenché par Firestore, choisir explicitement entre
« au moins une fois » et « au plus une fois ». Si le produit exige l’absence de
doublon, réserver atomiquement une clé métier déterministe au niveau de l’unité
d’effet — ici la publication et l’appareil — avant d’appeler le service
externe.

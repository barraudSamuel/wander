---
title: "Autoriser un delete Firestore idempotent dans un batch"
date: 2026-09-01
category: firebase
tags: [solution, firestore, rules, batch, participation]
related_plan: "../plans/2026-09-01-corriger-batch-participation.md"
---

# Autoriser un delete Firestore idempotent dans un batch

## Problem

Le client remplace une réponse à une sortie avec un batch atomique : supprimer
la réponse opposée puis écrire la nouvelle. Lors d'une première réponse, le
document supprimé n'existe pas. Firestore évalue néanmoins la règle du
`delete` ; lire `resource.data.participantId` sur cette ressource absente
produit une erreur et refuse toutes les opérations du batch.

## Root cause

Les tests validaient la création d'une réponse et la suppression d'une réponse
existante séparément. Ils ne rejouaient pas le batch réel contenant un
`delete` sans effet. La règle supposait donc implicitement que `resource`
existait pour toute suppression.

## Solution

La règle sépare désormais trois cas :

- l'organisateur peut supprimer une réponse ;
- si le document existe, seul son `participantId` peut le supprimer ;
- si le document n'existe pas, un ami `accepted` peut envoyer le `delete` sans
  effet uniquement tant que l'événement parent existe.

Le troisième cas n'accorde aucun pouvoir sur une donnée existante. Il permet
seulement au batch idempotent du client de continuer jusqu'à la création de la
réponse personnelle, elle-même protégée par les règles d'amitié et d'identité.

## Validation

- Le batch exact réussit pour une première participation et un premier refus.
- Les transitions participation vers refus et refus vers participation
  réussissent atomiquement.
- Un ami accepté ne peut pas supprimer la réponse existante d'un autre compte.
- Les relations `pending` ou `revoking`, un étranger et un événement absent ne
  peuvent pas utiliser la branche de suppression absente.
- La suite complète réussit avec 38/38 tests sur 7 suites sous JDK 21.
- Aucun service Swift, aucune donnée distante et aucun déploiement Firebase
  n'ont été modifiés ou exécutés.

## Reusable lesson

Toute règle de `delete` utilisée dans un batch idempotent doit couvrir
explicitement l'absence de `resource`. Le test doit reproduire l'unité atomique
réelle du client, et pas seulement chaque écriture isolée. L'autorisation du cas
absent doit rester plus étroite que celle du document existant et être protégée
par les mêmes frontières métier.


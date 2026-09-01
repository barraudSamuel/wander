---
title: "Séparer l’autorisation sociale du schéma Firestore"
date: 2026-09-01
category: architecture
tags: [solution, firebase, firestore, security, compatibility]
related_plan: "../plans/2026-09-01-simplifier-regles-firestore.md"
---

# Séparer l’autorisation sociale du schéma Firestore

## Problem

Les règles Firestore validaient simultanément l'acteur, la relation sociale, la
liste exacte des champs, leur format, les timestamps, la publication courante
et la cohérence avec plusieurs documents. Un nouveau champ ou un nouveau
listener pouvait donc rendre une fonctionnalité indisponible même lorsque
l'accès demandé était légitime.

Le cas révélateur concernait la réponse à une sortie : l'état client dépend de
deux documents personnels, sous `attendees` et `declines`. Si un seul listener
recevait `permission-denied`, l'ensemble de la commande devenait
« Participation indisponible ».

## Root cause

L'autorisation et la validation de schéma partageaient les mêmes prédicats. En
outre, certaines lectures de groupe dépendaient des champs de chaque résultat,
notamment `publicationId`. Firestore évaluant une requête contre tous ses
résultats possibles, le client devait reproduire exactement ces contraintes
pour obtenir le droit de lister la collection.

Cette architecture transformait chaque évolution de payload en changement de
sécurité et chaque nouvelle requête en risque de `permission-denied`.

## Solution

Les règles reposent désormais sur une petite matrice d'autorisation :

- toute opération client requiert une session Firebase ;
- les profils sont visibles par leur propriétaire et leurs relations `pending`
  ou `accepted` ;
- positions, explorations, événements et groupes sont visibles seulement par
  le propriétaire et ses amis `accepted` ;
- une demande commence en `pending`, seul son destinataire peut l'accepter et
  l'identité de la paire reste immuable ;
- une relation `revoking` coupe immédiatement tous les accès sociaux ;
- chaque compte écrit uniquement ses ressources ou sa propre réponse ;
- les tokens d'appareil et documents backend conservent leur frontière privée.

Les règles ne valident plus les allowlists de champs, regex, catalogues,
formats temporels, identités de publication ou copies du profil. Les modèles
et décodeurs Swift restent responsables de l'acceptation fonctionnelle d'un
payload. Les règles restent responsables de qui peut lire ou écrire.

## What did not work

- Conserver les champs exacts puis ajouter chaque nouveau champ : cette méthode
  reste incompatible avec des versions de clients qui évoluent séparément.
- Autoriser tous les comptes authentifiés à lire toutes les collections : cela
  aurait simplifié les requêtes, mais exposé positions et sorties aux
  non-amis.
- Rendre Firestore public : cette option ne protège ni les données sociales ni
  les écritures croisées.
- Refondre simultanément le modèle de données : le symptôme fonctionnel pouvait
  être corrigé sans migration ni suppression de données.

## Validation

- `firestore.rules` est passé de 1 048 à 282 lignes.
- 37 tests sur 37 réussissent avec l'émulateur Firestore et JDK 21.
- Les tests couvrent les deux listeners personnels absents, les listes de
  groupes sans filtre de publication, les relations `pending` et `revoking`,
  les non-amis, les UID usurpés, les positions, les explorations, les tokens et
  les documents backend et le refus d'une réponse visant un événement absent.
- Aucun déploiement ni accès à des données Firebase distantes n'a été effectué.

## Reusable lesson and prevention

Une règle Firestore doit commencer par répondre à « qui possède ce chemin ? »
et « quelle relation autorise cette lecture ? ». La forme complète du document
ne doit être validée dans les règles que lorsqu'un champ porte directement une
décision d'autorisation, comme `participants`, `requestedBy`, `status`,
`ownerId` ou `participantId`.

Pour chaque nouvelle collection ou requête, ajouter d'abord des tests négatifs
sur l'accès non authentifié, non ami et croisé, puis un test positif avec un
payload enrichi. Ce test garantit qu'une évolution de schéma ne réintroduit pas
le couplage supprimé.

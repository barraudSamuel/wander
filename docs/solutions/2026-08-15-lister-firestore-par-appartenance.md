---
title: "Autoriser une liste Firestore par appartenance déterministe"
date: 2026-08-15
category: security
tags: [solution, firebase, firestore, rules, authorization]
related_plan: "../plans/2026-08-15-sorties-prevues-sprint-06-participation.md"
---

# Autoriser une liste Firestore par appartenance déterministe

## Problem

Un participant devait pouvoir lister les inscriptions de la sortie qu'il avait
rejointe, sans ouvrir cette liste aux autres amis de l'organisateur. La requête
cliente était déjà bornée par `publicationId`, mais la première règle combinait
ce filtre avec la validation complète de chaque document et de son identifiant.

L'émulateur refusait alors la requête d'un participant valide avec une propriété
de ressource indéfinie. La lecture du même document par chemin direct et la
liste de l'organisateur réussissaient, ce qui isolait le problème au contrat de
requête `list`.

## Root cause

Les règles Firestore ne filtrent pas les résultats après lecture : elles doivent
pouvoir prouver que tous les documents potentiellement retournés satisfont la
règle. Une validation conçue pour `get`, dépendante de l'identifiant capturé du
document, ajoutait une condition que l'autoriseur de requête ne pouvait pas
établir de façon fiable dans ce contexte.

## Solution

Séparer les deux preuves :

1. prouver l'appartenance du demandeur avec le chemin déterministe
   `plans/{owner}/attendees/{publicationId}__{auth.uid}` construit depuis la
   publication active du parent ;
2. exiger que chaque résultat ait le même `publicationId` que ce parent ;
3. envoyer côté client une requête `whereField("publicationId", isEqualTo: ...)`.

La règle vérifie aussi que le plan est actif et que l'amitié avec
l'organisateur est toujours `accepted`. Le document d'appartenance reste créé
par une règle stricte qui valide son identifiant, son profil et ses timestamps.

## What did not work

- Réutiliser sans adaptation le validateur complet d'un document dans
  `allow list`.
- Construire la preuve d'appartenance à partir d'un champ de chaque ressource
  retournée plutôt qu'à partir du parent connu.
- Assouplir la liste pour tous les amis acceptés : cela aurait fait fonctionner
  l'interface, mais aurait supprimé la frontière entre participant et simple
  spectateur.

## Validation

- Une requête filtrée réussit pour l'organisateur et pour un participant actif.
- La même requête échoue pour un ami accepté qui n'a pas rejoint.
- Une requête non filtrée échoue même pour un participant.
- Après suppression de sa participation ou révocation de l'amitié, la requête
  échoue immédiatement.
- La matrice complète réussit avec 52 tests sur 52 dans l'émulateur local.

## Reusable lesson and prevention

Pour autoriser une liste selon une appartenance, préférer un document de membre
à chemin déterministe et une contrainte de requête explicite. Tester ensemble le
cas positif filtré, le lecteur non membre, la requête sans filtre et la perte
d'appartenance. Ne jamais résoudre un refus de requête en ouvrant la collection
à une population plus large que le besoin produit.

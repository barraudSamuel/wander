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

## Frontière produit révisée

Cette frontière participant/spectateur décrit la décision approuvée lors du
sprint d'origine. Elle a été remplacée le 2026-09-01 par une frontière entre
ami actuellement `accepted` de l'organisateur et autre compte, afin de montrer
les participants avant de rejoindre une sortie. La requête reste bornée au
`publicationId` courant, les lectures directes de documents tiers restent
interdites et le client n'ouvre une prévisualisation que pour la fiche
sélectionnée. Voir le plan révisé
[`2026-08-31-afficher-organisateur-fiche-evenement.md`](../plans/2026-08-31-afficher-organisateur-fiche-evenement.md).

La leçon durable reste de définir la population autorisée depuis le besoin
produit, puis de contraindre explicitement la requête et de tester les pertes
d'autorisation. L'élargissement est ici volontaire et approuvé, pas un
contournement d'un refus de règles.

## Validation historique (2026-08-15)

- Une requête filtrée réussit pour l'organisateur et pour un participant actif.
- La même requête échoue pour un ami accepté qui n'a pas rejoint.
- Une requête non filtrée échoue même pour un participant.
- Après suppression de sa participation ou révocation de l'amitié, la requête
  échoue immédiatement.
- Lors de ce sprint, la matrice complète réussissait avec 52 tests sur 52 dans
  l'émulateur local. Ce nombre documente cette validation historique, pas la
  suite actuelle.

## Matrice révisée actuelle (2026-09-01)

- Une requête filtrée sur le `publicationId` courant réussit pour
  l'organisateur, un participant actif et un ami actuellement `accepted` qui
  n'a pas encore rejoint.
- Les requêtes non filtrées ou filtrées sur une publication obsolète échouent
  aussi pour l'organisateur ; celui-ci ne contourne donc pas la frontière de
  publication active.
- La lecture directe du document d'un tiers reste refusée à un ami accepté.
- Les comptes sans amitié acceptée, en attente, non authentifiés ou connectés
  avec un fournisseur non autorisé ne peuvent pas lister le groupe.
- La révocation de l'amitié retire immédiatement l'accès à la liste, tandis
  que le participant peut toujours supprimer sa propre inscription. Une
  transition serveur-horodatée `accepted -> revoking` conserve ensuite un
  tombstone jusqu'au nettoyage backend bidirectionnel des inscriptions.
- Le nettoyage ignore les inscriptions dont `joinedAt` est postérieur à
  `revokedAt`, se reprend après un échec partiel et ne supprime le tombstone
  qu'après le succès des deux directions.
- La suite actuelle réussit avec 52 tests sur 52 dans l'émulateur Firestore
  local. Les 43 tests Functions actifs réussissent également ; un test
  d'intégration préexistant reste explicitement ignoré.

## Reusable lesson and prevention

Pour autoriser une liste selon une appartenance, préférer un document de membre
à chemin déterministe et une contrainte de requête explicite. Tester ensemble le
cas positif filtré, le lecteur non membre, la requête sans filtre et la perte
d'appartenance. Lorsqu'une révocation exige aussi un nettoyage asynchrone,
conserver un état intermédiaire immuable qui coupe les autorisations avant de
supprimer les données dérivées, puis protéger les retries avec un cutoff
serveur. Ne jamais résoudre un refus de requête en ouvrant la collection à une
population plus large que le besoin produit.

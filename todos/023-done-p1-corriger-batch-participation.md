---
id: "023"
title: "Corriger le batch de première participation"
status: done
priority: P1
source: production-validation
created: 2026-09-01
resolved: 2026-09-01
tags: [todo, firebase, firestore, participation, regression]
---

# Corriger le batch de première participation

## Finding

Une première réponse à la sortie échouait avec « Participation impossible ».
Le client supprimait la réponse opposée absente avant de créer la nouvelle dans
un batch. La règle de suppression lisait `resource.data.participantId` alors
que `resource` n'existait pas, ce qui refusait tout le batch.

## Evidence

- Le service appelle `batch.deleteDocument` avant `batch.setData` pour les deux
  choix de réponse.
- La reproduction exacte sous l'émulateur renvoyait `permission-denied` avec
  `Null value error for delete`.
- Les tests précédents exécutaient création et suppression séparément et ne
  couvraient pas cette atomicité.

## Acceptance criteria

- [x] La première participation et le premier refus réussissent.
- [x] Le changement de réponse reste atomique.
- [x] Un ami accepté peut supprimer une réponse opposée absente sans pouvoir
      supprimer la réponse existante d'un autre participant.
- [x] Un événement absent et une relation non acceptée restent refusés.
- [x] La suite complète des règles réussit.

## Resolution notes

Résolu localement le 2026-09-01 par
`docs/plans/2026-09-01-corriger-batch-participation.md` :

- la suppression absente est autorisée seulement pour un ami `accepted` et un
  événement parent existant ;
- les droits sur une réponse existante restent limités à l'organisateur et à
  son `participantId` ;
- le batch réel et les refus croisés sont couverts par 38/38 tests réussis.

Aucun déploiement Firebase et aucune donnée distante n'ont été modifiés. Le
correctif ne prendra effet sur l'appareil qu'après un déploiement séparé des
règles.

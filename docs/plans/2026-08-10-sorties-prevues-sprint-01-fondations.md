---
title: "Sorties prévues — Sprint 1 — Fondations des données"
status: completed
sprint: 1
date: 2026-08-10
completed_at: "2026-08-10T20:07:01+09:00"
depends_on: []
tags: [plan, sprint, firestore, friends]
---

# Sprint 1 — Fondations des sorties prévues

## Status

Ce sprint a été approuvé par le propriétaire le 2026-08-10 et a été complété
le même jour après le build iOS et 18 tests de règles Firestore réussis.

## Outcome

Définir une représentation sécurisée d'une sortie future et les opérations de
base permettant à son propriétaire de la créer, la remplacer, la lire et la
supprimer. Ce sprint ne rend encore aucun contrôle ni marqueur visible dans
l'application.

Une personne possède au maximum une sortie active. Le document contient un nom
de lieu, une adresse facultative, une coordonnée, une heure prévue, un fuseau et
une date d'expiration. Seul le propriétaire peut écrire ; seuls le propriétaire
et ses amis acceptés peuvent lire le document par chemin direct.

## Scope

- Modèle Swift validé pour une sortie prévue.
- Schéma Firestore déterministe `plans/{userID}`.
- Service limité aux opérations de la sortie du compte courant.
- Règles Firestore strictes sur les champs, dates et autorisations.
- Suppression du document lors de la suppression du compte.
- Tests de règles couvrant les accès positifs et négatifs.

## Non-goals

- Aucun formulaire ou bouton dans `ContentView`.
- Aucune recherche MapKit ou résolution d'adresse.
- Aucun écouteur des sorties des amis dans l'interface.
- Aucune annotation cartographique.
- Aucune notification, dépendance FCM ou Cloud Function.
- Aucun déploiement Firebase de production.

## Data contract

Le document `plans/{userID}` doit contenir :

- `ownerId`, égal à l'identifiant du document ;
- `publicationId`, UUID renouvelé à chaque publication ;
- `displayName` et `placeName` normalisés ;
- `address`, facultative ;
- `location`, de type `GeoPoint` ;
- `plannedAt`, dans les prochaines 24 heures ;
- `expiresAt`, au plus deux heures après `plannedAt` ;
- `publishedAt` et `updatedAt`, timestamps serveur ;
- `timeZoneIdentifier`, identifiant IANA valide côté client.

## Affected files

- `wander/OutingPlan.swift` — modèle et logique de validité.
- `wander/OutingPlanService.swift` — CRUD de la sortie personnelle.
- `wander/FriendSyncService.swift` — nettoyage à la suppression du compte.
- `firestore.rules` — validation et contrôle des accès.
- `firebase.json` — émulateur local isolé sur le port 8980.
- `firebase-tests/` — dépendances et tests automatisés des règles.
- `.gitignore` — artefacts locaux Node et Firebase.
- `todos/007-ready-p3-auditer-firebase-tools.md` — suivi de l'audit des
  dépendances de développement.
- `docs/solutions/2026-08-10-tester-regles-firestore-sans-projet-distant.md`
  — procédure locale réutilisable.

## Implementation checklist

- [x] Ajouter le modèle sans dépendance UI.
- [x] Normaliser les chaînes et valider les coordonnées et les dates.
- [x] Ajouter la publication, le remplacement, la lecture et l'annulation.
- [x] Employer les timestamps serveur pour les champs d'audit.
- [x] Ajouter des règles refusant les listes de toute la collection.
- [x] Autoriser la lecture directe uniquement aux amis `accepted`.
- [x] Couvrir le nettoyage lors de la suppression du compte.
- [x] Ajouter les tests de règles positifs et négatifs.
- [x] Relire les journaux pour éviter toute position ou UID sensible.

## Risks

- Une requête de collection trop large pourrait exposer les intentions de tous
  les utilisateurs ; seules des lectures directes doivent être autorisées.
- Une date d'expiration incorrecte laisserait une sortie active trop longtemps.
- Les SDK Admin contournent les règles ; ce sprint ne doit ajouter aucun backend.
- Un changement de schéma dans un sprint ultérieur nécessitera une nouvelle
  approbation et une mise à jour explicite de ce contrat.

## Validation

- [x] Build Debug iOS réussi sans nouvel avertissement issu du sprint.
- [x] Le propriétaire peut créer, remplacer, lire et supprimer sa sortie.
- [x] Un ami accepté peut lire la sortie par chemin direct.
- [x] Un ami en attente, un non-ami et un utilisateur déconnecté sont refusés.
- [x] Toute requête listant `plans` est refusée.
- [x] Les champs supplémentaires, dates invalides et coordonnées invalides sont
      refusés.
- [x] La suppression de compte supprime aussi `plans/{userID}`.

## Completion record

Validations exécutées le 2026-08-10 :

- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug
  -destination 'generic/platform=iOS Simulator' build` — `BUILD SUCCEEDED`.
- `npm --prefix firebase-tests run test:rules`, avec JDK 21 temporaire et le
  projet d'émulation `demo-wander` — 18 tests réussis, aucun échec.
- `git diff --check` — aucune erreur.
- `jq empty firebase.json firebase-tests/package.json
  firebase-tests/package-lock.json` — JSON valides.
- `npm audit --json` — cinq avis modérés limités à l'outillage de test et
  consignés dans `todos/007-ready-p3-auditer-firebase-tools.md`.

Aucun déploiement Firebase ni aucune écriture distante n'a été exécuté.

## Review record

1. La décision la plus délicate était la gestion de l'expiration : le
   propriétaire conserve l'accès pour remplacer ou supprimer son document,
   tandis qu'un ami ne peut plus le lire après `expiresAt`.
2. Une requête de collection, un backend Admin et une validation contre le
   projet Firebase réel ont été écartés car ils élargissaient inutilement
   l'exposition ou le périmètre du sprint.
3. Le point le moins certain reste le parcours réel à deux comptes après
   déploiement des règles ; il n'a volontairement pas été exécuté contre le
   projet distant et sera repris dans la validation de production.

Ne pas commencer le Sprint 2 avant une nouvelle approbation explicite.

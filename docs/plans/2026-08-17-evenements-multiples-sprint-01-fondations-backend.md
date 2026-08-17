---
title: "Événements multiples — Sprint 1 — Fondations backend"
status: completed
sprint: 1
date: 2026-08-17
approved_at: "2026-08-17T08:30:33+09:00"
started_at: "2026-08-17T08:32:00+09:00"
revised_at: "2026-08-17T09:00:00+09:00"
completed_at: "2026-08-17T09:30:47+09:00"
tags: [plan, sprint, firestore, cloud-functions, notifications]
---

# Sprint 1 — Fondations backend des événements multiples

## Status

Ce sprint est `completed`. Le propriétaire l’a approuvé explicitement le
2026-08-17 et le travail backend a été validé localement le même jour. Le
propriétaire a confirmé que l’application n’est pas en production : le contrat
legacy a donc été supprimé sans transition et les événements n’ont aucune
expiration automatique. Le terme `events` est employé dans le contrat backend.
Cette approbation ne couvre ni l’adaptation iOS du Sprint 2, ni la création par
appui long du Sprint 3.

## Outcome

Remplacer le contrat de sortie unique par un contrat backend permettant à un
même propriétaire de posséder plusieurs événements persistants. Chaque
événement possède un identifiant stable, tandis que l’identifiant de publication
continue de versionner les modifications et de protéger l’idempotence des
notifications. Un événement reste disponible jusqu’à son annulation manuelle.

## Scope

- Nouvelle sous-collection `users/{ownerID}/events/{eventID}`.
- `eventId` est un UUID stable, égal à l’identifiant du document.
- `publicationId` reste un UUID renouvelé lors de chaque modification.
- Participations sous
  `users/{ownerID}/events/{eventID}/attendees/{publicationID}__{participantID}`.
- Autorisations limitées au propriétaire, à ses amis acceptés et aux
  participants autorisés selon le même contrat de confidentialité que le
  produit actuel.
- Aucun champ `expiresAt`, aucune règle d’expiration et aucun TTL.
- Triggers Cloud Functions et routes de notification incluant `eventId`.
- Suppression du contrat, des triggers et des tests `plans/{ownerID}`.
- Nettoyage des participations d’une publication remplacée ou lors de
  l’annulation manuelle d’un événement.

## Non-goals

- Aucun changement Swift ou comportement visible dans l’application pendant ce
  sprint backend.
- Aucun appui long, formulaire simplifié ou retrait de contrôle cartographique.
- Aucun déploiement Firebase distant.
- Aucun nettoyage distant avant vérification explicite du projet Firebase
  ciblé au moment du futur déploiement.
- Aucune expiration automatique ; elle fera l’objet d’un chantier ultérieur.

## Dependencies

- Authentification Apple et relations d’amitié existantes.
- Firebase Emulator Suite et Node 22 pour les validations locales.
- Contrats actuels de sortie, participation et notification comme base de
  compatibilité.

## Affected files

- `firestore.rules` — contrat et permissions du nouveau schéma.
- `firebase.json` — configuration Firestore conservée sans TTL ni nouvel index.
- `firebase-tests/tests/outing-plans.rules.test.mjs` — suppression des tests
  legacy.
- `firebase-tests/tests/outing-attendances.rules.test.mjs` — suppression des
  tests legacy.
- `firebase-tests/tests/outing-events.rules.test.mjs` — règles des événements
  persistants.
- `firebase-tests/tests/outing-event-attendances.rules.test.mjs` — règles des
  participations isolées par événement.
- `functions/src/index.ts` — triggers des événements et participations.
- `functions/src/notificationLogic.ts` — routes et identités de dispatch.
- `functions/src/notificationLogic.test.ts` — tests unitaires des routes.
- `docs/notifications-apns-configuration.md` — nouveau payload de routage.
- `docs/plans/2026-08-17-evenements-multiples-sprint-01-fondations-backend.md`
  — suivi du sprint.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md`
  — statut du chantier.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md`
  — schéma et responsabilités backend.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/00 - Wander.md`
  — portée produit et état du projet.

## Implementation checklist

- [x] Définir les champs exacts et l’identité de
  `users/{ownerID}/events/{eventID}`.
- [x] Autoriser plusieurs documents persistants pour un même propriétaire.
- [x] Conserver les limites de programmation, textuelles et géographiques.
- [x] Retirer `expiresAt`, le TTL et toute logique d’expiration.
- [x] Isoler les participations par événement et par version de publication.
- [x] Refuser toute lecture ou écriture hors relation autorisée.
- [x] Supprimer les règles, triggers et tests legacy `plans`.
- [x] Ajouter les triggers `events` et le nettoyage des participations lors
  d’une modification ou d’une annulation.
- [x] Inclure `eventId` dans les payloads et dispatches nouveaux.
- [x] Couvrir les règles et la logique de notification par des tests.
- [x] Mettre à jour la documentation du dépôt et le vault Obsidian.
- [x] Simplifier et revoir le diff avant validation finale.

## Risks

- Une règle de liste insuffisamment contrainte pourrait révéler les événements
  d’un inconnu ; le propriétaire est donc fixé par le chemin `users/{ownerID}`.
- Une identité de dispatch incomplète pourrait fusionner deux événements du
  même propriétaire ; `eventID` doit participer à chaque identité nouvelle.
- Firestore ne supprime pas automatiquement les sous-collections ; les triggers
  doivent nettoyer l’ancienne publication après une modification et toutes les
  participations après une annulation.
- Le retrait du legacy casse volontairement l’application actuelle si le
  backend est déployé seul ; aucun déploiement ne doit précéder le Sprint 2.
- Le vault Obsidian se trouve hors du dépôt ; ses trois notes concernées ont été
  mises à jour puis vérifiées dans la vue de lecture pendant ce sprint.

## Validation

- [x] Deux événements valides du même propriétaire peuvent coexister.
- [x] Un ami accepté peut interroger les événements de ce propriétaire.
- [x] Un ami en attente, un inconnu et une session non Apple sont refusés.
- [x] Un événement reste lisible jusqu’à son annulation manuelle.
- [x] Une participation ne peut viser ni le mauvais événement ni la mauvaise
  publication.
- [x] Le propriétaire et les participants autorisés voient uniquement la liste
  permise pour cet événement.
- [x] Aucun contrat ou test `plans/{ownerID}` ne subsiste.
- [x] `npm --prefix functions test` réussit.
- [x] `npm --prefix firebase-tests run test:rules` réussit, ou le blocage local
  JDK déjà connu est documenté avec sa sortie exacte.
- [x] Aucun déploiement distant n’est exécuté.

### Résultats exacts

- `npm test` dans `functions/` : compilation TypeScript réussie, 27 tests,
  26 réussis, 1 ignoré volontairement pour le cycle de fixtures émulateur.
- `JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home npm run test:rules`
  dans `firebase-tests/` : 27 tests réussis, aucun échec.
- `git diff --check` : aucune erreur d’espace ou de patch.
- Recherche ciblée : aucune référence à `plans`, `outingEvents` ou `expiresAt`
  dans `firestore.rules` et `functions/src/`.
- Les notes `Backlog features.md`, `Documentation technique.md` et
  `00 - Wander.md` ont été relues dans la vue de lecture Obsidian ; propriétés,
  wikilinks, tableau du schéma et contenu modifié sont rendus correctement.
- Aucun déploiement Firebase et aucune suppression distante n’ont été lancés.

## Review

- Aucun finding P1, P2 ou P3 ne reste ouvert pour ce sprint.
- La revue a détecté que les participations d’une ancienne publication seraient
  devenues orphelines sans expiration. Le trigger
  `cleanupReplacedEventAttendances` les supprime désormais à chaque changement
  de `publicationId`, tandis que `cleanupEventAttendances` nettoie tout lors de
  l’annulation.
- Aucun nouveau fichier `todos/` n’est nécessaire, le point ayant été corrigé
  et revalidé avant la clôture.

## Compound

Le comportement Firestore selon lequel la suppression d’un document ne
supprime pas ses sous-collections était déjà documenté dans le plan. Aucun
nouvel apprentissage réutilisable distinct ne justifie un fichier
`docs/solutions/` supplémentaire.

## Acceptance criteria

- Le nouveau contrat autorise plusieurs événements persistants avec des
  identités et participations sans collision.
- Les règles empêchent toute extension des droits sociaux existants.
- Les notifications nouvelles routent un événement précis.
- Le schéma legacy et ses tests sont supprimés sans transition.
- La configuration est prête pour le Sprint 2 sans être encore consommée par
  l’application publiée.

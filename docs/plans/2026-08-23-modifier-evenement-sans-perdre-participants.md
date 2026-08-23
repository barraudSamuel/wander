---
title: "Modifier un événement sans perdre ses participants"
status: blocked
date: 2026-08-23
approved_at: "2026-08-23T14:33:12+09:00"
started_at: "2026-08-23T14:33:12+09:00"
blocked_at: "2026-08-23T14:50:25+09:00"
owner: "Samuel"
related:
  - "todos/017-ready-p2-gerer-publication-confirmee-relecture-echouee.md"
tags: [plan, ios, firebase, events, reliability]
---

# Modifier un événement sans perdre ses participants

## Outcome

Permettre à l'organisateur de modifier la catégorie ou l'heure d'un événement
existant sans créer une nouvelle identité de publication, retirer les
participants, renvoyer une notification de publication ou enregistrer un
formulaire inchangé.

## Context

Le publisher commun renouvelle actuellement `publicationId` à chaque écriture.
Les listeners de participation, les règles et le nettoyage Cloud Functions
interprètent ce renouvellement comme le remplacement de la publication et
retirent donc les participations précédentes. Le compositeur autorise aussi une
écriture identique au document chargé.

## Scope

- Inclus :
  - distinguer explicitement la création de la mise à jour ;
  - conserver `eventId`, `ownerId` et `publicationId` lors d'une modification ;
  - mettre à jour le document existant sans le recréer s'il a disparu ;
  - rendre la catégorie modifiable dans le compositeur ;
  - activer l'enregistrement seulement si la catégorie ou la minute affichée a
    changé ;
  - adapter les règles et leurs tests ;
  - maintenir les aperçus Obsidian concernés.
- Non inclus :
  - rendre le lieu modifiable dans l'interface ;
  - notifier les amis à chaque modification ;
  - corriger l'écriture confirmée dont la relecture échoue ;
  - ajouter une résolution de conflits multi-appareils ou une stratégie hors
    ligne.

## Proposed approach

La création garde le contrat actuel et produit un nouvel `eventId` et un nouveau
`publicationId`. La mise à jour reçoit l'événement chargé, vérifie son
propriétaire, puis utilise `updateData` avec seulement les champs de contenu et
les timestamps serveur. Le `publicationId` stable conserve les documents
`attendees` et empêche les triggers actuels de traiter la modification comme une
nouvelle publication.

Les règles continuent de protéger l'identité, le schéma, les dates et les types,
mais exigent désormais que `publicationId` soit conservé au lieu d'être
renouvelé. La catégorie devient un champ de contenu modifiable. `publishedAt` et
`updatedAt` restent renouvelés lors d'une vraie modification afin de préserver
la rétention actuelle de douze heures.

## Affected files

- `wander/OutingPlanPublishing.swift` — séparer création et mise à jour stable.
- `wander/OutingPlanService.swift` — router la sauvegarde selon l'existence de
  l'événement.
- `wander/OutingPlanComposerView.swift` — catégorie éditable et détection des
  changements visibles.
- `firestore.rules` — conserver l'identité de publication et autoriser la
  catégorie modifiée.
- `firebase-tests/tests/outing-events.rules.test.mjs` — adapter le contrat de
  mise à jour.
- `firebase-tests/tests/outing-event-attendances.rules.test.mjs` — vérifier la
  continuité des participations.
- `docs/notifications-apns-configuration.md` — corriger le cycle de vie des
  participations après modification.
- `todos/017-ready-p2-gerer-publication-confirmee-relecture-echouee.md` — garder
  les preuves et le périmètre cohérents après le refactor du publisher.
- `docs/solutions/2026-08-23-modifier-evenement-sans-perdre-participants.md` —
  consigner le contrat réutilisable après validation.
- `docs/plans/2026-08-23-modifier-evenement-sans-perdre-participants.md` — suivre
  le travail et sa validation.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md`
  — mettre à jour l'état de la gestion des événements.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md`
  — documenter l'identité stable et les règles de mutation.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`
  — documenter la catégorie éditable et le bouton conditionnel.

## Implementation

- [x] Séparer les chemins de création et de mise à jour du publisher.
- [x] Préserver l'identité de l'événement et de sa publication lors d'une mise à
  jour.
- [x] Rendre la catégorie éditable et bloquer les écritures sans changement.
- [x] Adapter les règles Firestore et leurs tests.
- [x] Vérifier que les participations restent rattachées après modification.
- [x] Mettre à jour le todo et la documentation.
- [x] Simplifier et revoir le diff.

## Edge cases and risks

- Les anciennes versions de l'app renouvellent `publicationId` et ne pourront
  plus modifier un événement après le déploiement du contrat strict ; les
  créations restent compatibles.
- Les secondes ne sont pas affichées par le `DatePicker` ; la comparaison doit
  donc suivre la minute visible plutôt que l'égalité exacte des `Date`.
- Une mise à jour après suppression distante ne doit pas recréer silencieusement
  l'événement ; `updateData` doit échouer dans ce cas.
- Les tests de règles nécessitent Java 21, absent au début du sprint ; la
  validation ne pourra être déclarée complète sans exécution ou limitation
  explicitement rapportée.

## Validation

- [x] Le build Debug iOS Simulator réussit sans nouvel avertissement.
- [x] Les tests Cloud Functions réussissent.
- [x] Les tests de règles Firestore réussissent sous Java 21.
- [ ] En édition, le bouton est désactivé tant que catégorie et minute sont
  inchangées.
- [ ] Une catégorie ou une minute différente active le bouton et persiste.
- [ ] Revenir aux valeurs visibles initiales désactive le bouton.
- [x] Une participation existante reste associée après modification.
- [ ] La création et l'extension de partage restent fonctionnelles.
- [x] Les notes Obsidian affectées sont vérifiées en vue lecture.

### Résultats au 23 août 2026

- `xcodebuild` Debug pour iOS Simulator : succès. Aucun nouvel avertissement ;
  l'avertissement préexistant sur le `CFBundleVersion` de l'extension reste
  présent (`15` contre `25` pour l'app).
- Tests Cloud Functions : 29 tests, 28 réussis et 1 ignoré.
- Tests des règles Firestore sous Temurin Java 21 temporaire : 31 tests réussis,
  aucun échec ni test ignoré.
- `git diff --check` : aucun problème d'espaces ou de patch.
- Revue manuelle : aucun finding P1 ou P2 ; aucun nouveau fichier n'est requis
  dans `todos/`.
- Les trois notes Obsidian affectées ont été ouvertes en aperçu et leurs
  propriétés, liens, tableaux/listes et sections modifiées ont été contrôlés.
- Validation interactive bloquée : tous les simulateurs iPhone 17 sont éteints.
  Aucun appareil n'a été démarré, conformément à la règle du dépôt qui exige
  l'accord explicite du propriétaire.

## Acceptance criteria

- Une modification conserve `eventId` et `publicationId`.
- Une modification valide ne supprime aucun participant.
- La catégorie et l'heure peuvent être modifiées par l'organisateur.
- Un formulaire inchangé ne déclenche aucune écriture Firestore.
- Une modification ne déclenche pas une nouvelle notification de publication.

## Review notes

- Hardest decision: conserver `publishedAt` renouvelé pour ne pas modifier en
  parallèle la politique de rétention existante.
- Rejected alternatives: supprimer `publicationId` des participations aurait
  imposé une migration de schéma disproportionnée.
- Least certain: compatibilité des anciennes versions après déploiement des
  règles strictes.
- Remaining validation: démarrer explicitement l'iPhone 17 Simulator, puis
  vérifier les trois états du bouton, la persistance catégorie/heure, la
  création et le parcours de l'extension de partage.

---
title: "Événements multiples — Sprint 2 — Adaptation iOS"
status: completed
sprint: 2
date: 2026-08-17
approved_at: "2026-08-17T10:08:00+09:00"
started_at: "2026-08-17T10:09:00+09:00"
completed_at: "2026-08-17T10:28:00+09:00"
tags: [plan, sprint, ios, swiftui, mapkit, firestore]
---

# Sprint 2 — Adaptation iOS aux événements multiples

## Outcome

Faire consommer à l’application iOS le contrat
`users/{ownerID}/events/{eventID}` livré au Sprint 1. Plusieurs événements d’un
même utilisateur doivent pouvoir être chargés, affichés, sélectionnés, modifiés,
annulés et rejoints indépendamment, sans aucune expiration locale.

## Scope

- Ajouter l’identité stable `eventId` au modèle iOS et retirer `expiresAt`.
- Observer les sous-collections `events` du compte et des amis acceptés.
- Publier, modifier et annuler un événement par son `eventId`.
- Observer et modifier les participations sous chaque événement.
- Indexer l’état de carte, la sélection, les cartes de détail et les routes de
  notification par événement plutôt que par seul propriétaire.
- Accepter les payloads `eventPublished` et `eventAttendanceCreated` du Sprint 1.
- Conserver temporairement le compositeur, son bouton, sa mini-carte et sa
  recherche existants ; leur suppression appartient au Sprint 3.
- Supprimer toute logique de timer ou de filtrage fondée sur une expiration.

## Non-goals

- Aucun geste d’appui long sur la carte.
- Aucun retrait du bouton d’ajout, de la mini-carte ou de la recherche.
- Aucun déploiement Firebase ni nettoyage distant.
- Aucun changement de direction visuelle hors adaptation fonctionnelle native.

## Affected files

- `wander/OutingPlan.swift`
- `wander/OutingAttendance.swift`
- `wander/OutingPlanService.swift`
- `wander/OutingAttendanceService.swift`
- `wander/OutingPlanComposerView.swift`
- `wander/OutingPlanDetailCardView.swift`
- `wander/ContentView.swift`
- `wander/MapWithFogView.swift`
- `wander/NotificationService.swift`
- `wander/FriendSyncService.swift`
- `docs/plans/2026-08-17-evenements-multiples-sprint-02-adaptation-ios.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/00 - Wander.md`

## Implementation checklist

- [x] Adapter les modèles au contrat `events` persistant.
- [x] Charger plusieurs événements par propriétaire.
- [x] Publier et annuler un événement précis.
- [x] Isoler les listeners et écritures de participation par événement.
- [x] Afficher plusieurs annotations d’un même propriétaire.
- [x] Sélectionner et router un événement par `eventId`.
- [x] Retirer les timers et filtres d’expiration.
- [x] Mettre à jour la suppression de compte pour le nouveau chemin.
- [x] Mettre à jour la documentation du dépôt et le vault Obsidian.
- [x] Simplifier et revoir le diff.

## Risks

- Une clé basée seulement sur `ownerID` écraserait les autres événements du
  même utilisateur ; chaque état de collection et de carte doit utiliser
  `eventId`.
- Un listener mal détaché pourrait laisser apparaître les événements d’une
  amitié révoquée.
- Une route de notification sans `eventId` sélectionnerait le mauvais marqueur.
- Le backend du Sprint 1 ne doit pas être déployé avant que cette adaptation
  iOS soit validée et livrée avec lui.

## Validation

- [x] Le projet compile sans avertissement Swift nouveau.
- [x] Deux événements du même propriétaire coexistent dans l’état et sur la
  carte.
- [x] La sélection, la modification, l’annulation et la participation visent le
  bon `eventId`.
- [x] Un événement passé reste visible jusqu’à son annulation.
- [x] Une révocation retire tous les événements et listeners concernés.
- [x] Les anciennes routes ou références `plans` et `expiresAt` ne subsistent
  plus dans le code iOS concerné.
- [x] Le build Debug réussit pour la destination iPhone 17 configurée, sans
  créer ni télécharger de runtime.
- [x] Aucun déploiement Firebase ni nettoyage distant n’est exécuté.

### Résultats exacts

- `xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration
  Debug -destination 'platform=iOS Simulator,name=iPhone 17'
  CODE_SIGNING_ALLOWED=NO build` — succès, code de sortie `0`.
- `git diff --check` — succès, aucune erreur d’espace ou de patch.
- Recherche ciblée dans les dix fichiers Swift concernés — aucune référence à
  `expiresAt`, au chemin `plans` ni aux anciens payloads `outing*`.
- Revue structurelle — collections, état de carte, sélection, édition,
  annulation, participation et routes indexés par la valeur Firestore exacte de
  `eventId` ; les listeners d’un propriétaire révoqué retirent tous ses
  événements et états de participation.
- Les quatre notes Wander ont été ouvertes et vérifiées dans la vue Aperçu
  d’Obsidian ; propriétés, wikilinks, tableau, callout et diagramme Mermaid sont
  rendus.
- Aucun finding de revue nouveau ne justifie un fichier `todos/` distinct.
- Aucun simulateur n’était démarré au moment du test de lancement final ; aucun
  appareil ni runtime n’a donc été démarré ou créé. Les scénarios sociaux réels
  restent à rejouer après livraison conjointe du backend et de l’app iOS.

## Acceptance criteria

- L’application iOS est compatible avec le backend `events` du Sprint 1.
- Plusieurs événements par utilisateur sont représentés sans collision.
- Aucun événement n’est masqué ou supprimé en raison du temps écoulé.
- Le Sprint 3 peut remplacer le compositeur par l’appui long sans nouvelle
  migration de données.

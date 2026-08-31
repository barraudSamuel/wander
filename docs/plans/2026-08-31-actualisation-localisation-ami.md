---
title: "Actualiser la localisation d’un ami à la sélection"
status: in_progress
date: 2026-08-31
owner: "Samuel Barraud"
related: []
tags: [plan, location, friends, apns, map]
---

# Actualiser la localisation d’un ami à la sélection

## Outcome

Sélectionner un ami sur la carte demande automatiquement une position récente.
Pendant la requête, un indicateur d’activité système recouvre son avatar ; il
disparaît à la réception d’une nouvelle position, lorsque le backend répond
qu’aucun réveil n’est nécessaire ou disponible, ou après un délai borné.

## Context

Wander partage aujourd’hui les positions reçues par le suivi Core Location
avant/arrière-plan. Le projet utilise APNs via FCM pour les notifications
visibles, mais ne possède pas encore de Location Push Service Extension.

Le plan a été approuvé explicitement par Samuel le 2026-08-31.

## Scope

- Included:
  - déclencher une actualisation lorsque MapKit sélectionne le pin d’un ami ;
  - couvrir le toucher direct, le rail, l’indicateur hors champ et « Voir sur
    la carte » puisqu’ils convergent vers la sélection MapKit ;
  - afficher un loader natif par-dessus l’avatar du pin concerné ;
  - enregistrer un token APNs Location Push distinct du token FCM ;
  - vérifier côté serveur l’amitié acceptée, la fraîcheur et la fréquence ;
  - réveiller une extension qui publie une position unique dans Firestore ;
  - préserver la dernière position connue si l’actualisation échoue ;
  - documenter la configuration Apple/APNs et les limites de validation.
- Not included:
  - remplacer le suivi Core Location continu ou significatif ;
  - activer implicitement le partage si l’exploration ou le suivi arrière-plan
    est désactivé ;
  - déployer les fonctions, règles ou secrets Firebase ;
  - modifier Apple Developer, les profils ou App Store Connect.

## Proposed approach

Un service principal enregistre le token Location Push seulement lorsque le
compte partage effectivement sa position avec l’autorisation « Toujours ». La
sélection d’un ami appelle une Cloud Function authentifiée. Celle-ci refuse les
relations non acceptées, réutilise une position de moins de cinq minutes,
applique une fenêtre de déduplication et envoie directement à APNs les pushes
`location` pour les appareils éligibles.

L’extension demande une seule position et la publie avec la session Firebase
Auth partagée. Le listener Firestore existant reste la source de vérité côté
demandeur : une valeur `updatedAt` postérieure à la demande termine le loader.
Un timeout garantit que l’UI ne reste jamais bloquée.

## Affected files

- `wander.xcodeproj/project.pbxproj` — target d’extension, dépendances et
  Firebase Functions.
- `wander/wander.entitlements` — entitlement Location Push.
- `wander/Info.plist` — description explicite du partage à la demande.
- `wander/ContentView.swift` — composition et observation du service.
- `wander/FriendSyncService.swift` — nettoyage des tokens et du quota lors de
  la suppression de compte.
- `wander/MapWithFogView.swift` — sélection d’ami et loader du pin.
- `wander/LocationPushService.swift` — enregistrement du token et état des
  actualisations.
- `wander/LocationPushSharedConfiguration.swift` — consentement partagé entre
  l’app et l’extension.
- `WanderLocationPushExtension/Info.plist` — point d’extension Apple.
- `WanderLocationPushExtension/WanderLocationPushExtension.entitlements` —
  groupes partagés.
- `WanderLocationPushExtension/LocationPushServiceExtension.swift` — position
  unique et publication Firestore.
- `firestore.rules` — stockage privé des tokens Location Push.
- `firebase-tests/tests/location-push.rules.test.mjs` — couverture des règles.
- `functions/src/index.ts` — fonction callable et envoi APNs.
- `functions/src/locationPushLogic.ts` — validation et décisions testables.
- `functions/src/locationPushLogic.test.ts` — tests unitaires backend.
- `docs/notifications-apns-configuration.md` — configuration et validation.
- `docs/solutions/2026-08-31-location-push-ami.md` — apprentissage réutilisable
  après validation.
- `docs/plans/2026-08-31-actualisation-localisation-ami.md` — suivi du travail.
- `todos/019-ready-p1-deployer-valider-location-push.md` — configuration et
  validation physiques restant à effectuer.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md`
  — ajouter la fonctionnalité et son statut.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md`
  — localisation, schéma Firestore et notifications.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`
  — amis sur la carte et confidentialité.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/00 - Wander.md`
  — état du projet.

## Implementation

- [x] Ajouter le contrat backend, les garde-fous et les tests.
- [x] Ajouter les règles privées des tokens et leurs tests.
- [x] Ajouter l’enregistrement Location Push dans l’app.
- [x] Ajouter la Location Push Service Extension.
- [x] Déclencher la requête sur la sélection MapKit.
- [x] Afficher et terminer correctement le loader du pin.
- [x] Simplifier et revoir le diff.
- [x] Exécuter les validations locales et consigner leurs résultats.
- [x] Mettre à jour la documentation disponible dans le workspace.
- [ ] Mettre à jour et vérifier les quatre notes Obsidian après obtention de
      l’accès en écriture au vault.

## Edge cases and risks

- Un ami peut ne pas avoir l’autorisation « Toujours », le partage actif ou un
  token valide — le backend répond sans push et l’ancienne position reste
  visible.
- APNs peut retarder ou ignorer le réveil — le loader possède un timeout et le
  listener Firestore reste la seule preuve d’une nouvelle position.
- Les Location Push sont contingentés par iOS — une position encore fraîche et
  les demandes rapprochées ne déclenchent pas un nouveau réveil.
- Une amitié peut être révoquée entre le toucher et l’envoi — le backend relit
  l’amitié avant chaque dispatch.
- Plusieurs appareils peuvent être enregistrés — la première nouvelle position
  valide termine le loader, les tokens invalides sont nettoyés.
- Le vault Obsidian est présent mais non accessible en écriture depuis cette
  session — les sections non mises à jour seront signalées exactement.

## Validation

- [x] `functions`: build TypeScript et 38 tests exécutés — 37 réussis, 1 test
      d’intégration existant ignoré, 0 échec.
- [x] `firebase-tests`: 42 tests de règles réussis sous l’émulateur, 0 échec.
- [x] Build Debug générique app + extension réussi sans sortie d’avertissement.
- [x] Toucher direct, rail, indicateur hors champ et « Voir sur la carte »
  convergent vers une requête unique.
- [x] La revue du cycle d’état confirme que le loader apparaît immédiatement et
  disparaît sur réception, absence de
  token, erreur et timeout.
- [x] Les relations pending, étrangères ou révoquées ne peuvent pas demander
  une position.
- [x] Aucun token, identifiant d’authentification ou coordonnée précise n’est
  journalisé.
- [ ] VoiceOver, contraste, mode sombre et Réduire les animations sont vérifiés.
- [ ] Deux appareils physiques valident APNs sandbox puis production après la
  configuration externe du propriétaire.

## Acceptance criteria

- Un ami éligible sélectionné obtient une nouvelle position et son pin se met à
  jour sans action supplémentaire.
- Le loader ne recouvre que l’avatar concerné et ne peut pas rester permanent.
- Un utilisateur non autorisé ne peut ni lire les tokens ni déclencher une
  requête Location Push.
- Le suivi d’exploration existant et les notifications FCM restent inchangés.

## Review notes

- Hardest decision: utiliser le listener de position existant comme accusé de
  réception fiable plutôt qu’inventer un second état client faisant autorité.
- Rejected alternatives: silent FCM, polling arrière-plan et réveil à chaque
  toucher malgré une position récente.
- Least certain: comportement APNs réel avant signature, secrets et validation
  sur deux appareils physiques.
- Local review: `npm test`, les tests d’émulateur Firestore, `plutil`,
  `git diff --check` et le build Xcode Debug ont réussi le 2026-08-31.
- Remaining external validation: capability et profils Apple, secrets Firebase,
  déploiement ciblé, accessibilité en exécution et APNs sandbox/production sur
  deux appareils physiques. Suivi dans
  `todos/019-ready-p1-deployer-valider-location-push.md`.
- Obsidian pending because the vault is read-only in this session:
  `Backlog features.md` (« En cours »), `Documentation technique.md`
  (« Exploration et localisation », « Schéma Firestore principal »,
  « Notifications »), `Documentation UX.md` (« Amis sur la carte »,
  « Permissions et confidentialité ») et `00 - Wander.md` (« État du projet »).

---
title: "Sorties prévues — Sprint 4 — Notifications privées"
status: in_progress
sprint: 4
date: 2026-08-10
completed_at:
depends_on:
  - "Sprint 1 completed"
  - "Sprint 2 completed"
  - "Sprint 3 completed"
tags: [plan, sprint, fcm, apns, functions]
---

# Sprint 4 — Notifier les amis acceptés

## Status

Ce sprint est `in_progress`. Il implique de nouvelles capacités Apple et un
backend déployable. Son implémentation a été approuvée après la validation
complète des trois premiers sprints.

## Outcome

Lorsqu'une nouvelle publication est créée, chaque appareil enregistré des amis
acceptés reçoit au plus une notification. Le message contient uniquement le
pseudo, le nom du lieu et l'heure, jamais l'adresse ni les coordonnées.

Toucher la notification ouvre Wander, relit le document sous les autorisations
actuelles, puis centre la carte seulement si la relation et la sortie sont
encore valides.

## Scope

- Firebase Messaging dans le projet iOS.
- Capacité Push Notifications et mode arrière-plan nécessaire.
- Permission demandée dans un contexte explicite et gérée depuis le profil.
- Un token FCM privé par installation dans `users/{uid}/devices/{deviceId}`.
- Suppression du token lors de la déconnexion et de la suppression du compte.
- Cloud Function Firestore ciblant uniquement les amitiés `accepted`.
- Registre de dispatch déterministe empêchant les doublons.
- Routage interne du toucher vers l'annotation du Sprint 3.
- Tests unitaires du ciblage et du contenu du push.

## Non-goals

- Aucun envoi aux demandes d'ami en attente ou aux non-amis.
- Aucun topic FCM public.
- Aucune coordonnée, adresse complète ou UID dans le texte visible.
- Aucun déploiement de production automatique dans ce sprint sans autorisation
  distincte.
- Aucune notification d'annulation.

## Data contract

`users/{uid}/devices/{deviceId}` contient seulement `token`, `platform` et
`updatedAt`. Le payload contient `type`, `outingOwnerId` et `publicationId` pour
le routage ; les données de destination sont relues depuis Firestore.

## Affected files

- `wander/NotificationService.swift` — permission, token et routage.
- `wander/WanderAppDelegate.swift` et `wander/wanderApp.swift` — delegates
  APNs/FCM et cycle de vie de l'application.
- `wander/ContentView.swift` — ouverture ciblée et réglage utilisateur.
- `wander/OutingPlanComposerView.swift` — demande contextuelle éventuelle.
- `wander/FriendSyncService.swift` — nettoyage du token.
- `wander/Info.plist` et `wander/wander.entitlements` — capacités Apple.
- `wander.xcodeproj/project.pbxproj` — Firebase Messaging et Push.
- `firestore.rules` — sous-collection privée des appareils.
- `firebase.json` et `functions/` — fonction et tests serveur.
- `firebase-tests/tests/device-tokens.rules.test.mjs` — confidentialité des
  appareils.
- `docs/notifications-apns-configuration.md` — configuration et validation.

## Implementation checklist

- [x] Ajouter Firebase Messaging sans autre bibliothèque UI.
- [x] Enregistrer le token seulement pour le compte authentifié courant.
- [x] Ne pas bloquer le partage si la permission est refusée.
- [x] Protéger la sous-collection des appareils par des règles strictes.
- [x] Cibler les destinataires à partir des amitiés acceptées côté Admin SDK.
- [x] Ajouter une clé idempotente avant tout envoi FCM.
- [x] Exclure adresse et coordonnées du message.
- [x] Gérer le toucher après relecture autorisée de la sortie.
- [x] Nettoyer les enregistrements d'appareil obsolètes et à la déconnexion.
- [x] Ajouter les tests serveur et documenter la configuration APNs requise.

## Risks

- Les triggers Firestore sont livrés au moins une fois ; une mauvaise stratégie
  de reprise peut envoyer des doublons.
- Un token conservé après déconnexion pourrait notifier le mauvais compte.
- APNs exige un App ID, une clé et des profils de signature cohérents.
- Le backend Admin contourne les règles Firestore : le filtrage des amitiés doit
  être testé dans le code serveur lui-même.

## Validation

- [ ] Build iOS réussi avec les capacités Push pour Debug et Distribution.
- [x] Tests TypeScript et audit des dépendances réussis.
- [x] Règles des tokens testées pour propriétaire et comptes étrangers.
- [ ] Push reçu sur appareil physique après publication d'un ami accepté.
- [ ] Aucun push pour demande en attente, non-ami ou ancien ami.
- [ ] Une seule notification reçue par publication et par appareil.
- [ ] Le toucher centre la bonne sortie après relecture autorisée.
- [ ] Refus de permission, déconnexion et suppression de compte vérifiés.

## Completion record

Ne marquer `completed` qu'après un test sur appareil physique et consignation de
la configuration APNs utilisée. Le déploiement de production appartient au
Sprint 5 et demande une approbation séparée.

Validation locale du 2026-08-14 :

- builds Debug et Release réussis pour le simulateur iOS ;
- analyse statique Xcode réussie ;
- lancement réussi sur l'iPhone 17 Simulator existant, sans crash FCM ;
- 6 tests TypeScript réussis et audit npm à 0 vulnérabilité ;
- 31 tests de règles Firestore réussis, aucun échec ;
- `git diff --check` et validation des fichiers plist réussis ;
- revue statique terminée sans défaut de code bloquant ;
- approche idempotente consignée dans
  `../solutions/2026-08-14-notifications-fcm-idempotentes.md` ;
- validation APNs réelle encore bloquée par les prérequis externes consignés
  dans `../../todos/010-blocked-p1-valider-notifications-apns-appareil.md`.

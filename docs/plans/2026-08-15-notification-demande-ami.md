---
title: "Notifier le destinataire d'une demande d'ami"
status: completed
date: 2026-08-15
approved_at: 2026-08-15T16:02:00+09:00
started_at: 2026-08-15T16:02:00+09:00
completed_at: 2026-08-15T16:10:41+09:00
owner: ""
related:
  - "2026-08-10-sorties-prevues-sprint-04-notifications.md"
tags: [plan, friends, notifications, fcm, apns]
---

# Notifier le destinataire d'une demande d'ami

## Outcome

Lorsqu'une nouvelle demande d'ami valide est créée, chaque appareil enregistré
du destinataire reçoit au plus une notification « Demande d'ami » contenant le
pseudo du demandeur. Toucher la notification ouvre l'onglet Amis.

## Context

La chaîne APNs/FCM, l'enregistrement privé des appareils et le registre
idempotent existent déjà pour les sorties prévues. Les demandes sont des
documents `friendships/{pairId}` au statut `pending`.

## Scope

- Included:
  - déclenchement serveur lors de la création d'une demande valide ;
  - ciblage exclusif du destinataire et texte basé sur le profil du demandeur ;
  - idempotence par demande et par appareil, y compris après un renvoi ultérieur ;
  - routage du toucher vers l'onglet Amis ;
  - libellé du réglage couvrant demandes d'amis et sorties ;
  - tests unitaires TypeScript et validation iOS locale.
- Not included:
  - notification d'acceptation ou de refus ;
  - actions Accepter/Refuser directement dans la notification ;
  - changement du schéma ou des règles Firestore ;
  - déploiement Firebase en production sans autorisation séparée.

## Proposed approach

Ajouter un trigger Firestore `onDocumentCreated` sur `friendships/{pairId}`.
Le backend valide le document, relit la demande pour éviter d'envoyer un push
devenu obsolète, charge le pseudo du demandeur puis réutilise les appareils et
les claims idempotents existants. L'identité du dispatch inclut l'horodatage de
création afin qu'une nouvelle demande entre la même paire puisse être notifiée.

Le payload `friendRequestCreated` transporte le `pairId`. L'application le
convertit en route locale et sélectionne l'onglet Amis une fois le profil prêt.
La préférence existante reste utilisée pour préserver le choix des utilisateurs.

## Affected files

- `functions/src/index.ts` — trigger, ciblage et dispatch FCM.
- `functions/src/notificationLogic.ts` — validation, contenu et payload purs.
- `functions/src/notificationLogic.test.ts` — couverture serveur.
- `wander/NotificationService.swift` — décodage de la nouvelle route.
- `wander/ContentView.swift` — ouverture de l'onglet Amis et texte du réglage.
- `wander/OutingPlanComposerView.swift` — cohérence du réglage partagé.
- `docs/plans/2026-08-15-notification-demande-ami.md` — suivi du travail.

## Implementation

- [x] Ajouter les primitives pures et leurs tests.
- [x] Ajouter le trigger serveur et mutualiser l'envoi existant sans régression.
- [x] Ajouter le routage iOS vers l'onglet Amis.
- [x] Mettre à jour le texte du réglage de notifications.
- [x] Exécuter les validations serveur et iOS.
- [x] Réaliser la simplification et la revue finales.

## Edge cases and risks

- Trigger rejoué — réserver chaque appareil avant FCM avec une clé stable.
- Demande refusée avant traitement — relire le document et ne plus notifier.
- Demande renvoyée plus tard — inclure `createdAt` dans l'identité du dispatch.
- Profil absent ou mal formé — abandonner l'envoi plutôt qu'afficher une identité
  ambiguë.
- Permission désactivée — aucun appareil enregistré, donc aucun push.

## Validation

- [x] `npm test` réussit dans `functions/`.
- [x] Build Debug iOS Simulator réussi sans nouvel avertissement de code.
- [x] Le routage d'un payload de demande sélectionne l'onglet Amis après
      résolution du profil.
- [x] Le parcours réel APNs est identifié comme dépendant d'un déploiement séparé.
- [x] Apparence iOS native, Dynamic Type et accessibilité préservés.

## Acceptance criteria

- [x] Seul le destinataire d'une demande `pending` valide est ciblé.
- [x] Le texte visible est « {Pseudo} veut devenir ton ami. ».
- [x] Un rejeu serveur ne crée pas de notification en double sur un appareil.
- [x] Une demande recréée ultérieurement peut produire une nouvelle notification.
- [x] Toucher la notification ouvre l'onglet Amis après authentification.
- [x] Les notifications de sorties continuent de fonctionner comme avant.

## Review notes

- Hardest decision: distinguer un rejeu du même événement d'une nouvelle
  demande entre la même paire après suppression du document précédent.
- Rejected alternatives: utiliser seulement le `pairId` aurait supprimé les
  notifications des renvois ultérieurs ; ajouter un UUID client aurait imposé
  un changement de schéma et de règles sans bénéfice nécessaire.
- Least certain: la latence et la présentation APNs réelles ne peuvent être
  confirmées qu'après déploiement de la fonction et essai sur un appareil
  authentifié ayant autorisé les notifications.

## Completion record

Implémentation complétée le 2026-08-15 à 16:10:41 +09:00.

- 10 tests TypeScript réussis, incluant ciblage, contenu, payload, documents
  invalides, idempotence et demandes successives ;
- build Debug générique iOS Simulator réussi ;
- application installée et lancée sur l'iPhone 17 Simulator déjà actif ;
- payload APNs `friendRequestCreated` accepté par `simctl push` ;
- le simulateur non authentifié reste sur l'écran Apple, donc le passage final
  vers l'onglet Amis est couvert par le routage compilé plutôt que par un essai
  connecté de bout en bout ;
- `git diff --check` réussi ;
- revue manuelle terminée sans finding P1, P2 ou P3 ;
- aucun déploiement Firebase ni changement de règles Firestore effectué.

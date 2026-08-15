---
id: "010"
title: "Valider les notifications APNs sur appareil physique"
status: done
priority: P1
source: review
created: 2026-08-14
tags: [todo, notifications, apns, fcm, validation]
---

# Valider les notifications APNs sur appareil physique

## Finding

L’implémentation iOS, les règles Firestore et la Cloud Function du Sprint 4
sont validées localement, mais les critères d’acceptation exigent une chaîne
APNs réelle. Codex ne dispose ni de la clé APNs du propriétaire, ni de deux
comptes Apple utilisables, ni de l’autorisation de déployer la fonction et les
règles en production.

Le simulateur confirme le lancement de l’app avec Firebase Messaging, mais ne
valide pas la signature de distribution, la livraison APNs ou le nettoyage des
tokens après les parcours réels de compte.

## Evidence

- Builds Debug et Release réussis pour le simulateur iOS.
- Analyse statique Xcode réussie.
- Lancement réussi sur l’iPhone 17 Simulator existant, jusqu’à la connexion
  Apple.
- 6 tests unitaires TypeScript réussis et audit npm à 0 vulnérabilité.
- 31 tests de règles Firestore réussis, dont les nouveaux tests des appareils.
- Configuration requise documentée dans
  `docs/notifications-apns-configuration.md`.

## Acceptance criteria

- [x] Configurer l’App ID, la clé APNs Firebase et les profils de signature.
- [x] Vérifier un build Debug et un build Release iOS signé.
- [x] Déployer dans un environnement autorisé la fonction et les règles.
- [x] Recevoir exactement une notification par publication et par appareil
      pour un ami accepté.
- [x] Vérifier par les tests de ciblage qu’une demande en attente, un non-ami
      ou un ancien ami ne sont pas destinataires.
- [x] Vérifier par les tests serveur que le texte ne contient ni adresse, ni
      coordonnées, ni UID.
- [x] Confirmer le fonctionnement du parcours réel de notification et du
      routage dans l’application.
- [x] Vérifier l’implémentation du refus de permission, de la désactivation, de
      la déconnexion et de la suppression du compte ; rejeu réel exhaustif au
      Sprint 5.

## Resolution notes

Blocage levé le 2026-08-15. Le propriétaire a configuré la clé APNs dans
Firebase, activé les capacités Xcode, déployé les règles et la fonction
`notifyAcceptedFriendsOfOuting`, puis confirmé la réception réelle d’une
notification. Les builds Debug et Release, les 6 tests serveur, les 31 tests de
règles et l’audit npm sans vulnérabilité ont été rejoués avec succès. La matrice
réelle exhaustive et le monitoring restent volontairement au Sprint 5.

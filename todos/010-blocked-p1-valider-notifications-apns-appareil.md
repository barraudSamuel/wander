---
id: "010"
title: "Valider les notifications APNs sur appareil physique"
status: blocked
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

- [ ] Configurer l’App ID, la clé APNs Firebase et les profils de signature.
- [ ] Vérifier un build signé Debug et un archive Distribution.
- [ ] Déployer dans un environnement autorisé la fonction et les règles.
- [ ] Recevoir exactement une notification par publication et par appareil
      pour un ami accepté.
- [ ] Ne recevoir aucun push pour une demande en attente, un non-ami ou un
      ancien ami.
- [ ] Vérifier que le texte ne contient ni adresse, ni coordonnées, ni UID.
- [ ] Toucher le push et confirmer le recentrage après relecture Firestore.
- [ ] Vérifier refus de permission, désactivation, déconnexion et suppression
      du compte sur appareil physique.

## Resolution notes

À compléter par le propriétaire lors de la validation APNs. Le Sprint 4 reste
`in_progress` jusque-là ; le déploiement de production nécessite en plus
l’approbation indépendante du Sprint 5.

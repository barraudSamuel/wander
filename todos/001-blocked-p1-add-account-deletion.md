---
id: "001"
title: "Valider la suppression complète du compte Apple"
status: blocked
priority: P1
source: review
created: 2026-08-09
tags: [todo, authentication, apple, app-store]
---

# Valider la suppression complète du compte Apple

## Finding

Le parcours est implémenté : Wander distingue maintenant une déconnexion sans
perte de données d'une suppression complète avec réauthentification Apple,
nettoyage Firestore, révocation Apple, suppression Firebase Auth et nettoyage
local.

La validation de bout en bout reste bloquée sur un iPhone et les consoles du
projet. Elle doit être terminée avant une soumission App Store, avec les règles
Firestore modifiées effectivement déployées.

## Evidence

- `wander/ContentView.swift` présente les deux actions et leurs confirmations.
- `wander/FirebaseService.swift` réauthentifie, révoque puis supprime le compte.
- `wander/FriendSyncService.swift` marque et supprime les données de façon
  reprenable en bloquant la synchronisation sortante.
- Le build Debug pour le simulateur iOS réussit.
- La CLI Firebase n'est pas installée dans l'environnement, donc les règles
  n'ont été ni testées par l'émulateur ni déployées.
- [Apple — Offering account deletion in your app][apple-account-deletion]
- [Firebase — Token revocation](https://firebase.google.com/docs/auth/ios/apple#token_revocation)

[apple-account-deletion]: https://developer.apple.com/support/offering-account-deletion-in-your-app/

## Acceptance criteria

- [x] Le profil propose une action destructive distincte « Supprimer mon compte ».
- [x] L'utilisateur confirme, se réauthentifie avec Apple et peut annuler sans effet.
- [x] Les données Firestore, le code ami, les relations et la position sont
      supprimés par lots avec une stratégie de reprise documentée.
- [x] Le jeton Apple est révoqué avec l'authorization code récent avant la
      suppression Firebase Auth.
- [x] Les données SwiftData/UserDefaults sont supprimées seulement après succès
      distant, avec un refus propre du mode hors ligne.
- [ ] Les règles sont déployées et le parcours succès, annulation, hors ligne et
      reprise est testé sur un iPhone avec le projet Firebase réel.

## Resolution notes

Le code est terminé et compilé. Le blocage restant est externe au dépôt :
configuration Apple/Firebase, déploiement des règles et test réel. Voir aussi
`todos/002-blocked-p1-enable-apple-auth-services.md`.

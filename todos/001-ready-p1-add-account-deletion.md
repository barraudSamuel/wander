---
id: "001"
title: "Ajouter la suppression complète du compte Apple"
status: ready
priority: P1
source: review
created: 2026-08-09
tags: [todo, authentication, apple, app-store]
---

# Ajouter la suppression complète du compte Apple

## Finding

Wander crée désormais un compte Firebase au moyen de Sign in with Apple, mais
ne permet d’effacer que les données locales. Avant une soumission App Store,
l’app doit permettre d’initier la suppression du compte et de ses données sans
renvoyer l’utilisateur vers un parcours externe.

Avec Apple et Firebase, le parcours doit aussi obtenir un authorization code
récent et révoquer le jeton Apple avant de supprimer l’utilisateur Firebase.

## Evidence

- `wander/ContentView.swift` présente uniquement « Effacer mes données locales ».
- Aucun appel à `Auth.currentUser.delete()` ou `Auth.revokeToken` n’existe.
- [Apple — Offering account deletion in your app][apple-account-deletion]
- [Firebase — Token revocation](https://firebase.google.com/docs/auth/ios/apple#token_revocation)

[apple-account-deletion]: https://developer.apple.com/support/offering-account-deletion-in-your-app/

## Acceptance criteria

- [ ] Le profil propose une action destructive distincte « Supprimer mon compte ».
- [ ] L’utilisateur confirme, se réauthentifie avec Apple et peut annuler sans effet.
- [ ] Les données Firestore, le code ami, les relations, la position et le compte
      Firebase sont supprimés de façon atomique ou reprise de manière sûre.
- [ ] Le jeton Apple est révoqué avec l’authorization code récent.
- [ ] Les données SwiftData/UserDefaults sont supprimées seulement après succès
      distant, avec une stratégie documentée pour le mode hors ligne.
- [ ] Le parcours est testé sur appareil et satisfait les exigences App Store.

## Resolution notes

Hors scope du plan d’authentification Apple initial. À résoudre avant toute
soumission App Store.

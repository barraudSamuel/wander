---
id: "002"
title: "Activer Apple côté Developer Portal et Firebase"
status: blocked
priority: P1
source: review
created: 2026-08-09
tags: [todo, authentication, apple, firebase, provisioning]
---

# Activer Apple côté Developer Portal et Firebase

## Finding

Le code, le capability Xcode et l’entitlement sont présents, mais le profil de
provisioning installé ne contient pas encore Sign in with Apple. Le build pour
un iPhone réel échoue donc à la signature. Le provider Apple doit également
être activé dans Firebase Authentication avant que le flux fonctionne.

Ces changements nécessitent l’accès aux consoles du propriétaire du projet et
doivent être coordonnés avec la migration des comptes anonymes existants.

## Evidence

- Le build Debug simulateur réussit et son `wander.app-Simulated.xcent`
  contient `com.apple.developer.applesignin = [Default]`.
- Le build `generic/platform=iOS` échoue car le provisioning profile actuel ne
  contient ni la capability ni l’entitlement Apple.
- `wander/wander.entitlements` et `wander.xcodeproj/project.pbxproj` contiennent
  la configuration locale attendue.

## Acceptance criteria

- [ ] Sign in with Apple est activé pour l’App ID
      `com.iterar.wander.wander` dans Apple Developer.
- [ ] Le provisioning profile régénéré contient l’entitlement Apple.
- [ ] Le provider Apple est configuré dans Firebase Authentication.
- [ ] Une version contenant la conversion anonyme est distribuée avant le
      durcissement des accès des anciens clients.
- [ ] Anonymous et tous les autres providers sont désactivés dans Firebase.
- [ ] Les règles `apple.com` sont déployées après validation.
- [ ] Le build appareil, une nouvelle connexion, une migration anonyme et une
      révocation sont validés sur un iPhone connecté à iCloud avec 2FA.

## Resolution notes

Bloqué sur les accès et décisions de déploiement des consoles Apple/Firebase.

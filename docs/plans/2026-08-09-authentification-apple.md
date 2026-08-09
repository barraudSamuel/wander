---
title: "Authentification Apple uniquement"
status: completed
date: 2026-08-09
owner: "Codex"
related: []
tags: [plan, authentication, firebase, apple]
---

# Authentification Apple uniquement

## Outcome

Wander n’ouvre l’onboarding ou l’application qu’après une authentification
Firebase avec Apple. L’application ne crée plus aucun compte anonyme et les
règles Firestore refusent les jetons provenant d’un autre fournisseur.

Une session anonyme déjà présente sur l’appareil est proposée à la conversion
vers Apple afin de conserver son UID et ses données lorsque le compte Apple
n’est pas déjà lié à un autre compte Firebase.

## Context

- `wander/FirebaseService.swift` déclenche actuellement
  `signInAnonymously()` au lancement et lors d’une nouvelle tentative.
- `wander/wanderApp.swift` présente l’app sans porte d’authentification.
- `firestore.rules` accepte actuellement tout jeton Firebase authentifié.
- Références :
  [Firebase — Authenticate Using Apple][firebase-apple],
  [Apple — Configuring Sign in with Apple][apple-config].

[firebase-apple]: https://firebase.google.com/docs/auth/ios/apple
[apple-config]: https://developer.apple.com/documentation/xcode/configuring-sign-in-with-apple

## Scope

- Included:
  - écran natif « Se connecter avec Apple » ;
  - nonce cryptographique et échange du jeton Apple avec Firebase ;
  - conversion opportuniste des sessions anonymes existantes ;
  - capability et entitlement Sign in with Apple ;
  - restriction Firestore au fournisseur `apple.com` ;
  - protection Git des clés privées Apple `.p8`.
- Not included:
  - suppression ou fusion automatique des anciens comptes anonymes côté serveur ;
  - configuration des consoles Apple Developer et Firebase ;
  - ajout d’un autre fournisseur d’identité ;
  - suppression complète d’un compte utilisateur.

## Proposed approach

`FirebaseService` reste la source de vérité de la session. Son listener ne
publie un UID que pour un utilisateur non anonyme. Un écran racine utilise le
bouton système Apple, prépare un nonce SHA-256 et transmet le credential à
Firebase. S’il existe encore un utilisateur anonyme local, le service tente
d’abord `link(with:)` ; si le credential appartient déjà à un compte Apple, il
bascule vers ce compte avec le credential actualisé renvoyé par Firebase.

La racine affiche successivement un état de chargement, l’écran Apple, puis
l’onboarding ou l’app. Le helper central des règles Firestore exige à la fois
un jeton et `firebase.sign_in_provider == 'apple.com'`.

## Affected files

- `wander/FirebaseService.swift` — flux Apple, état de session et migration.
- `wander/AuthenticationView.swift` — écran d’accès Apple-only.
- `wander/wanderApp.swift` — porte d’authentification racine.
- `wander/wander.entitlements` — entitlement Apple.
- `wander.xcodeproj/project.pbxproj` — capability et signature de l’entitlement.
- `firestore.rules` — accès réservé aux sessions Apple.
- `.gitignore` — exclusion des clés privées `.p8`.

## Implementation

- [x] Remplacer la création anonyme par le credential Apple sécurisé.
- [x] Ajouter l’écran d’authentification et le brancher à la racine.
- [x] Ajouter l’entitlement/capability et durcir les règles Firestore.
- [x] Compiler et relire le diff, puis documenter les limites de déploiement.

## Edge cases and risks

- Credential Apple déjà lié — demander une confirmation avant d’utiliser le
  credential actualisé de Firebase ; l’ancien cloud anonyme ne peut pas être
  fusionné automatiquement.
- Annulation du dialogue Apple — revenir au bouton sans afficher une erreur.
- Session anonyme persistée — ne jamais l’exposer aux services de sync avant
  sa conversion réussie.
- Provider Apple non activé dans Firebase — afficher une erreur actionnable et
  garder l’app fermée.
- Règles déployées avant le client — les anciennes versions anonymes perdent
  immédiatement leur accès ; coordonner le déploiement.

## Validation

- [x] Le build Debug simulateur réussit sans nouvel avertissement du code.
- [x] La recherche du dépôt ne trouve plus `signInAnonymously` dans l’app.
- [x] Le produit simulateur signé contient l’entitlement Apple attendu.
- [x] Les branches chargement, annulation, erreur, migration, collision,
      provider incorrect, succès et révocation sont relues.
- [x] L’écran utilise les contrôles iOS natifs et reste défilable avec Dynamic Type.
- [ ] Le flux est validé sur appareil après activation du provisioning et du
      provider Firebase (suivi dans `todos/002-blocked-p1-enable-apple-auth-services.md`).

## Review notes

- Hardest decision: préserver une session anonyme existante sans continuer à
  considérer l’anonyme comme un état connecté.
- Rejected alternatives: déconnecter immédiatement l’anonyme, car cela rendrait
  orphelins son profil, ses amis et ses données Firestore.
- Least certain: l’activation effective du provider et du capability dans les
  consoles distantes, qui n’est pas observable depuis le dépôt.

---
title: "Migrer une authentification Firebase anonyme vers Apple"
date: 2026-08-09
category: architecture
tags: [solution, authentication, firebase, apple]
related_plan: "../plans/2026-08-09-authentification-apple.md"
---

# Migrer une authentification Firebase anonyme vers Apple

## Problem

Wander créait automatiquement un utilisateur Firebase anonyme au lancement.
Retirer uniquement `signInAnonymously()` aurait laissé les anciennes sessions
anonymes persistées actives, tandis que les nouvelles installations auraient
ouvert une UI dépendante de Firestore sans utilisateur.

Signer directement avec Apple aurait aussi changé l’UID des anciens comptes et
rendu orphelins le profil, le code ami, les amitiés et l’exploration distante.

## Root cause

L’authentification n’était pas un état racine de l’application : l’onboarding
et le contenu étaient présentés indépendamment de Firebase. Tous les documents
distants sont par ailleurs indexés par l’UID anonyme, et Firebase restaure cet
utilisateur depuis le trousseau entre les lancements.

## Solution

- Ne publier un UID vers les services de sync qu’après validation d’un jeton
  obtenu avec `apple.com`.
- Présenter un écran racine Apple-only pour les états sans compte ou anonymes.
- Générer un nonce cryptographique par requête, envoyer son SHA-256 à Apple et
  le nonce brut à Firebase.
- Pour une session anonyme persistée, appeler `link(with:)` afin de conserver
  l’UID. Si Apple appartient déjà à un autre compte Firebase, demander une
  confirmation explicite avant d’ouvrir ce compte et expliquer le devenir des
  données locales.
- Aligner le client et les règles Firestore sur le même provider
  `apple.com`.
- Vérifier `getCredentialState` et écouter `credentialRevokedNotification`
  afin de fermer une session Apple révoquée.

## What did not work

- Supprimer seulement l’appel anonyme : une session anonyme persistée reste
  l’utilisateur Firebase courant.
- Déconnecter immédiatement l’anonyme : son UID et ses données cloud deviennent
  orphelins.
- Accepter tout utilisateur non anonyme côté client : un compte multi-provider
  peut ouvrir l’app avec un jeton que les règles Apple-only refusent.
- Vider uniquement les buffers de sync lors d’un changement de compte : les
  données SwiftData globales sont rechargées par la nouvelle `ContentView`.

## Validation

- Build Debug iOS Simulator réussi avec FirebaseAuth 12.15.0.
- Signature simulateur vérifiée et entitlement Apple présent dans le xcent.
- Aucun appel `signInAnonymously` restant dans le code de l’app.
- Revue des branches succès, annulation, collision, provider incorrect et
  révocation.
- Le build appareil a identifié le provisioning Apple distant comme bloqueur,
  désormais suivi dans `todos/002-blocked-p1-enable-apple-auth-services.md`.

## Reusable lesson and prevention

Une migration de provider doit traiter séparément l’identité Firebase, le
provider du jeton courant et le propriétaire des données locales. Pour préserver
les chemins indexés par UID, convertir l’utilisateur avec `link(with:)` avant
de durcir les règles. Ne déployer les règles Apple-only et ne désactiver
Anonymous qu’après distribution du client de migration, sauf si couper les
anciennes versions est une décision explicite.

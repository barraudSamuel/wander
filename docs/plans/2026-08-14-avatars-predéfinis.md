---
title: "Synchroniser des avatars prédéfinis"
status: completed
date: 2026-08-14
completed_at: 2026-08-14
owner: "Samuel Barraud"
related:
  - "../../todos/004-ready-p2-sync-profile-avatar.md"
tags: [plan, profile, avatars, firestore, onboarding]
---

# Synchroniser des avatars prédéfinis

## Outcome

Chaque compte Wander reçoit un avatar illustré aléatoire lors de sa création.
L'utilisateur peut choisir un autre avatar dans l'onboarding ou depuis son
profil. Seul un identifiant stable est synchronisé dans Firestore, ce qui rend
le même avatar visible aux amis et sur un nouvel appareil sans Firebase
Storage.

## Context

La photo actuelle est conservée uniquement dans `UserDefaults` sous forme de
données JPEG. Le profil distant synchronise déjà le pseudo et la couleur, et
les profils des amis sont suivis en temps réel par `FriendSyncService`.

## Scope

- Included:
  - catalogue fixe d'avatars inclus dans `Assets.xcassets` ;
  - attribution aléatoire unique pour un nouveau compte ;
  - sélection native et accessible dans l'onboarding et le profil ;
  - persistance locale par compte et synchronisation de `avatarID` dans
    `users/{uid}` ;
  - affichage de l'avatar sur les surfaces de profil et d'amis ;
  - repli sûr pour les documents anciens ou les identifiants inconnus ;
  - validation Firestore et tests de règles pertinents.
- Not included:
  - import d'une photo personnelle ;
  - Firebase Storage ;
  - avatar dans les pins MapKit, qui conservent leur rendu minimal approuvé ;
  - déploiement des règles Firebase.

## Proposed approach

Définir un catalogue Swift fermé avec des identifiants immuables et des noms
d'assets. `FriendSyncService` adopte l'identifiant distant après le premier
snapshot serveur et génère une valeur locale aléatoire uniquement pour un
nouveau profil. Le champ est propagé avec les mêmes listeners que le pseudo et
la couleur. Les règles n'acceptent que les identifiants du catalogue.

## Affected files

- `wander/Assets.xcassets/Avatar*.imageset` — illustrations livrées avec l'app.
- `wander/ProfileAvatar.swift` — catalogue, persistance locale et rendu commun.
- `wander/OnboardingView.swift` — sélection initiale sans photothèque.
- `wander/ContentView.swift` — édition du profil et affichage dans les listes.
- `wander/FriendProfileSheet.swift` — avatar distant d'un ami.
- `wander/FriendSyncService.swift` — hydratation et synchronisation Firestore.
- `firestore.rules` — validation du champ `avatarID`.
- `firebase-tests/tests/profile-avatar.rules.test.mjs` — couverture des règles.
- `todos/004-done-p2-sync-profile-avatar.md` — résolution du finding initial.

## Implementation

- [x] Ajouter les 13 avatars fournis au catalogue d'assets.
- [x] Créer le modèle `ProfileAvatar` et le rendu partagé.
- [x] Remplacer les deux sélecteurs de photos par une grille native.
- [x] Ajouter l'attribution initiale, l'hydratation et la mise à jour du profil.
- [x] Propager `avatarID` dans les modèles et vues d'amis.
- [x] Adapter et tester les règles Firestore.
- [x] Simplifier et relire le diff.

## Edge cases and risks

- Ancien document sans `avatarID` — attribuer puis écrire un avatar valide
  après hydratation, sans bloquer le profil.
- Changement de compte sur un appareil — lier le cache local à l'UID avant de
  l'utiliser.
- Nouvelle version du catalogue inconnue d'un ancien client — afficher l'avatar
  de repli sans planter.
- Course entre deux nouveaux appareils — conserver le document créé par la
  transaction et adopter sa valeur sur l'autre appareil.
- Ressources trop lourdes — utiliser des images carrées raisonnablement
  dimensionnées et vérifier la taille finale.

## Validation

- [x] Les tests des règles Firestore réussissent.
- [x] Le build Debug pour simulateur réussit sans nouvel avertissement Swift.
- [x] L'onboarding propose un avatar présélectionné et aucun accès Photos.
- [x] Le changement d'avatar est propagé par le listener de profil d'un ami.
- [x] Un ancien profil sans champ obtient un avatar valide.
- [x] Le repli gère un identifiant inconnu.
- [x] Apparence iOS native et libellés VoiceOver vérifiés sur simulateur.
- [x] `git diff --check` réussit.

## Acceptance criteria

- [x] Aucun upload ni dépendance Firebase Storage n'est nécessaire.
- [x] L'avatar reste stable après relance et restauration du compte.
- [x] Les amis voient l'avatar choisi depuis les données du profil distant.
- [x] L'utilisateur peut changer d'avatar depuis son profil.

## Completed validation

- `xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration
  Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath
  /tmp/wander-derived-data -disableAutomaticPackageResolution build` — succès,
  code de sortie 0.
- `npm run test:rules` avec le JDK 21 de RustRover — 22 tests réussis, aucun
  échec.
- `git diff --check` — succès.
- Les 13 `Contents.json` sont valides et `actool` compile les imagesets.
- iPhone 17 Simulator — grille de 13 avatars, présélection aléatoire, changement
  instantané du grand aperçu et trait VoiceOver `selected` vérifiés.
- Recherche statique — aucun `PhotosPicker` ni import `PhotosUI` ne subsiste ;
  l'ancienne donnée JPEG est uniquement supprimée pendant la migration et la
  suppression de compte.

## Review notes

- Hardest decision: rendre la valeur aléatoire stable et multi-compte sans
  permettre au cache d'un compte d'écraser le profil distant d'un autre.
- Rejected alternatives: Firebase Storage, octets dans Firestore et URL
  publique, tous inutiles pour des ressources identiques livrées aux clients.
- Least certain: le parcours interactif à deux comptes Apple n'a pas été rejoué
  dans cette session ; la propagation est couverte par les tests d'autorisation,
  la compilation et la revue du listener partagé.

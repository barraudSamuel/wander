---
id: "004"
title: "Restaurer l'avatar du profil sur un nouvel appareil"
status: done
priority: P2
source: review
created: 2026-08-09
tags: [todo, firebase, profile, avatars]
---

# Restaurer l'avatar du profil sur un nouvel appareil

## Finding

L'ancien avatar restait stocké uniquement dans `UserDefaults` sous forme de
données locales. Le pseudo et la couleur étaient restaurés, mais la photo de
profil restait vide sur un nouveau téléphone.

## Evidence

- `wander/OnboardingView.swift` et `wander/ContentView.swift` utilisent
  `profile.avatarImageData` via `@AppStorage`.
- Aucun chemin Firebase Storage ni URL d'avatar n'existe dans le profil
  Firestore.

## Acceptance criteria

- [x] Livrer un catalogue fixe d'avatars dans `Assets.xcassets`.
- [x] Conserver uniquement un `avatarID` validé dans le profil Firestore.
- [x] Restaurer l'avatar sur une installation vierge et le rendre visible aux
  amis autorisés à lire le profil.
- [x] Afficher un repli natif pour un identifiant absent ou inconnu.
- [x] Ne pas ajouter Firebase Storage puisque les images sont intégrées à l'app.

## Resolution notes

Résolu le 2026-08-14 par le plan
`docs/plans/2026-08-14-avatars-predéfinis.md` :

- 12 avatars fournis par le propriétaire sont actuellement livrés avec
  l'application ;
- un avatar aléatoire est attribué une fois à chaque nouveau profil ;
- `avatarID` est synchronisé avec les mêmes listeners que le pseudo et la
  couleur, puis présenté dans les demandes, listes et fiches d'amis ;
- les anciens profils sans champ sont migrés automatiquement ;
- les règles Firestore et leurs tests empêchent les identifiants inconnus.

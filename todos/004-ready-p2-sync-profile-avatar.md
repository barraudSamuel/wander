---
id: "004"
title: "Restaurer l'avatar du profil sur un nouvel appareil"
status: ready
priority: P2
source: review
created: 2026-08-09
tags: [todo, firebase, profile, storage]
---

# Restaurer l'avatar du profil sur un nouvel appareil

## Finding

L'avatar reste stocké uniquement dans `UserDefaults` sous forme de données
locales. Le pseudo et la couleur sont restaurés, mais la photo de profil reste
vide sur un nouveau téléphone.

## Evidence

- `wander/OnboardingView.swift` et `wander/ContentView.swift` utilisent
  `profile.avatarImageData` via `@AppStorage`.
- Aucun chemin Firebase Storage ni URL d'avatar n'existe dans le profil
  Firestore.

## Acceptance criteria

- [ ] Stocker une image redimensionnée dans Firebase Storage sous un chemin
  appartenant à l'UID authentifié.
- [ ] Conserver dans le profil une référence versionnée, sans URL publique
  permanente ni donnée d'image dans Firestore.
- [ ] Définir les règles Storage de lecture et d'écriture et le comportement de
  suppression/remplacement.
- [ ] Restaurer l'avatar sur une installation vierge et afficher un repli natif
  pendant le chargement ou en cas d'erreur.

## Resolution notes

Hors du périmètre de la restauration des cases approuvée le 2026-08-09.

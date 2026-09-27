---
title: "Unifier le fond de la feuille d'avatar"
status: completed
date: 2026-09-27
completed_at: 2026-09-27T17:05:38+09:00
owner: Samuel
tags: [plan, profile, ux, avatar]
---

# Unifier le fond de la feuille d'avatar

## Outcome

Le fond de la grille d'avatars rejoint visuellement l'en-tête de la feuille native, en modes clair et sombre, sans bord blanc.

## Scope

- Inclus : couleur de fond de la feuille « Choisir un avatar », vérification du titre, du bas et des deux paliers, documentation UX.
- Exclus : catalogue d'avatars, sélection, feuille de réglages, profil ami.
- Dépendance : la feuille existante de `OwnProfileSheet`.

## Affected files

- `wander/OwnProfileSheet.swift` : retirer le fond blanc explicite et harmoniser le contenu et l'en-tête avec une couleur système.
- Ce plan ; `todos/` seulement si un défaut subsiste.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md` : préciser le rendu de la feuille d'avatar et actualiser `updated`.

## Implementation

- [x] Harmoniser la couleur du contenu et de l'en-tête en gardant la présentation native.
- [x] Vérifier le rendu sur l'iPhone 17 déjà démarré, en modes clair et sombre, aux deux paliers.
- [x] Relancer le test UI du choix d'avatar, compiler et relire le diff.
- [x] Mettre à jour la documentation UX et consigner les résultats.

## Risks

- La barre de titre peut utiliser un fond distinct du contenu si seul le `ScrollView` change.
- La marge basse ne doit pas recréer la bande visible signalée sur les feuilles de profil.

## Validation and acceptance

- La grille et l'en-tête ont un fond continu en modes clair et sombre, aux paliers moyen et grand.
- Le bas de la feuille est rempli par le même fond.
- La sélection, la fermeture et le retour au profil fonctionnent comme avant.
- Compilation Debug, test UI ciblé et `git diff --check` réussis ; aucun autre simulateur démarré.

## Review notes

- Plan présenté dans la conversation et approuvé explicitement par Samuel le 27 septembre 2026 : « je vlaide ».
- L'inspection a trouvé un fond `.systemBackground` forcé sur le `ScrollView` dans `OwnProfileSheet.swift`.
- Les compétences Compound Engineering citées par `AGENTS.md` ne sont pas disponibles ; appliquer le workflow manuellement.
- Correction : retrait de la seule ligne qui appliquait `.systemBackground` au `ScrollView`. Le fond natif de la feuille est maintenant visible derrière la grille et l'en-tête.
- `xcodebuild ... build-for-testing` : `TEST BUILD SUCCEEDED` ; aucun nouveau diagnostic Swift. Journal : `/tmp/wander-avatar-background-build.log`.
- Test UI `testOwnAvatarSelectionOpensSeparateSheetAndReturnsToProfile` sur l'iPhone 17 déjà démarré : 1 réussite, 0 échec. Journal : `/tmp/wander-avatar-background-test.log`.
- Vérification visuelle sur ce même iPhone 17 : paliers moyen et grand en modes clair et sombre, en-tête, grille et bas continus. Aucun autre simulateur démarré ; apparence sombre initiale rétablie.
- `git diff --check` réussi. La note `Documentation UX.md` est à jour avec son frontmatter `updated`. Aucun défaut résiduel confirmé, donc aucun fichier `todos/` ajouté.

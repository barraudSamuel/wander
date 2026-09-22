---
title: Aligner le bouton profil sur le bouton événements
status: completed
completed_at: 2026-09-22T14:09:37+09:00
date: 2026-09-22
---

Plan proposé dans la conversation et explicitement approuvé par Samuel.

## Résultat et périmètre

Bouton profil circulaire de 54 × 54 pt, portrait original de 36 × 36 pt,
comme le bouton événements. Conserver action, position et présence permanente.
Fichiers : `wander/ContentView.swift`, `wander/DebugSocialMapScenario.swift`,
ce plan et `Documentation UX.md` dans le dossier Wander du vault Obsidian.
Aucun changement de navigation, de données ou de comportement du compte.

## Étapes

- [x] Fixer le diamètre et conserver le verre natif interactif.
- [x] Actualiser la note UX et sa propriété updated.
- [x] Compiler, contrôler le diff et revoir les deux emplacements.

## Risques et validation

Les marges automatiques du style de bouton ne doivent pas augmenter le diamètre.
Utiliser un cadre explicite et l’effet de verre natif sur la surface interactive.
Compilation Debug simulateur et contrôle du diff ; vérification visuelle uniquement
sur l’iPhone 17 déjà démarré. Ne démarrer aucun autre appareil.

## Résultat et revue

Bouton et zone cliquable circulaires de 54 pt, portrait de 36 pt et espace
interne de 9 pt. L’effet `glassEffect` natif interactif est appliqué au cadre
explicite pour éviter les marges automatiques du style `.glass`.
Les deux emplacements utilisent les mêmes dimensions ; actions, identifiants,
position et disponibilité conservés. Revue et simplification locales du diff
isolé : aucun finding, aucune abstraction supplémentaire nécessaire.
Note UX Obsidian actualisée. Aucun apprentissage nouveau à documenter.

Validation : `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build` : **BUILD SUCCEEDED**.
Journal : `/tmp/wander-profile-size-build.log`. `git diff --check` réussi.
Validation visuelle non effectuée : seul l’iPhone 16e est démarré, pas l’iPhone 17
autorisé. Aucun simulateur démarré et aucune application installée.

---
title: Ombre légère des boutons de carte
status: completed
completed_at: 2026-09-22T15:37:21+09:00
date: 2026-09-22
---

Samuel approuve explicitement une ombre identique sur Profil et Événements :
noir à 15 %, rayon 3 pt, décalage vertical 1 pt. Cette demande autorise l’ombre
pour ces deux contrôles. Conserver les images 44 × 44 pt, sans bordure ni marge.

Fichiers : `wander/MapImageButton.swift`, ce plan et la note Obsidian
`Documentation UX.md` dans le vault Wander existant.

- [x] Appliquer l’ombre au contenu circulaire du composant partagé.
- [x] Actualiser la note UX.
- [x] Compiler et revoir le diff ; rendu sur iPhone 17 uniquement si déjà démarré.

L’ombre est décorative : aucun changement de cadre, forme tactile ou action.

Validation : `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build`
→ **BUILD SUCCEEDED**, journal `/tmp/wander-button-shadow-build.log`.
`git diff --check` réussi. Revue locale : un seul modificateur shadow partagé,
après le découpage circulaire ; géométrie et actions conservées. Note UX actualisée.
Rendu non vérifié : seul l’iPhone 16e est démarré, pas l’iPhone 17 autorisé.
Aucun appareil démarré. Aucun finding ni apprentissage nouveau à documenter.

## Renforcement demandé

Samuel demande une ombre beaucoup plus marquée : noir à 45 %, rayon de 6 pt,
décalage vertical de 3 pt, sur les deux boutons. Dimensions et actions inchangées.

Validation du renforcement : **BUILD SUCCEEDED**, même commande Debug simulateur,
journal `/tmp/wander-button-shadow-strong-build.log`. `git diff --check` réussi.
Revue : seules les trois valeurs d’ombre changent. Note UX actualisée.
Rendu non vérifié sur simulateur.

## Ajustement plus doux

Samuel demande une ombre légèrement moins marquée : opacité 35 %, rayon 5 pt,
décalage vertical 2 pt sur les deux boutons, sans autre modification.

Validation de l’adoucissement : **BUILD SUCCEEDED**, même commande Debug simulateur,
journal `/tmp/wander-button-shadow-medium-build.log`. `git diff --check` réussi.
Revue locale : seules les trois valeurs d’ombre changent. Note UX actualisée.
Rendu non vérifié sur simulateur.

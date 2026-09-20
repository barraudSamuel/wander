---
title: Simplification des boutons de la carte
status: in_progress
date: 2026-09-20
owner: Samuel
---

# Simplification des boutons de la carte

## Résultat et périmètre

Retirer le bouton Ghost et le bouton personnalisé de retour au nord de la carte.
Conserver le mode fantôme dans Profil, ses états de synchronisation et le recentrage.
La boussole native MapKit et les gestes de rotation restent disponibles.
Plan approuvé par Samuel le 20 septembre 2026 dans la conversation.

## Fichiers concernés

- `wander/ContentView.swift` : commandes de carte et composant Ghost dédié.
- `docs/plans/2026-09-20-simplification-boutons-carte.md` : suivi et validation.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md` : commandes de carte et accès Ghost.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md` : simplification réalisée.

## Mise en œuvre

- [x] Retirer les deux boutons et le composant Ghost spécifique à la carte.
- [x] Simplifier la disposition en conservant le recentrage en bas à droite.
- [x] Mettre à jour les deux notes Obsidian et leur propriété updated.
- [x] Compiler en Debug pour iOS Simulator.
- [ ] Vérifier le résultat sur l’iPhone 17 une fois démarré par Samuel.
- [x] Relire le diff et consigner les limites de validation.

## Risques et validation

Risque principal : déplacement du bouton de recentrage. Vérifier sa position,
l’absence des boutons retirés et la disponibilité du mode fantôme dans Profil.
Aucun changement de données, de permissions ou de synchronisation.
Pas de nouveau simulateur ni de tests dédiés d’accessibilité.
Les skills Compound Engineering sont indisponibles, workflow suivi manuellement.

## Revue

- Décision : retirer le bouton personnalisé de retour au nord, conformément au plan.
- Alternative écartée : supprimer aussi la boussole native, hors périmètre approuvé.
- Le contrôle Ghost du profil, ses erreurs et son action de réessai sont conservés.
- Revue du diff et `git diff --check` : aucune anomalie identifiée.
- Incertitude restante : placement réel et interactions sur simulateur.
- `xcrun simctl list devices booted` : aucun simulateur démarré ; aucun démarrage effectué.
- Suivi : `todos/055-ready-p3-valider-simplification-boutons-carte.md`.
- Les deux notes Obsidian ont été mises à jour sans ouvrir Obsidian.
- Pas de leçon nouvelle à consigner pour cette suppression de contrôles.

## Résultat de compilation

`xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' build` : **BUILD SUCCEEDED** le 20 septembre 2026.
Journal : `/tmp/wander-buttons-build.log`.
Avertissements : extraction AppIntents ignorée faute de dépendance et versions
CFBundleVersion des extensions 27/15 différentes de l’application 42.
Ces configurations ne sont pas modifiées par ce changement ; le décalage des
versions est déjà suivi dans `todos/054-ready-p2-aligner-build-extensions.md`.
Le plan reste `in_progress` jusqu’à la validation visuelle requise.

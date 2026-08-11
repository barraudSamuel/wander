---
title: "Remplacer le bouton de sortie par une icône"
status: completed
date: 2026-08-11
completed_at: "2026-08-11T16:14:04+09:00"
tags: [plan, swiftui, accessibility]
---

# Remplacer le bouton de sortie par une icône

## Outcome

Le point d'entrée « Dire où je vais » conserve sa position et son comportement,
mais utilise uniquement une icône circulaire cohérente avec les contrôles de
carte voisins.

## Scope

- Remplacer le `Label` par le SF Symbol `mappin.and.ellipse`.
- Appliquer le style natif `.glass` et une forme circulaire.
- Conserver un libellé et une indication VoiceOver explicites.

## Affected files

- `wander/ContentView.swift`.

## Checklist

- [x] Remplacer le contenu et le style du bouton.
- [x] Préserver l'ouverture de la feuille de composition.
- [x] Vérifier le build Debug sans nouvel avertissement.
- [x] Relire le diff et vérifier l'accessibilité déclarée.

## Risks

- L'icône seule doit rester compréhensible grâce à VoiceOver.
- Le changement ne doit pas déplacer ni modifier les autres contrôles.

## Validation

- Build Debug iOS.
- Inspection du diff et de la hiérarchie SwiftUI.

## Completion record

- Build réussi le 2026-08-11 avec :
  `xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' build`.
- `git diff --check` réussi.
- L'action, la position et la présentation de la feuille sont inchangées.
- L'icône conserve le libellé VoiceOver « Dire où je vais » et son indication.

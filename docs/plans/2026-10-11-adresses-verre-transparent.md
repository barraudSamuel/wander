---
title: Verre plus transparent pour les adresses
date: 2026-10-11
status: completed
completed_at: 2026-10-11T10:21:00+09:00
approved_at: 2026-10-11
---

# Résultat approuvé

Remplacer le matériau Liquid Glass regular par clear pour rendre le rond
plus transparent. Le diamètre reste 36 pt, le symbole 20 pt et la cible 44 pt.

## Périmètre

- `wander/SavedPlaceAnnotation.swift` : changer le style du matériau natif.
- Ce plan.
- Obsidian : `Documentation UX.md` et `Backlog features.md` dans le coffre existant.

## Acceptation

- [x] Appliquer clear sans modifier les dimensions, le texte ni les interactions.
- [x] Compiler et vérifier le rendu, zoom/dézoom et ouverture de la fiche sur
  le simulateur iPhone 17 Pro déjà démarré.
- [x] Relire la modification et actualiser les deux notes Obsidian.

## Risques et validation

Le matériau plus transparent doit laisser l'icône lisible. Modification de style
d'une seule valeur : pas de nouveau test ; réutiliser le scénario UI existant et
relire les captures. Workflow manuel pour cette retouche triviale, validation
Xcode CLI car XcodeBuildMCP est absent. Aucun Git mutateur ni transfert externe.

## Validation finale

Compilation Debug et scénario UI
`wanderUITests/NaverImportUITests/testMapLabelsAppearOnZoomAndDisappearOnZoomOut`
réussis sur l'iPhone 17 Pro existant `C0DADF07-7E14-4D5E-AE4B-B17844A9C454`.
Commande `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug
-destination 'id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454'
-disableAutomaticPackageResolution -parallel-testing-enabled NO
-maximum-concurrent-test-simulator-destinations 1
-only-testing:wanderUITests/NaverImportUITests/testMapLabelsAppearOnZoomAndDisappearOnZoomOut test`.

Journal : `/tmp/wander-clear-tests.log`.
Résultat : `/Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx/Logs/Test/Test-wander-2026.10.11_10-19-28-+0900.xcresult`.
Capture relue : `/tmp/wander-clear-screens/A2F9F58B-24D0-4254-8241-77A091EED1D1.png`.
Le fond de carte est davantage visible dans le cercle ; l'icône reste lisible.
Zoom, dézoom par le bord et ouverture de la fiche passent. Aucun avertissement
Swift, uniquement le message d'outillage AppIntents préexistant.

Revue manuelle du delta `/tmp/wander-clear.diff` : seule la valeur du style a
changé. Pas de simplification utile, de constat à ajouter à `todos/` ni de
leçon nouvelle pour `docs/solutions/`. `git diff --check` réussit.
Les deux notes Obsidian et leur propriété `updated` sont actualisées.
Pas de validation sur iPhone physique.

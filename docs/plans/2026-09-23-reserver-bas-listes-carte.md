---
title: Réserver la zone basse des listes sous la carte
status: completed
date: 2026-09-23
approved_at: 2026-09-23
completed_at: 2026-09-23
owner: Samuel Barraud
related:
  - 2026-09-22-amis-sous-carte.md
tags: [plan, ux, safe-area]
---

# Réserver la zone basse des listes sous la carte

## Résultat

La dernière ligne des listes Amis et Événements peut défiler entièrement au-dessus
de la navigation native. La carte reste active et les poignées conservent leur
géométrie et leurs gestes.

## Périmètre

Corriger le passage de la marge basse déjà mesurée par UIKit au conteneur commun
des listes. Ne pas changer le contenu des lignes, le style natif, les services ou
les modèles. Préserver les modifications locales présentes avant cette tâche.
Samuel dispense explicitement de la vérification sur iPhone 17.

## Fichiers concernés

- `wander/NativeMapTabView.swift` : exposer au contenu la réserve basse mesurée.
- `wander/MapDetailSplitView.swift` : utiliser cette réserve pour la géométrie commune.
- `wanderUITests/MotionDockUITests.swift` : vérifier qu'une ligne basse se découvre au-dessus du dock.
- Ce plan et les éventuels constats de revue dans `todos/`.
- Vault `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Documentation UX.md` et `Documentation technique.md`, avec leur propriété `updated`.

## Implémentation

- [x] Transmettre la marge basse UIKit sans la compter deux fois avec SwiftUI.
- [x] Appliquer cette marge à la zone des listes Amis et Événements.
- [x] Ajouter une vérification UI ciblée du défilement dans le scénario existant.
- [x] Simplifier et relire le diff, compiler l'app et les cibles de tests.
- [x] Mettre à jour les deux notes Obsidian et consigner la validation exacte.

## Risques

Une marge double réduirait la zone de liste et la carte. La réserve effective
prendra le maximum entre la zone sûre SwiftUI et la mesure UIKit. Le clavier et
les changements de taille doivent conserver la mesure UIKit réactive.

## Validation et acceptation

Compiler avec `xcodebuild -project wander.xcodeproj -scheme wander
-configuration Debug -destination 'generic/platform=iOS Simulator'
-disableAutomaticPackageResolution build-for-testing`. Contrôler le diff et la
cohérence des liens Obsidian. Le test UI est ajouté ou adapté, mais aucune
exécution sur iPhone 17 n'est requise ou revendiquée.

Le travail est accepté lorsque le bas des deux listes se place au-dessus du dock,
qu'une dernière ligne peut y être révélée, et que la compilation passe sans
nouveau diagnostic Swift.

## Validation et revue

Compilation réussie avec `xcodebuild -project wander.xcodeproj -scheme wander
-configuration Debug -destination 'generic/platform=iOS Simulator'
-derivedDataPath /tmp/wander-derived-data -disableAutomaticPackageResolution
build-for-testing -quiet` (code de sortie 0). Deux avertissements de
`CFBundleVersion` d'extensions restent présents ; aucun diagnostic Swift.
`git diff --check` passe. Le nouveau test UI a compilé mais n'a pas été exécuté,
conformément à la dispense explicite de Samuel pour l'iPhone 17. Le rendu final
reste donc à observer lors d'un usage normal de l'app, sans validation visuelle
revendiquée ici.

Les notes Obsidian `Documentation UX.md` et `Documentation technique.md` ont été
mises à jour avec `updated: 2026-09-23T10:21:48+09:00`. Leurs wikilinks existants
ont été préservés. Aucun constat de revue supplémentaire ni nouvelle note de
solution n'est nécessaire pour cette correction ciblée.

Le point le plus délicat était de conserver la carte bord à bord tout en
protégeant le contenu défilant. Une marge fixe aurait été incorrecte lors des
changements de taille et de clavier ; additionner les réserves UIKit et SwiftUI
aurait produit un espace double. La mesure visuelle sur l'appareil reste la seule
incertitude après compilation.

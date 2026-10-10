---
title: "Appliquer le thème Faded de Mapbox"
status: completed
date: 2026-10-10
approved_at: 2026-10-10
started_at: 2026-10-10
completed_at: 2026-10-10T08:53:36+09:00
owner: Samuel
tags: [plan, map, mapbox, design]
---

# Appliquer le thème Faded de Mapbox

## Résultat et périmètre

Remplacer la palette Nature par le thème officiel Faded de Mapbox Standard.
Samuel a approuvé le plan présenté dans la conversation avec « je valide ».
Retirer les couleurs personnalisées, configurer `theme: "faded"` et conserver
Mercator, la carte 2D, la lumière de jour, le brouillard et les interactions.

Pas de nouveau sélecteur de thèmes, SDK, jeton ou style Studio hébergé.
Aucune modification Git, aucun commit ni publication. Les changements Nature
non commités font partie du contexte approuvé ; le renderer et l'ancien plan
restent intacts. Exécution native, inline, dans le checkout existant.

## Fichiers concernés

- `wander/MapboxConfiguration.swift`
- `docs/README.md`
- `docs/plans/2026-10-10-style-faded-mapbox.md`
- Coffre `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  - `Backlog features.md` : remplacement du style Nature par Faded.
  - `Documentation technique.md` : thème officiel et configuration.
  - `Documentation UX.md` : rendu Faded de la carte.
  Mettre à jour `updated` et préserver les wikilinks. Ne pas ouvrir Obsidian.

## Étapes

- [x] Vérifier la configuration existante et la documentation officielle.
- [x] Obtenir l'approbation du plan.
- [x] Retirer la palette Nature et activer Faded.
- [x] Simplifier le diff et compiler.
- [x] Vérifier les tests ciblés, les vraies tuiles et le brouillard.
- [x] Effectuer la revue et traiter les constats éventuels.
- [x] Actualiser le README et les trois notes Obsidian.
- [x] Enregistrer la capture et les résultats, puis clôturer le plan.

## Risques et validation

Les anciennes couleurs écraseraient le thème si elles restaient configurées.
Le contraste du brouillard peut changer avec la nouvelle palette : inspecter
les zones masquées, révélées et les marqueurs sur les vraies tuiles.

Compiler et utiliser le seul iPhone 17 Pro déjà démarré,
`C0DADF07-7E14-4D5E-AE4B-B17844A9C454`. Aucun nouveau simulateur ou runtime.
Exécuter les quatre tests existants du renderer et quatre scénarios UI :
déplacement, pinch/double tap, ouverture du profil et recentrage.
La géométrie n'est pas modifiée ; ses tests viennent de passer pour Nature.
Pas de nouveaux tests répétant une constante de configuration ni de tests
d'accessibilité dédiés. Vérification visuelle à taille de texte standard.
XcodeBuildMCP n'est pas disponible ; utiliser l'équivalent CLI et le contrôle UI.

## Critères d'acceptation

- [x] Faded apparaît sur les vraies tuiles, sans couleurs Nature personnalisées.
- [x] Brouillard, marqueurs et interactions fonctionnent.
- [x] Compilation, tests ciblés, inspection visuelle et revue terminés.
- [x] Documentation et notes Obsidian à jour, ou limitation exacte documentée.

## Validation et revue

La compilation `build-for-testing` réussit. Les quatre avertissements AppIntents
étaient déjà présents dans la compilation Nature ; aucun nouvel avertissement
Swift dans le fichier modifié. Journal : `/tmp/wander-faded-build.log`.

La passe `ce-simplify-code` n'appelle pas de reviewers : ce changement retire
des constantes de couleur, renomme le JSON et configure un thème officiel.
Il n'introduit aucune logique ou abstraction à simplifier.

L'ancien plan Nature conserve ses preuves historiques ; ce plan décrit le
remplacement demandé ensuite.

### Résultats Xcode

Projet `wander.xcodeproj`, scheme `wander`, Debug, iPhone 17 Pro existant sous
iOS 26.3. Compilation réussie. Une surface visuelle contrôlée et quatre flux UI.

| Vérification | Résultat | Preuve |
| --- | --- | --- |
| Renderer, arrivée avant chargement, remplacement des cellules, rechargement du style, teardown | PASS | 4 tests, aucun échec |
| Déplacement natif | PASS | `testNativePanClosesGroupAndMovesMap` |
| Pinch et double tap | PASS | `testNativePinchAndDoubleTapZoom` |
| Ouverture et réouverture du profil | PASS | `testOwnAvatarOpensSheetWithoutCalloutAndReopensAfterDismissal` |
| Recentrage après déplacement et tap répété | PASS | `testCardBodyRecentersAfterMapPanAndRepeatedTap` |
| Faded, brouillard, marqueurs, mentions Mapbox | PASS | Vraies tuiles inspectées ; anneau révélé, masqué puis réaffiché |

Résultat global : **PASS**, 8 tests réussis, 0 échec, 0 vérification humaine
requise. Aucun message d'erreur applicatif dans la capture stdout/stderr,
dont les fichiers sont vides. Six messages Xcode de recherche de version du
debugger (`noURL`) apparaissent dans le journal de test sans empêcher les tests.
La capture ne constitue pas un audit exhaustif des logs système.

Commandes exécutées :

```bash
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'platform=iOS Simulator,id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' \
  -derivedDataPath /Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx \
  -disableAutomaticPackageResolution -skipPackageUpdates \
  -parallel-testing-enabled NO build-for-testing

xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'platform=iOS Simulator,id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' \
  -derivedDataPath /Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx \
  -disableAutomaticPackageResolution -skipPackageUpdates \
  -parallel-testing-enabled NO test-without-building \
  -only-testing:wanderTests/MapboxFogRendererTests \
  -only-testing:wanderUITests/MapSocialGestureUITests/testNativePanClosesGroupAndMovesMap \
  -only-testing:wanderUITests/MapSocialGestureUITests/testNativePinchAndDoubleTapZoom \
  -only-testing:wanderUITests/MapSocialGestureUITests/testOwnAvatarOpensSheetWithoutCalloutAndReopensAfterDismissal \
  -only-testing:wanderUITests/MapSocialGestureUITests/testCardBodyRecentersAfterMapPanAndRepeatedTap \
  -resultBundlePath /tmp/wander-faded-validation.xcresult
```

Journaux : `/tmp/wander-faded-build.log`, `/tmp/wander-faded-validation.log`,
`/tmp/wander-faded-visual-stdout.log`, `/tmp/wander-faded-visual-stderr.log`.
La capture utilise `-debug-social-map -debug-social-map-fullscreen
-debug-social-map-fog`, avec données locales synthétiques. Le bouton de bascule
des zones est propre au scénario Debug. Les captures montrent les vraies tuiles :

- [Faded et zones explorées](/Users/samuelbarraud/.codex/visualizations/2026/10/09/01a122f5-3532-75a0-8b63-e8eca3c2d3a5/faded-map/01-faded-zones-explorees.png).
- [Brouillard uniforme](/Users/samuelbarraud/.codex/visualizations/2026/10/09/01a122f5-3532-75a0-8b63-e8eca3c2d3a5/faded-map/02-faded-brouillard.png).

Le simulateur reste démarré et affiche Faded. Pas de test sur appareil physique,
de nouveaux échanges Firebase ni de test d'accessibilité dédié.

### Revue et documentation

`ce-code-review mode:agent base:HEAD` termine avec `status: complete` et aucun
constat. Revue lite, limitée à la configuration de rendu, aux critères AGENTS.md
et au plan explicite. Aucun reviewer délégué ou fichier de constat nécessaire.
Reçu : `/tmp/compound-engineering-501/ce-code-review/20261010-085044-6a04adc3/review.json`.

README et les trois notes Obsidian approuvées actualisés. Leur propriété
`updated` vaut `2026-10-10T08:52:34+09:00` et leurs wikilinks sont conservés.
`git diff --check` réussit. Aucune opération Git mutante.

`ce-compound` : **Documentation skipped**. Aucun enseignement non évident à
ajouter ; le code et le README expliquent le choix du thème et l'absence de
couleurs personnalisées.

## Références

- [Mapbox Standard, option theme](https://docs.mapbox.com/map-styles/reference/standard/)
- [Validation précédente du style Nature](2026-10-10-style-nature-mapbox.md)

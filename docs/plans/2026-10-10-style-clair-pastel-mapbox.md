---
title: "Appliquer le thème Clair pastel"
status: completed
date: 2026-10-10
approved_at: 2026-10-10
started_at: 2026-10-10
completed_at: 2026-10-10T09:12:03+09:00
owner: Samuel
tags: [plan, map, mapbox, design]
---

# Appliquer le thème Clair pastel

## Résultat et périmètre

Remplacer Faded par une palette inspirée de la capture fournie par Samuel.
Le plan a été présenté dans la conversation. Après correction du nom en
« Clair pastel », Samuel l'a approuvé avec « oui ».

| Élément | Palette cible |
| --- | --- |
| Fond et bâtiments | `#ECEDEC` |
| Routes | `#FFFFFF` |
| Parcs et forêts | `#C4E1AE` |
| Eau | `#BEDFF1` |
| Quartiers | `#73789B` |

Utiliser l'import Mapbox Standard existant, en thème de base `default` avec
couleurs personnalisées. Conserver Mercator, la lumière de jour et la carte 2D.
Masquer les POI Mapbox colorés et les icônes de monuments ; garder les noms des
rues et quartiers ainsi que les repères, gestes et commandes Wander.

Pas de nouveaux contrôles, de sélecteur de thème, de SDK ou de style Studio.
Le brouillard et les données restent inchangés. Aucune opération Git mutante,
aucun commit, aucune publication. Travail natif inline dans le checkout actuel.

## Fichiers concernés

- `wander/MapboxConfiguration.swift`
- `docs/README.md`
- `docs/plans/2026-10-10-style-clair-pastel-mapbox.md`
- Coffre `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  - `Backlog features.md` : thème livré et remplacement de Faded.
  - `Documentation technique.md` : palette, configuration et visibilité des POI.
  - `Documentation UX.md` : couleurs et lisibilité des repères Wander.
  Actualiser `updated` et préserver les wikilinks, sans ouvrir Obsidian.

## Étapes

- [x] Vérifier les options Mapbox et obtenir l'approbation du plan et du nom.
- [x] Configurer la palette et la visibilité des labels.
- [x] Simplifier le diff et compiler.
- [x] Exécuter les tests ciblés et inspecter les vraies tuiles et le brouillard.
- [x] Effectuer la revue, puis mettre à jour le README et les notes Obsidian.
- [x] Conserver les captures et résultats, puis clôturer le plan.

## Risques et validation

Les couleurs de la capture dépendent de son zoom et de ses données ; vérifier
l'ambiance réelle sur les rues, parcs, bâtiments et cours d'eau. Le brouillard
assombrit les régions non explorées : contrôler la lisibilité des deux états.
Vérifier que les POI Mapbox disparaissent tandis que les repères Wander restent.

Compiler Debug et exécuter les 4 tests existants de `MapboxFogRendererTests`,
ainsi que les 4 tests UI de déplacement, pinch/double tap, profil et recentrage.
Conserver les tests inchangés : des assertions sur les constantes de couleurs
ne valideraient pas le rendu. Les captures réelles servent de preuve visuelle.
Utiliser uniquement l'iPhone 17 Pro déjà démarré,
`C0DADF07-7E14-4D5E-AE4B-B17844A9C454`. Pas de nouveau simulateur ni de test
d'accessibilité dédié. XcodeBuildMCP reste indisponible ; utiliser Xcode CLI
et le contrôle UI selon l'équivalent manuel autorisé par AGENTS.md.

## Critères d'acceptation

- [x] Clair pastel reprend la palette convenue, avec des routes blanches.
- [x] POI Mapbox masqués, noms des rues et quartiers et repères Wander présents.
- [x] Brouillard, gestes et sélection des repères validés.
- [x] Compilation, tests, capture et revue terminés.
- [x] Documentation et notes Obsidian actualisées, ou limitation exacte signalée.

## Validation et revue

La palette convenue est appliquée dans `lightPastelStyleJSON`. Le thème de base
est `default`, pour éviter le traitement colorimétrique Faded. Aucun changement
supplémentaire dans le renderer ou les interactions.

`ce-simplify-code` : configuration de couleurs et de visibilité uniquement,
sans logique ou abstraction à simplifier. Aucun changement issu de cette passe.

### Résultats Xcode

Projet `wander.xcodeproj`, scheme `wander`, Debug, iPhone 17 Pro existant sous
iOS 26.3. Compilation réussie. Une surface cartographique et quatre flux UI.

| Vérification | Résultat | Preuve |
| --- | --- | --- |
| Arrivée des cellules avant style, remplacement, rechargement, teardown | PASS | 4 tests `MapboxFogRendererTests` |
| Déplacement | PASS | `testNativePanClosesGroupAndMovesMap` |
| Pinch et double tap | PASS | `testNativePinchAndDoubleTapZoom` |
| Ouverture et réouverture du profil | PASS | `testOwnAvatarOpensSheetWithoutCalloutAndReopensAfterDismissal` |
| Recentrage après déplacement et tap répété | PASS | `testCardBodyRecentersAfterMapPanAndRepeatedTap` |
| Palette, routes blanches, noms des rues et quartiers | PASS | Vraies tuiles inspectées |
| POI Mapbox masqués, repères Wander et attribution présents | PASS | Capture réelle |
| Brouillard masqué puis réaffiché | PASS | Anneau exploré restauré, îlot central conservé |

Résultat global : **PASS**, 8 tests réussis, aucun échec, aucune vérification
humaine requise. Les quatre avertissements AppIntents préexistants subsistent ;
aucun nouvel avertissement Swift dans le fichier modifié. Six messages Xcode
`debugger version lookup failed ... noURL` apparaissent, sans échec des tests.
La capture visuelle stdout/stderr reste vide : zéro message d'erreur applicatif
capturé, sans prétendre à un audit exhaustif des logs système.

Commandes exactes enregistrées par Xcode :

```bash
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination "platform=iOS Simulator,id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454" -derivedDataPath /Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx -disableAutomaticPackageResolution -skipPackageUpdates -parallel-testing-enabled NO build-for-testing

/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination "platform=iOS Simulator,id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454" -derivedDataPath /Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx -disableAutomaticPackageResolution -skipPackageUpdates -parallel-testing-enabled NO test-without-building "-only-testing:wanderTests/MapboxFogRendererTests" "-only-testing:wanderUITests/MapSocialGestureUITests/testNativePanClosesGroupAndMovesMap" "-only-testing:wanderUITests/MapSocialGestureUITests/testNativePinchAndDoubleTapZoom" "-only-testing:wanderUITests/MapSocialGestureUITests/testOwnAvatarOpensSheetWithoutCalloutAndReopensAfterDismissal" "-only-testing:wanderUITests/MapSocialGestureUITests/testCardBodyRecentersAfterMapPanAndRepeatedTap" -resultBundlePath /tmp/wander-clair-pastel-validation.xcresult
```

Preuves locales :

- `/tmp/wander-clair-pastel-build.log`
- `/tmp/wander-clair-pastel-validation.log`
- `/tmp/wander-clair-pastel-validation.xcresult`
- `/tmp/wander-clair-pastel-visual-stdout.log`
- `/tmp/wander-clair-pastel-visual-stderr.log`
- [Clair pastel et zones explorées](/Users/samuelbarraud/.codex/visualizations/2026/10/09/01a122f5-3532-75a0-8b63-e8eca3c2d3a5/clair-pastel-map/01-clair-pastel-zones-explorees.png)
- [Brouillard uniforme](/Users/samuelbarraud/.codex/visualizations/2026/10/09/01a122f5-3532-75a0-8b63-e8eca3c2d3a5/clair-pastel-map/02-clair-pastel-brouillard.png)

Les captures utilisent `-debug-social-map -debug-social-map-fullscreen
-debug-social-map-fog`, avec de vraies tuiles et des données locales synthétiques.
Le bouton de bascule des zones appartient au scénario Debug. Le simulateur
existant reste démarré avec Clair pastel affiché. Aucun échange Firebase nouveau,
test sur appareil physique ou test d'accessibilité dédié dans ce changement.

### Revue et documentation

`ce-code-review mode:agent base:HEAD` termine avec `status: complete`, aucun
constat et aucune correction restante. Revue lite de la configuration, des
critères AGENTS.md et du plan explicite, sans reviewer délégué.
Reçu : `/tmp/compound-engineering-501/ce-code-review/20261010-090856-ffa6d58e/review.json`.
Aucun fichier de constat dans `todos/` nécessaire.

Le README et les trois notes Obsidian approuvées sont actualisés. Leur propriété
`updated` vaut `2026-10-10T09:11:06+09:00` ; leurs wikilinks sont préservés.
Les plans Nature et Faded gardent leurs preuves historiques. Aucun changement
Git, commit ou publication. `git diff --check` réussit.

`ce-compound` : **Documentation skipped**. La palette et les choix de visibilité
sont directement lisibles dans le code et le README ; aucun nouvel enseignement
non évident ne justifie une note supplémentaire.


## Références

- [Configuration Mapbox Standard](https://docs.mapbox.com/map-styles/reference/standard/)
- [Validation Faded précédente](2026-10-10-style-faded-mapbox.md)

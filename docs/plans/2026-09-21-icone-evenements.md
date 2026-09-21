---
title: Utiliser l'illustration calendrier pour les événements
status: completed
approved_at: 2026-09-21
completed_at: 2026-09-21
---

# Résultat et périmètre

Samuel approuve le plan dans la conversation avec « j'approuve ».
Remplacer le SF Symbol calendrier par l'image fournie, préserver son fond bleu
et ses couleurs, et harmoniser sa taille visible avec les trois autres icônes.
Le bouton natif conserve son diamètre stable de 54 points et ses actions.

## Fichiers affectés

- `wander/Assets.xcassets/TabIconEvents.imageset/Contents.json` et PNG 1×/2×/3×.
- `wander/NativeMapTabView.swift`.
- Ce plan et `todos/059-ready-p2-valider-carrousel-evenements.md`.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md`.

## Mise en œuvre

- [x] Préparer les variantes de l'image fournie selon les dimensions des assets
  existants : 40, 80 et 120 pixels, rendu original.
- [x] Utiliser l'asset dans le bouton et harmoniser son format visible avec les
  icônes natives, dont le conteneur est réduit à 90 %.
- [x] Compiler l'app et les tests, contrôler les dimensions et revoir le diff.
- [x] Actualiser les deux notes Obsidian, leur propriété `updated` et le suivi 059.

## Implémentation et revue

L'image source fournie est redimensionnée sans régénération du dessin avec
`sips`, en trois PNG 40/80/120 pixels. `Contents.json` reprend le rendu original
des autres assets. La miniature UIKit est préparée à 36 points une seule fois,
puis partagée entre les états. Le `UIImageView` est arrondi en cercle comme les
autres icônes ; le dessin central et son fond bleu sont conservés. Bouton 54,
image 36, rayon 18 et marges 9 : les deux diamètres sont les constantes sources,
les autres valeurs sont dérivées. Les callbacks et états natifs restent identiques.

`ce-simplify-code` : trois relectures indépendantes. Proposition de qualité
appliquée pour centraliser la géométrie. Proposition d'efficacité partiellement
appliquée en préparant la miniature une seule fois pour tous les contrôleurs.
Le remplacement par `scaleAspectFit` seul n'est pas retenu : conserver une
taille intrinsèque de 36 points rend le placement du bouton configuré explicite.
Le rendu `.alwaysOriginal` reste explicite comme pour les autres icônes.

Pas de nouveau test pour ce remplacement visuel. Les parcours existants et
leurs assertions de stabilité restent en place et sont compilés. Aucun test
exécuté, aucune preuve visuelle sur simulateur ou iPhone. Pas de nouvelle leçon
validée en exécution à ajouter à `docs/solutions/`.

## Validation finale

- Compilation après simplification : `xcodebuild -project wander.xcodeproj
  -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator'
  -disableAutomaticPackageResolution build-for-testing` :
  `TEST BUILD SUCCEEDED`, code 0. Journal `/tmp/wander-events-icon-build.log`.
- Compilation finale : avertissements AppIntents préexistants uniquement, sans
  dépendance au framework. La première compilation signalait aussi les versions
  des extensions 15/27 contre 42 pour l'app, déjà suivies dans 054.
- Dimensions vérifiées par `sips` : 40×40, 80×80, 120×120. Références du catalogue
  valides ; variante 3× inspectée visuellement. Source 1024×1024 inchangée.
- `git diff --check` : succès.
- `ce-code-review`, lecture lite ciblée sur la nouvelle icône : aucun constat
  retenu. Reçu : `/tmp/compound-engineering-501/ce-code-review/20260921-events-icon/review.json`.
- Les deux notes Obsidian sont mises à jour avec leur propriété `updated`,
  wikilinks préservés, sans ouvrir Obsidian.
- Validation d'exécution `PARTIAL` : compilation réussie, rendu de l'icône et
  interactions sur iPhone non exécutés, explicitement suivis dans 059.

## Risques et validation

Préserver le dessin, sa lisibilité à petite taille et les marges. Conserver
l'état actif du bouton et la géométrie corrigée dans le plan de stabilité.
Contrôle visuel des assets et compilation `build-for-testing` pour iOS Simulator
générique, sans exécution de simulateur ni test dédié d'accessibilité.
La taille perçue et le rendu actif sur appareil restent à confirmer.

## Critères d'acceptation

- Le bouton utilise l'image fournie dans ses deux états avec ses couleurs.
- Les trois variantes sont présentes et le rendu tient dans le bouton de 54 points.
- Compilation app/tests et revue terminées ; limites de validation explicites.
- Notes UX/technique et suivi actualisés, ou limitation d'écriture explicitée.

## État initial

HEAD `5301b3b8f17c961aaaff48b2f4ec8fb125a8a2fd`. Modifications antérieures de
cette conversation conservées dans `NativeMapTabView.swift`, `MotionDockUITests.swift`,
le suivi 059 et le plan de stabilité non suivi. Aucun Git mutant, commit ou
publication. L'autorisation de ce plan couvre l'ajout à ces modifications.

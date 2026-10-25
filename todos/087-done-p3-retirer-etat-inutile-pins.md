---
id: "087"
title: Retirer l'état du pin devenu inutile après le retour natif
status: done
priority: P3
source: ponytail-review
created: 2026-10-25
completed_at: 2026-10-25
tags: [todo, map, refactor]
---

## Constat et preuve

`SavedPlaceAnnotation` copiait cinq champs lus seulement par detailsChanged dans
`MapWithFogView` : adresse, liste, disponibilité, avertissement de localisation et
lien Naver. La fiche native lit déjà SavedPlace. Un changement de liste provoquait
donc une reconfiguration sans changement de rendu.

`SavedPlaceAnnotationView.reserveRestingShape` recalculait trois rectangles à chaque
image. Aucun lecteur dans l'app ; les tests disposaient déjà de currentVisualRect
et renderedBodyRect. Trois propriétés sans lecteur et le nettoyage d'animation
dupliqué complétaient ces suppressions.

## Critères de résolution

- [x] Supprimer les copies, comparaisons, rectangles et calculs sans usage.
- [x] Préserver la mise à jour des coordonnées, du titre et de la catégorie.
- [x] Garder les mêmes assertions de géométrie et l'ordre du callback de fin.
- [x] Actualiser la note technique Obsidian sans modifier ses wikilinks.
- [x] Compilation, tests ciblés et revue finale réussis.

## Résolution

Refactor appliqué, compilation réussie, revue indépendante sans constat.
42 tests natifs et 4 parcours UI réussis sur l'iPhone 18 Pro autorisé,
dans `/private/tmp/wander-ponytail-tests.xcresult`, sans échec ni test ignoré.
Plan : [simplification Ponytail](../docs/plans/2026-10-25-simplifier-pins-ponytail.md).

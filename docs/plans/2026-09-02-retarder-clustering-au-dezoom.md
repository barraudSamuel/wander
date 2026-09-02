---
status: completed
approved_at: 2026-09-02
completed_at: 2026-09-02T11:05:24+09:00
---

# Retarder le clustering au dézoom

## Outcome

Retarder fortement la fusion des personnes et événements pendant le dézoom tout en conservant leurs dimensions visuelles et des cibles tactiles natives.

## Scope

- Utiliser une géométrie de collision MapKit de 24 points pour les personnes et les événements.
- Conserver une cible tactile indépendante de 48 points.
- Conserver les visuels actuels : cercle de présence 88 points, pin 44 points, avatar 36 points et événement 40 points.
- Préserver le regroupement des coordonnées identiques et la liste verticale.

## Non-goals

- Introduire un niveau de zoom fixe qui active brutalement le clustering.
- Remplacer le clustering natif MapKit.
- Modifier l'apparence des marqueurs ou des clusters.

## Affected files

- `wander/MapWithFogView.swift`
- `docs/plans/2026-09-02-retarder-clustering-au-dezoom.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md`

## Implementation checklist

- [x] Ramener les limites de collision des personnes à 24 points.
- [x] Ramener les limites de collision des événements à 24 points.
- [x] Étendre le hit-testing de chaque type à 48 points autour de son centre.
- [x] Conserver les centres visuels et les callouts inchangés.
- [x] Vérifier le point de bascule au dézoom avec des marqueurs espacés de 24 à 48 points.
- [x] Vérifier les coordonnées identiques, les clusters mixtes et la liste verticale.
- [x] Consigner précisément le blocage des mises à jour Obsidian.

## Risks

- Les visuels peuvent se chevaucher davantage avant la fusion ; ce comportement est demandé pour retarder le cluster.
- Deux cibles tactiles de 48 points peuvent se chevaucher alors que les annotations restent distinctes ; UIKit doit conserver une sélection déterministe.
- Le hit-testing étendu ne doit pas déplacer l'ancrage du callout ni détourner les gestes hors de la cible.

## Validation

- Build Debug final pour le simulateur iOS : réussi après retrait de toutes les fixtures locales.
- `git diff --check` : réussi.
- Préconditions DEBUG : limites personne 24 × 24 points, point situé dans la couronne tactile hors `bounds` accepté jusqu'à 48 points, point immédiatement extérieur refusé.
- Scénario de dézoom contrôlé sur l'iPhone 17 Simulator : la paire proche reste individuelle au niveau initial, puis ne fusionne qu'après un dézoom doublé et la stabilisation du recalcul MapKit.
- Les coordonnées strictement identiques forment immédiatement `Groupe, 2 personnes` et la liste s'ouvre en `Groupe ouvert, 2 personnes`.
- Comparaison A/B au même zoom et avec le même espacement : la paire `Ancien A, Ancien B` en collision 48 points est déjà regroupée, tandis que `Nouveau A` et `Nouveau B` en collision 24 points restent indépendants.
- Personnes et événements conservent une cible tactile de 48 points ; les événements gardent un visuel de 40 points et les personnes leurs visuels 44/36/88 points.
- Les `centerOffset`, `calloutOffset`, cadres projetés, fiches et indicateurs hors écran restent inchangés.
- Les fixtures `-debug-clustering-zoom` et `-debug-clustering-comparison` ont été retirées ; absence confirmée par `rg` avant le build final.
- Build final : deux avertissements préexistants de `CFBundleVersion` pour les extensions 15 et 27 face à l'app 29, sans lien avec ce changement.
- Revue manuelle : aucun finding P1, P2 ou P3 ; aucun fichier `todos/` ajouté.

### Mises à jour Obsidian restantes

Les deux notes existent mais ne sont pas inscriptibles depuis cette session (`test -w` échoue). Ne pas créer de vault de remplacement.

#### `Documentation UX.md`

1. mettre à jour la propriété `updated` ;
2. dans `Onglet Explorer > Amis sur la carte`, préciser que le clustering est retardé pendant le dézoom et ne s'appuie plus sur la dimension visuelle complète des marqueurs ;
3. préciser que les cibles tactiles restent à 48 points malgré le seuil de collision réduit ;
4. vérifier le frontmatter, les wikilinks et le paragraphe ajouté dans Obsidian reading view.

#### `Documentation technique.md`

1. mettre à jour la propriété `updated` ;
2. dans `Carte`, documenter les trois géométries distinctes : collision MapKit 24 points, interaction 48 points et visuels existants ;
3. documenter l'extension de `point(inside:with:)` pour les personnes et les événements ;
4. préciser que les offsets, cadres projetés et calculs hors écran utilisent toujours les géométries visuelles ;
5. vérifier le frontmatter, les wikilinks, le paragraphe et le diagramme Mermaid existant dans Obsidian reading view.

## Acceptance criteria

- Des marqueurs séparés de plus de 24 points restent individuels pendant le dézoom.
- Les coordonnées identiques continuent de former un cluster.
- Toute la cible de 48 points reste cliquable.
- Les visuels, callouts, fiches et listes restent centrés et fonctionnels.

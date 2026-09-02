---
status: completed
approved_at: 2026-09-02
completed_at: 2026-09-02T10:51:09+09:00
---

# Réduire le seuil du clustering social

## Outcome

Conserver les marqueurs de personnes individuels jusqu'à ce que leurs cœurs visuels soient réellement proches, au lieu de les regrouper dès que leurs cercles de présence de 88 points se rencontrent.

## Scope

- Réduire la géométrie de collision MapKit des personnes de 88 à 48 points.
- Conserver le cercle de présence visuel de 88 points et l'avatar existant.
- Conserver une cible tactile native de 48 points.
- Aligner le seuil des personnes sur celui des événements.
- Préserver les clusters de coordonnées identiques et la liste verticale.

## Non-goals

- Modifier le rendu ou l'animation des clusters.
- Modifier les coordonnées ou le seuil interne non configurable de MapKit.
- Modifier les indicateurs hors écran ou les fiches.

## Affected files

- `wander/MapWithFogView.swift`
- `docs/plans/2026-09-02-reduire-seuil-clustering-social.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md`

## Implementation checklist

- [x] Découpler la géométrie de collision de la géométrie du cercle de présence.
- [x] Centrer le cercle de 88 points hors des limites de contrôle de 48 points.
- [x] Conserver l'avatar et sa cible tactile centrés.
- [x] Vérifier que des marqueurs proches mais non superposés restent distincts.
- [x] Vérifier que des coordonnées identiques forment toujours un cluster.
- [x] Revalider l'ouverture du cluster et la sélection directe.
- [x] Consigner le blocage exact des mises à jour Obsidian.

## Risks

- Les cercles de présence peuvent se chevaucher légèrement avant le regroupement ; les avatars doivent toutefois rester distincts.
- La réduction des limites ne doit pas décaler le callout ni l'ancrage cartographique.
- La cible tactile doit rester supérieure au minimum de 44 points.

## Validation

- Build Debug final pour le simulateur iOS : réussi après retrait de la fixture locale.
- `git diff --check` : réussi.
- La vue personne expose des limites de contrôle de 48 × 48 points ; une précondition DEBUG l'a confirmé dans la fixture.
- Le cercle de présence reste centré dans 88 × 88 points, dessiné hors des limites compactes grâce à `clipsToBounds = false`.
- Fixture sur l'iPhone 17 Simulator : `Proche A` et `Proche B`, séparés d'environ 60 points, restent deux marqueurs indépendants.
- Deux personnes aux coordonnées strictement identiques produisent toujours `Groupe, 2 personnes`.
- Le groupe réellement superposé s'ouvre toujours en `Groupe ouvert, 2 personnes` avec les deux lignes accessibles.
- La cible tactile reste à 48 points, au-dessus du minimum de 44 points ; avatar de 36 points et pin de 44 points toujours centrés.
- Le callout conserve le même centre cartographique et les indicateurs hors écran continuent d'utiliser l'empreinte visuelle de 88 points.
- La fixture et l'argument `-debug-clustering-threshold` ont été retirés ; absence confirmée par `rg` avant le build final.
- Build final : deux avertissements préexistants de `CFBundleVersion` pour les extensions 27 et 15 face à l'app 29, sans lien avec ce changement.
- Revue manuelle : aucun finding P1, P2 ou P3 ; aucun fichier `todos/` ajouté.

### Mises à jour Obsidian restantes

Les deux notes existent mais ne sont pas inscriptibles depuis cette session (`test -w` échoue). Ne pas créer de vault de remplacement.

#### `Documentation UX.md`

1. mettre à jour la propriété `updated` ;
2. dans `Onglet Explorer > Amis sur la carte`, préciser que les personnes et sorties restent individuelles tant que leurs cœurs de marqueur de 48 points ne se chevauchent pas réellement ;
3. préciser que les cercles de présence peuvent se rapprocher visuellement sans déclencher immédiatement un regroupement ;
4. vérifier le frontmatter, les wikilinks et le paragraphe ajouté dans Obsidian reading view.

#### `Documentation technique.md`

1. mettre à jour la propriété `updated` ;
2. dans `Carte`, documenter la séparation entre les `bounds` MapKit de 48 points et le cercle de présence visuel de 88 points rendu hors limites ;
3. préciser que la cible tactile reste à 48 points, le pin à 44 points et l'avatar à 36 points ;
4. préciser que l'empreinte de 88 points reste utilisée pour les indicateurs hors écran ;
5. vérifier le frontmatter, les wikilinks, le paragraphe et le diagramme Mermaid existant dans Obsidian reading view.

## Acceptance criteria

- Deux marqueurs dont les cœurs visibles ne se recouvrent pas restent séparés.
- Des marqueurs au même emplacement continuent de former un cluster.
- Le cercle de présence, l'avatar, le callout et la sélection restent centrés.
- Les clusters mixtes avec événements continuent de fonctionner.

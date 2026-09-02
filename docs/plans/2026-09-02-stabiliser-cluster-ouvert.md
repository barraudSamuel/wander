---
status: completed
approved_at: 2026-09-02
completed_at: 2026-09-02T10:24:59+09:00
---

# Stabiliser les membres d'un cluster ouvert

## Outcome

Empêcher l'ouverture de la liste verticale d'un cluster social d'agrandir sa zone de collision MapKit et d'absorber un marqueur voisin.

## Scope

- Conserver une géométrie MapKit compacte pendant les états replié et déplié.
- Afficher la liste verticale hors de cette géométrie compacte.
- Maintenir les interactions, le défilement, l'animation et le recentrage de la liste.
- Vérifier que les membres du cluster restent stables pendant son ouverture.

## Non-goals

- Modifier le seuil de regroupement de MapKit.
- Modifier l'apparence ou l'ordre des lignes.
- Modifier le comportement de sélection d'un membre après le clic sur sa ligne.

## Dependencies

- Le rendu vertical existant de `MapSocialClusterAnnotationView`.
- Le suivi du cluster ouvert dans le coordinateur de `MapWithFogView`.

## Affected files

- `wander/MapSocialClusterAnnotationView.swift`
- `wander/MapWithFogView.swift` uniquement si la validation révèle un besoin de coordination supplémentaire
- `docs/plans/2026-09-02-stabiliser-cluster-ouvert.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md`

## Implementation checklist

- [x] Garder les `bounds` et le `centerOffset` compacts dans les deux états.
- [x] Positionner la liste dépliée visuellement au-dessus du même point d'ancrage.
- [x] Étendre le hit-testing aux contrôles visibles hors des `bounds` compacts.
- [x] Préserver le calcul de visibilité et de recentrage basé sur la taille dépliée réelle.
- [x] Valider l'ouverture avec un marqueur voisin situé sous l'empreinte visuelle de la liste.
- [x] Consigner précisément le blocage d'écriture des notes Obsidian et les modifications restantes.

## Risks

- UIKit ignore normalement les touchers hors des limites du parent ; le hit-testing doit couvrir la liste sans détourner les gestes de la carte ailleurs.
- Le point d'ancrage visuel ne doit pas bouger entre les états.
- La correction ne doit pas dégrader le défilement des longues listes ni Dynamic Type.

## Validation

- Build Debug final sur le simulateur iOS : réussi après retrait complet du scénario DEBUG local.
- `git diff --check` : réussi.
- Régression isolée sur l'iPhone 17 Simulator avec trois marqueurs au même point et un quatrième marqueur indépendant placé directement sous l'empreinte visuelle de la liste dépliée.
- Avant ouverture : cluster de trois personnes et marqueur voisin distinct.
- Après ouverture et animation : cluster toujours composé des trois mêmes personnes et marqueur voisin toujours distinct.
- Hit-testing hors des limites compactes : clic sur la ligne basse confirmé par le callback `Membre sélectionné : aya`.
- Fermeture : retour au cluster compact de trois personnes sans déplacement de l'ancrage ni absorption du voisin.
- Dynamic Type `accessibility-large` : liste agrandie, cluster toujours stable et clic sur la ligne basse confirmé par `Membre sélectionné : sam` ; réglage du Simulator restauré à `large`.
- Reduce Motion : le chemin sans animation conserve les mêmes géométries compactes et applique synchroniquement l'état final ; contrôle statique effectué, le Simulator ne proposant pas ce réglage via `simctl ui`.
- Scénario `-debug-cluster-collision` et vue fixture retirés ; absence confirmée par `rg` avant le build final.
- Revue manuelle : aucun finding P1, P2 ou P3 ; aucune modification supplémentaire de `MapWithFogView.swift` nécessaire.

### Mises à jour Obsidian restantes

Les deux notes existent mais ne sont pas inscriptibles depuis cette session (`test -w` échoue). Ne pas créer de vault de remplacement.

#### `Documentation UX.md`

1. mettre à jour le frontmatter `updated` avec la date de cette correction ;
2. dans `Onglet Explorer > Amis sur la carte`, préciser que l'ouverture de la liste verticale conserve exactement les membres du cluster initial et n'absorbe pas les marqueurs voisins recouverts visuellement par la liste ;
3. préciser que toute la surface visible des lignes reste interactive, même hors de l'empreinte compacte du marqueur ;
4. vérifier le frontmatter, les wikilinks et le paragraphe ajouté dans Obsidian reading view.

#### `Documentation technique.md`

1. mettre à jour le frontmatter `updated` avec la date de cette correction ;
2. dans `Carte`, documenter que `MapSocialClusterAnnotationView` conserve ses `bounds` et son `centerOffset` compacts dans les deux états afin de ne pas modifier la collision MapKit ;
3. documenter que la liste est positionnée visuellement hors de ces limites et que `point(inside:with:)` étend uniquement son hit-testing à `expandedContainer` ;
4. préciser que `projectedExpandedFrame(at:)` continue d'utiliser les dimensions visuelles complètes pour le recentrage ;
5. vérifier le frontmatter, les wikilinks, le paragraphe et le diagramme Mermaid existant dans Obsidian reading view.

## Acceptance criteria

- Ouvrir un cluster ne modifie jamais ses membres à cause de la taille de la liste.
- Un marqueur voisin reste indépendant pendant toute l'ouverture.
- Toutes les lignes visibles restent cliquables et scrollables.
- La fermeture restaure le cluster compact sans saut d'ancrage.

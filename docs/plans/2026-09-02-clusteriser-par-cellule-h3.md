---
status: completed
approved_at: 2026-09-02
completed_at: 2026-09-02T11:24:58+09:00
---

# Clusteriser par cellule H3

## Outcome

Interdire tout regroupement entre des personnes ou événements situés dans des cellules H3 différentes, quelle que soit l'échelle de la carte.

## Scope

- Utiliser la cellule H3 de résolution 10 comme partition stricte du clustering social.
- Attribuer un `clusteringIdentifier` MapKit distinct à chaque cellule.
- Recalculer cette partition lors des déplacements des personnes et événements.
- Restaurer les géométries natives de collision et d'interaction à 48 points.
- Préserver les clusters mixtes, les coordonnées identiques et la liste verticale.

## Non-goals

- Forcer le regroupement de tous les marqueurs d'une cellule lorsqu'ils sont visuellement éloignés.
- Modifier la résolution H3 utilisée par l'exploration.
- Remplacer le clustering natif MapKit.

## Affected files

- `wander/MapWithFogView.swift`
- `docs/plans/2026-09-02-clusteriser-par-cellule-h3.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md`

## Implementation checklist

- [x] Produire un identifiant de clustering déterministe à partir de la cellule H3 résolution 10.
- [x] Stocker cet identifiant dans les vues personne et événement.
- [x] Préserver sa désactivation temporaire pendant un focus de sélection.
- [x] Mettre à jour l'identifiant après tout changement de coordonnée.
- [x] Restaurer les limites personne et événement à 48 points et retirer le hit-testing compensatoire.
- [x] Vérifier deux cellules adjacentes à fort dézoom.
- [x] Vérifier une cellule commune, un cluster mixte et un changement de cellule.
- [x] Mettre à jour les notes Obsidian ou consigner précisément le blocage.

## Risks

- Changer l'identifiant d'une vue visible doit provoquer un recalcul MapKit sans laisser un cluster obsolète.
- Un focus sélectionné doit rester hors clustering puis retrouver l'identifiant H3 correct à sa fermeture.
- À très fort dézoom, des marqueurs de cellules différentes resteront volontairement distincts et pourront se chevaucher visuellement.

## Validation

- Build Debug réussi pour `generic/platform=iOS Simulator` avec la fixture, puis après son retrait.
- `git diff --check` réussi.
- Fixture temporaire validée sur l'iPhone 17 Simulator : un cluster mixte de trois membres dans une cellule et deux cellules adjacentes non fusionnées.
- Franchissement simulé d'une frontière H3 validé : MapKit a recalculé deux clusters de deux membres, chacun limité à une cellule.
- La fixture et son argument de lancement ont été retirés avant la build finale.
- Les interactions de liste verticale et de sélection restent couvertes par l'implémentation validée lors des incréments précédents ; aucune modification de leur code n'a été nécessaire.

### Obsidian à reporter

Le vault est présent mais les deux notes sont non inscriptibles depuis cet environnement. Les mises à jour suivantes restent à reporter et à vérifier en reading view :

- `Documentation UX.md` : préciser que le clustering social est strictement limité à une cellule H3 de résolution 10, que deux cellules différentes ne fusionnent jamais même à fort dézoom, et que la liste verticale reste inchangée.
- `Documentation technique.md` : documenter l'identifiant `MapSocialItem.<cellID>`, sa conservation pendant le focus, son recalcul lors des déplacements, et la réinsertion d'une annotation dans MapKit lorsqu'elle franchit une frontière H3.
- Pour chaque note : actualiser la propriété frontmatter `updated`, puis vérifier propriétés, wikilinks, tableaux, callouts, blocs de code et diagrammes Mermaid.

## Acceptance criteria

- Aucun cluster ne contient de membres provenant de plusieurs cellules H3.
- Les marqueurs d'une même cellule continuent d'utiliser le clustering MapKit normal.
- Un changement de cellule met à jour l'appartenance sans état visuel obsolète.
- Les interactions et l'accessibilité existantes sont conservées.

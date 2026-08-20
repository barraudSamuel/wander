---
title: "Fusionner visuellement les cellules d'exploration des amis"
status: in_progress
date: 2026-08-20
owner: "Samuel Barraud"
related: []
tags: [plan, map, friends, exploration, ux]
---

# Fusionner visuellement les cellules d'exploration des amis

## Outcome

Chaque exploration d'ami apparaît comme une masse colorée continue : les
cellules H3 adjacentes ne montrent plus leurs contours internes et aucune
bordure artificielle n'est ajoutée autour de la zone.

## Scope

- Inclus : rendu Core Graphics de `FriendScratchOverlayRenderer`, documentation
  technique et UX associée.
- Exclus : cellules H3, couleurs et opacité existantes, sélection des amis,
  synchronisation Firestore, brouillard, heat map et données d'exploration.

## Non-goals

- Aucun arrondi, flou, halo, ombre ou filtre bitmap.
- Aucun calcul d'union géométrique ni modification des cellules enregistrées.
- Aucun changement de couleur ou d'opacité des explorations.

## Dependencies

- `FriendScratchOverlay` continue de fournir les polygones H3 par ami.
- MapKit continue d'appeler un renderer séparé pour chaque ami sélectionné.

## Affected files

- `wander/MapWithFogView.swift` — chemin unique et remplissage sans `stroke`.
- `docs/plans/2026-08-20-fusion-zones-exploration-amis.md` — suivi du travail.
- `docs/solutions/2026-08-20-fusion-cellules-amis-core-graphics.md` — apprentissage réutilisable.
- `Backlog features.md` dans le vault Obsidian Wander — statut produit.
- `Documentation technique.md` dans le vault Obsidian Wander — stratégie de rendu.
- `Documentation UX.md` dans le vault Obsidian Wander — comportement visible.
- `todos/` — uniquement si la revue révèle un problème restant.

## Implementation checklist

- [x] Passer le plan en `in_progress`.
- [x] Construire un seul `CGMutablePath` pour les cellules visibles d'un ami.
- [x] Remplir le chemin une seule fois avec l'opacité existante de 34 %.
- [x] Supprimer le trait, sa couleur et sa largeur.
- [x] Préserver la superposition de plusieurs amis et l'ordre des overlays.
- [x] Mettre à jour la documentation dépôt et Obsidian.
- [x] Simplifier et revoir le changement.
- [x] Compiler l'application pour un Simulator iOS générique.

## Risks

- Des fissures peuvent apparaître si les cellules sont remplies séparément ; le
  renderer doit donc remplir tous les sous-chemins en une seule opération.
- Sans trait externe, le contraste repose uniquement sur le remplissage à 34 % ;
  cette opacité reste volontairement inchangée dans ce travail.
- Plusieurs amis superposés continuent de mélanger leurs couleurs comme avant.

## Validation

- [x] Le build Debug réussit sans nouvel avertissement.
- [x] Aucun `setStrokeColor`, `setLineWidth` ou `.fillStroke` ne subsiste dans
  `FriendScratchOverlayRenderer`.
- [ ] Les cellules adjacentes d'un ami ne montrent plus de ligne interne.
- [ ] Les cellules isolées et les limites extérieures restent visibles.
- [ ] Plusieurs amis gardent leurs couleurs distinctes.
- [ ] Zoom, panoramique et rotation n'introduisent pas de fissure.
- [x] Les notes Obsidian sont vérifiées en mode Aperçu.

## Review notes

- Cause corrigée : chaque cellule exécutait auparavant un `.fillStroke`, ce qui
  redessinait toutes les arêtes communes et exposait la grille hexagonale.
- Le renderer assemble désormais les cellules visibles dans un seul
  `CGMutablePath`, puis effectue un unique `fillPath()` à 34 %, sans trait,
  filtre, arrondi, halo ni ombre.
- La revue statique confirme l'absence de `setStrokeColor`, `setLineWidth`,
  `.fillStroke` et `drawPath(using:)` dans `MapWithFogView.swift`.
- Build validé avec
  `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' build` : `BUILD SUCCEEDED`.
  Les avertissements préexistants restent la métadonnée App Intents absente et
  le décalage de `CFBundleVersion` entre l'app (`19`) et l'extension (`15`).
- `Backlog features.md`, `Documentation technique.md` et `Documentation UX.md`
  ont été relus dans l'Aperçu Obsidian avec leur propriété `updated`, leurs
  wikiliens et les passages ajoutés correctement rendus.
- La validation interactive des contours, superpositions et transformations de
  caméra reste à réaliser sur l'iPhone 17 Simulator déjà prévu par le projet.

## Acceptance criteria

- Une exploration d'ami est perçue comme une zone colorée fusionnée.
- Aucun contour d'hexagone n'est dessiné.
- Aucun stockage, calcul H3 ou comportement social n'est modifié.

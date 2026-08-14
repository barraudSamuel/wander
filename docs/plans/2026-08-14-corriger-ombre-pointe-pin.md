---
title: "Corriger l'ombre de la pointe des pins"
status: completed
date: 2026-08-14
completed_at: 2026-08-14
owner: "Samuel Barraud"
related:
  - "2026-08-14-pins-users-simples.md"
  - "2026-08-14-opacite-position-ami-ancienne.md"
tags: [plan, mapkit, pins, visual-fix]
---

# Corriger l'ombre de la pointe des pins

## Outcome

La pointe inférieure reste entièrement blanche et nette. L'ombre légère est
limitée au corps circulaire du pin afin de supprimer les bandes grises autour
de la pointe et à sa jonction.

## Scope

- Included:
  - conserver le remplissage cercle + pointe ;
  - calculer l'ombre uniquement depuis l'ovale du cercle ;
  - préserver taille, ancrage, couleur et opacité.
- Not included:
  - redessiner la géométrie du pin ;
  - modifier la fraîcheur ou les callouts ;
  - supprimer l'ombre légère du corps circulaire.

## Affected files

- `wander/MapWithFogView.swift` — frontière de l'ombre du pin.
- `docs/solutions/2026-08-06-navigation-externe-depuis-mapkit.md` — règle de
  dessin durable.
- `docs/plans/2026-08-14-corriger-ombre-pointe-pin.md` — suivi du sprint.

## Implementation

- [x] Séparer le chemin de remplissage du chemin d'ombre.
- [x] Limiter `shadowPath` au cercle de 44 points.
- [x] Vérifier que géométrie, ancrage et opacité restent inchangés.
- [x] Compiler et relire le diff.

## Risks

- L'ombre circulaire peut encore apparaître derrière la base de la pointe — le
  remplissage blanc complet doit rester au-dessus de l'ombre.
- Un changement involontaire du chemin déplacerait la coordonnée — ne modifier
  ni les points de la pointe ni `centerOffset`.

## Validation

- [x] Build Debug pour simulateur réussi.
- [x] `shapeLayer.path` contient toujours cercle + pointe.
- [x] `shapeLayer.shadowPath` contient uniquement le cercle.
- [x] Taille 44 × 52, pointe à y = 52 et ancrage y = -26 inchangés.
- [x] Opacité récente/ancienne inchangée.
- [x] `git diff --check` réussit.

## Acceptance criteria

- [x] Aucune ombre propre à la pointe n'est dessinée.
- [x] L'ombre circulaire légère est conservée.
- [x] Aucun autre comportement du pin ne change.

## Completed validation

- `xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration
  Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath
  /tmp/wander-derived-data build` — succès, code de sortie 0.
- `git diff --check` — succès.
- Revue du tracé — le remplissage utilise toujours le chemin composite ;
  `shadowPath` reçoit uniquement `UIBezierPath(ovalIn: circleRect)`.
- Géométrie — 44 × 52, pointe à `(22, 52)` et `centerOffset.y = -26` inchangés.
- Fraîcheur — l'opacité reste 1 pour une position récente et 0,5 sinon.
- La capture finale sur carte authentifiée reste à confirmer par le propriétaire.

## Review notes

- Hardest decision: conserver l'ombre demandée sans la laisser suivre la pointe.
- Rejected alternatives: retirer toute ombre ou redessiner le pin.
- Least certain: le rendu final devra être confirmé sur une carte authentifiée.

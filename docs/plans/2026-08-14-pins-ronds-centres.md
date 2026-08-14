---
title: "Remplacer les pins par des points ronds centrés"
status: completed
date: 2026-08-14
completed_at: 2026-08-14
owner: "Samuel Barraud"
related:
  - "2026-08-14-pins-users-simples.md"
  - "2026-08-14-opacite-position-ami-ancienne.md"
  - "2026-08-14-corriger-ombre-pointe-pin.md"
tags: [plan, mapkit, pins, visual-fix]
---

# Remplacer les pins par des points ronds centrés

## Outcome

Chaque utilisateur est représenté par un point parfaitement rond, centré sur
sa coordonnée MapKit. La pointe est entièrement supprimée.

## Scope

- Included:
  - cercle extérieur blanc de 44 × 44 points ;
  - cercle intérieur coloré de 36 × 36 avec initiale ;
  - ombre noire légère autour du cercle ;
  - annotation et callout recentrés ;
  - opacité 100 % récente et 50 % ancienne conservée.
- Not included:
  - réintroduire une pointe, un halo ou une animation ;
  - modifier la fraîcheur ou la synchronisation des positions.

## Affected files

- `wander/MapWithFogView.swift` — tracé et centrage des points.
- `docs/solutions/2026-08-06-navigation-externe-depuis-mapkit.md` — contrat
  visuel durable.
- `docs/plans/2026-08-14-pins-ronds-centres.md` — suivi du sprint.

## Implementation

- [x] Réduire le tracé à un seul ovale de 44 points.
- [x] Supprimer toute géométrie liée à la pointe.
- [x] Passer le conteneur à 44 × 44.
- [x] Remettre `centerOffset` et `calloutOffset` à zéro.
- [x] Préserver l'initiale, l'ombre et l'opacité de fraîcheur.
- [x] Compiler et relire le diff.

## Risks

- Le centre du cercle représente la coordonnée, et non son bord inférieur — ce
  comportement est intentionnel et doit être cohérent pour tous les utilisateurs.
- Une réutilisation d'annotation pourrait conserver une ancienne géométrie —
  configurer les dimensions fixes dès l'initialisation de la vue.

## Validation

- [x] Build Debug pour simulateur réussi.
- [x] Aucun segment de pointe ne subsiste dans le tracé.
- [x] Conteneur 44 × 44 et cercle intérieur 36 × 36.
- [x] `centerOffset == .zero` et `calloutOffset == .zero`.
- [x] Opacité 1/0,5 inchangée.
- [x] `git diff --check` réussit.

Validation exécutée le 2026-08-14 :

- `xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/wander-derived-data build` — succès ;
- `git diff --check` — succès ;
- relecture statique de la géométrie et de l'opacité — conforme.

## Acceptance criteria

- [x] Le marqueur est uniquement rond.
- [x] Le rond est centré sur la coordonnée.
- [x] Aucun autre comportement du marqueur ne change.

## Review notes

- Hardest decision: faire du centre du cercle la coordonnée cartographique.
- Rejected alternatives: conserver ou raccourcir la pointe.
- Least certain: la perception du centre exact sur différents niveaux de zoom.

---
title: "Rapprocher le texte circulaire du pin"
status: completed
date: 2026-08-14
completed_at: 2026-08-14
owner: "Samuel Barraud"
related:
  - "2026-08-14-restaurer-texte-circulaire-pins.md"
tags: [plan, mapkit, pins, visual-fix]
---

# Rapprocher le texte circulaire du pin

## Outcome

Le texte de durée reste lisible autour du pin, mais suit un cercle plus compact
et visuellement rattaché au rond central.

## Scope

- Réduire le canevas du texte de 112 × 112 à 88 × 88 points.
- Recentrer le rond fixe de 44 × 44 dans ce canevas.
- Préserver la typographie, la durée, la fraîcheur et les callouts.

## Non-goals

- Modifier la taille du rond ou du texte.
- Ajouter une pointe, un glow, un halo ou une rotation.
- Modifier la synchronisation des positions.

## Dependencies

- Le texte circulaire et le pin partagent le centre de l’annotation MapKit.

## Affected files

- `wander/MapWithFogView.swift` — dimensions et centrage.
- `docs/solutions/2026-08-06-navigation-externe-depuis-mapkit.md` — géométrie durable.
- `docs/plans/2026-08-14-rapprocher-texte-circulaire-pin.md` — suivi.

## Implementation

- [x] Passer le canevas à 88 × 88.
- [x] Positionner le pin 44 × 44 à l’origine 22 × 22.
- [x] Préserver les offsets MapKit à zéro.
- [x] Compiler et relire le diff.

## Risks

- Le texte pourrait toucher le bord blanc sur certaines métriques de police ;
  conserver un espace intérieur mesurable.

## Validation

- [x] Build Debug pour simulateur réussi.
- [x] `git diff --check` réussit.
- [x] Canevas 88 × 88, pin 44 × 44 centré.
- [x] Aucun autre comportement visuel ou métier modifié.

Validation exécutée le 2026-08-14 :

- `xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/wander-derived-data build` — succès ;
- `git diff --check` — succès ;
- vérification géométrique : `(88 − 44) / 2 = 22`, offsets MapKit nuls.

## Acceptance criteria

- [x] Le texte est sensiblement plus proche du pin.
- [x] Le texte et le rond restent concentriques.
- [x] Le rond conserve sa taille dans tous les états.

## Review notes

- Hardest decision: conserver assez d’air pour la lisibilité sans détacher le texte.
- Rejected alternatives: agrandir le pin ou réduire la police.
- Least certain: perception finale sur une carte très chargée.

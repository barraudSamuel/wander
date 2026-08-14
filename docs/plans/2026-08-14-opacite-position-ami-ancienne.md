---
title: "Atténuer les positions d'amis anciennes"
status: completed
date: 2026-08-14
completed_at: 2026-08-14
owner: "Samuel Barraud"
related:
  - "2026-08-14-position-ami-persistante.md"
  - "2026-08-14-pins-users-simples.md"
tags: [plan, mapkit, friends, location-freshness]
---

# Atténuer les positions d'amis anciennes

## Outcome

Le pin conserve sa géométrie minimaliste et sa taille fixe. Il est affiché à
100 % lorsque `sampledAt` date de moins de cinq minutes, puis à 50 % tant
qu'aucune nouvelle position n'a été reçue.

## Scope

- Included:
  - appliquer 50 % d'opacité au pin d'un ami dont la position est ancienne ;
  - restaurer 100 % à chaque nouvelle position récente ;
  - conserver exactement les mêmes dimensions et le même ancrage.
- Not included:
  - ajouter un halo, une animation ou une variation de taille ;
  - modifier la fenêtre de cinq minutes ;
  - conserver un pin lorsque le document de position est explicitement supprimé.

## Affected files

- `wander/MapWithFogView.swift` — opacité du pin selon la fraîcheur.
- `docs/solutions/2026-08-06-navigation-externe-depuis-mapkit.md` — contrat
  visuel disponibilité/fraîcheur.
- `docs/plans/2026-08-14-opacite-position-ami-ancienne.md` — suivi du sprint.

## Implementation

- [x] Appliquer une opacité de 1 ou 0,5 depuis `isLocationFresh`.
- [x] Vérifier que la géométrie et l'ancrage ne varient pas.
- [x] Vérifier la réutilisation des annotations récente/ancienne.
- [x] Compiler et relire le diff.

## Risks

- L'opacité seule n'est pas accessible — conserver le texte « Dernière position
  reçue… » dans le callout et VoiceOver.
- Un pin blanc partiellement transparent peut être moins lisible sur certaines
  cartes — conserver l'ombre existante sans ajouter de glow.

## Validation

- [x] Build Debug pour simulateur réussi.
- [x] Position récente : opacité 1.
- [x] Position ancienne : opacité 0,5.
- [x] Nouvelle position : retour à l'opacité 1.
- [x] Taille fixe 44 × 52 et ancrage inchangé.
- [x] `git diff --check` réussit.

## Acceptance criteria

- [x] Le pin ne disparaît pas uniquement parce que la position vieillit.
- [x] L'ancienneté est visible sans variation de taille ni effet décoratif.

## Completed validation

- `xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration
  Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath
  /tmp/wander-derived-data build` — succès, code de sortie 0.
- `git diff --check` — succès.
- Revue statique — `pinBackgroundView.alpha` vaut 1 lorsque
  `isLocationFresh == true` et 0,5 sinon.
- La géométrie reste fixée à 44 × 52 avec `centerOffset.y = -26`.
- La réutilisation repart d'un `configuredCalloutInfo` nul, donc applique
  systématiquement l'opacité correspondant au nouvel utilisateur.

## Review notes

- Hardest decision: atténuer tout le pin, y compris sa pointe, pour conserver un
  signal visuel uniforme.
- Rejected alternatives: 58 %, halo et réduction de taille.
- Least certain: la lisibilité à 50 % sur les fonds de carte très clairs.

---
title: "Restaurer le texte circulaire autour des pins"
status: completed
date: 2026-08-14
completed_at: 2026-08-14
owner: "Samuel Barraud"
related:
  - "2026-08-14-pins-ronds-centres.md"
  - "2026-08-14-opacite-position-ami-ancienne.md"
tags: [plan, mapkit, pins, presence]
---

# Restaurer le texte circulaire autour des pins

## Outcome

Le texte de présence entoure de nouveau les positions récentes sans modifier le
point rond centré, sans pointe, sans halo et sans animation décorative.

## Scope

- Included:
  - texte circulaire statique « Au même endroit depuis… » ;
  - actualisation périodique de la durée ;
  - cœur rond fixe de 44 × 44 points ;
  - masquage du texte lorsque la position est ancienne ;
  - opacité 50 % du rond ancien conservée.
- Not included:
  - rotation, glow, halo ou variation de taille du cœur ;
  - modification de la synchronisation et du seuil de fraîcheur.

## Dependencies

- `MapUserCalloutInfo.isLocationFresh` reste la source de vérité visuelle.
- Les horodatages `spotEnteredAt` et `locationSampledAt` alimentent la durée.

## Affected files

- `wander/MapWithFogView.swift` — rendu, durée et cycle de vie du texte.
- `docs/solutions/2026-08-06-navigation-externe-depuis-mapkit.md` — contrat visuel.
- `docs/plans/2026-08-14-restaurer-texte-circulaire-pins.md` — suivi.

## Implementation

- [x] Ajouter une vue statique de texte circulaire.
- [x] Centrer le rond fixe dans une zone d’annotation élargie.
- [x] Afficher la durée uniquement pour une position récente et qualifiée.
- [x] Actualiser la durée périodiquement sans animation décorative.
- [x] Nettoyer la minuterie lors de la réutilisation et de la destruction.
- [x] Préserver l’opacité ancienne et les callouts.
- [x] Compiler et relire le diff.

## Risks

- Une zone d’annotation plus large peut augmenter les collisions MapKit ; le
  cœur visible reste néanmoins inchangé et centré.
- Une minuterie mal nettoyée peut continuer après réutilisation ; son cycle de
  vie doit être explicitement borné.

## Validation

- [x] Build Debug pour simulateur réussi.
- [x] `git diff --check` réussit.
- [x] Rond visible 44 × 44 et centré.
- [x] Aucun tracé de pointe, halo, glow ou animation de rotation.
- [x] Texte absent quand `isLocationFresh == false`.
- [x] Opacité du rond égale à 0,5 pour une position ancienne.

Validation exécutée le 2026-08-14 :

- `xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/wander-derived-data build` — succès ;
- `git diff --check` — succès ;
- recherche statique des anciens effets et relecture du cycle de vie de la minuterie — conformes.

## Acceptance criteria

- [x] Le texte de durée entoure une position récente qualifiée.
- [x] Le rond conserve sa taille et son centrage dans tous les états.
- [x] Une position ancienne n’affiche pas « Au même endroit depuis… ».
- [x] Aucun comportement de navigation ou de synchronisation ne change.

## Review notes

- Hardest decision: élargir seulement la zone transparente de l’annotation.
- Rejected alternatives: rotation, halo et changement de taille du cœur.
- Least certain: densité visuelle lorsque plusieurs amis sont proches.

---
title: "Simplifier les pins des utilisateurs"
status: completed
date: 2026-08-14
completed_at: 2026-08-14
owner: "Samuel Barraud"
related:
  - "2026-08-14-position-ami-persistante.md"
tags: [plan, mapkit, pins, friends, ui]
---

# Simplifier les pins des utilisateurs

## Outcome

Tous les utilisateurs sont représentés par un pin fixe et minimal : une
silhouette blanche avec une petite pointe, un cercle intérieur coloré et
l'initiale du pseudo. Le pin indique précisément sa coordonnée et ne change ni
de taille ni d'opacité selon la fraîcheur de la position.

## Scope

- Included:
  - géométrie fixe de 44 × 52 points ;
  - cercle coloré de 36 points avec initiale ;
  - contour blanc et ombre neutre légère ;
  - pointe ancrée sur la coordonnée MapKit ;
  - même rendu pour soi, les amis, les positions récentes et anciennes ;
  - suppression du halo, de l'anneau de durée et de leurs animations ;
  - conservation des callouts et de leurs informations textuelles.
- Not included:
  - utiliser la capture ou une photo de profil comme asset ;
  - modifier la synchronisation ou la rétention des positions ;
  - modifier l'action « Rejoindre » ou les profils d'amis.

## Dependencies

- La couleur et le pseudo existants restent la source du cercle et de
  l'initiale.
- La fraîcheur reste disponible pour les textes, sans effet sur le pin.

## Affected files

- `wander/MapWithFogView.swift` — dessin, taille et ancrage du pin.
- `docs/solutions/2026-08-06-navigation-externe-depuis-mapkit.md` — contrat
  visuel durable.
- `docs/plans/2026-08-14-pins-users-simples.md` — suivi du sprint.

## Implementation

- [x] Remplacer l'anneau actuel par une silhouette fixe cercle + pointe.
- [x] Afficher uniquement l'initiale sur le cercle coloré.
- [x] Supprimer image, halo, durée circulaire et variation récente/ancienne.
- [x] Positionner la pointe exactement sur la coordonnée.
- [x] Préserver callouts, actions et libellés d'accessibilité.
- [x] Simplifier et relire le diff.

## Risks

- Une pointe mal ancrée décale visuellement la position — régler explicitement
  `centerOffset` et `calloutOffset`.
- Une ombre trop large recrée un glow — utiliser une ombre noire courte et
  faiblement opaque.
- La suppression de l'anneau retire un signal de présence — garder cette
  information dans le callout et le profil.

## Validation

- [x] Build Debug pour simulateur réussi.
- [x] Tous les pins ont exactement la même géométrie.
- [x] Aucune vue de halo ou d'anneau animé ne subsiste.
- [x] La pointe correspond à la coordonnée MapKit.
- [x] Les positions anciennes et récentes ont le même rendu.
- [x] Les callouts et « Rejoindre » restent câblés et compilent.
- [x] `git diff --check` réussit.

## Acceptance criteria

- [x] Le pin est un cercle coloré avec initiale, bordure blanche et pointe.
- [x] Aucun glow ni effet décoratif n'est visible.
- [x] La taille ne varie jamais selon l'état de l'utilisateur.

## Completed validation

- `xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration
  Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath
  /tmp/wander-derived-data build` — succès, code de sortie 0.
- `git diff --check` — succès.
- Recherche statique — aucune ancienne classe de halo, anneau, avatar ou minuteur
  visuel ne subsiste dans `MapWithFogView.swift`.
- Géométrie — conteneur 44 × 52, cercle 36 × 36 et `centerOffset.y = -26` ;
  l'extrémité située à `y = 52` coïncide donc avec la coordonnée MapKit.
- État — `isLocationFresh` est utilisé uniquement pour les textes du callout et
  l'accessibilité, jamais pour la taille, l'opacité ou la couleur du pin.
- Simulateur — la build a été installée et lancée sur un iPhone 17 Pro. Sans
  session Apple de test, l'application reste sur l'authentification et les pins
  n'ont pas pu être photographiés sur une carte authentifiée.

## Review notes

- Hardest decision: conserver une ombre de lisibilité sans recréer un glow.
- Rejected alternatives: avatar, halo, durée circulaire et opacité d'état,
  contraires à la direction minimaliste approuvée.
- Least certain: l'ancrage exact devra être jugé visuellement sur la carte.

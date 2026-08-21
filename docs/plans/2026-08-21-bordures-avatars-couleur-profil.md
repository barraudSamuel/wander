---
title: "Colorer les bordures des avatars sur la carte"
status: in_progress
date: 2026-08-21
approved_at: "2026-08-21T16:20:55+09:00"
started_at: "2026-08-21T16:20:55+09:00"
owner: "Samuel Barraud"
related:
  - "2026-08-14-avatars-dans-pins-carte.md"
tags: [plan, ios, mapkit, profile, avatars, ux]
---

# Colorer les bordures des avatars sur la carte

## Outcome

Les avatars du compte courant et des amis visibles directement sur la carte
utilisent leur couleur de profil pour leur anneau, au lieu de l'anneau blanc
actuel. Le rendu reste cohérent avec le rail d'amis, les fiches de profil et les
indicateurs hors champ.

## Context

- `FriendAvatarBadge` colore déjà les bordures dans le rail et les surfaces de
  profil.
- `FriendOffscreenIndicatorView` applique déjà la couleur de profil à la
  bordure et au pointeur des avatars hors champ.
- `UserLocationAnnotationView` dessine encore les pins visibles sur un fond
  circulaire blanc, dont la marge de quatre points forme l'anneau actuel.

## Scope

- Inclus : pins MapKit visibles du compte courant et des amis, actualisation de
  la couleur lors d'un changement de profil ou de la réutilisation d'une vue,
  documentation UX correspondante.
- Exclus : illustrations d'avatar, tailles, ombres, texte de présence, rail
  d'amis, fiches de profil, indicateurs hors champ, zones d'exploration et
  données Firestore.

## Proposed approach

Transmettre la couleur locale à `MapWithFogView`, puis faire suivre la couleur
locale ou distante jusqu'à `UserLocationAnnotationView`. Le fond circulaire de
la pin devient configurable et utilise `ProfileColor.uiColor`, sans ajouter une
nouvelle forme ni modifier la géométrie actuelle. Chaque configuration réécrit
la couleur afin qu'une vue MapKit réutilisée ne conserve jamais celle d'un
autre profil.

## Affected files

- `wander/ContentView.swift` — transmission de la couleur du compte courant.
- `wander/MapWithFogView.swift` — propagation et rendu dynamique de l'anneau.
- `docs/plans/2026-08-21-bordures-avatars-couleur-profil.md` — suivi du travail.
- `Backlog features.md` dans le vault Obsidian Wander — état de l'amélioration.
- `Documentation UX.md` dans le vault Obsidian Wander — comportement visible
  des avatars cartographiques.
- `todos/` — uniquement si la revue révèle un problème restant.

## Implementation

- [x] Transmettre la couleur de profil locale à `MapWithFogView`.
- [x] Configurer l'anneau de la pin locale avec cette couleur.
- [x] Configurer l'anneau de chaque pin d'ami avec sa couleur synchronisée.
- [x] Garantir l'actualisation des vues MapKit existantes et réutilisées.
- [x] Mettre à jour la documentation UX et le backlog Obsidian.
- [ ] Compiler, vérifier le rendu et relire le diff.

## Edge cases and risks

- Une vue d'annotation réutilisée peut conserver la couleur précédente — la
  couleur est appliquée à chaque configuration, pas seulement à la création.
- Une couleur vide ou invalide peut atteindre le rendu — conserver la
  normalisation et le repli déterministe fournis par `ProfileColor`.
- Une couleur proche de l'illustration peut réduire la séparation visuelle —
  conserver l'épaisseur actuelle de quatre points et l'ombre existante.
- Une position ancienne doit rester identifiable — conserver l'alpha actuel
  appliqué à la pin complète.

## Validation

- [x] Le build Debug du scheme `wander` réussit sans nouvel avertissement.
- [ ] Sur l'iPhone 17 Simulator déjà actif, la pin locale et les pins d'amis
  utilisent leur couleur de profil.
- [ ] Un changement de couleur actualise une pin existante sans déplacement.
- [ ] L'avatar, l'ombre, le texte de présence, la sélection et l'opacité des
  positions anciennes restent inchangés.
- [ ] Les indicateurs hors champ et le rail d'amis ne régressent pas.
- [x] Les notes Obsidian modifiées sont vérifiées en mode lecture.

## Acceptance criteria

- Chaque pin d'utilisateur visible sur la carte possède un anneau de la couleur
  du profil correspondant.
- Aucun anneau ne conserve la couleur d'un autre utilisateur après réutilisation.
- Le reste du rendu et des interactions cartographiques demeure inchangé.

## Review notes

- Hardest decision: conserver exactement la géométrie approuvée en recolorant
  le fond circulaire existant, dont la marge autour de l'image forme déjà
  l'anneau de quatre points.
- Rejected alternatives: ajouter un second `CAShapeLayer` de contour aurait
  doublé le dessin et le risque d'aliasing ; modifier `ProfileAvatarView`
  aurait touché le rail, les profils et les pickers hors périmètre.
- Least certain: le rendu simultané de plusieurs couleurs, la sélection et
  l'opacité des positions anciennes restent à contrôler sur le simulateur,
  actuellement éteint.

## Validation results

- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug
  -destination 'generic/platform=iOS Simulator' build` — succès le 21 août
  2026. Aucun avertissement Swift lié au changement ; avertissements existants
  sur la version de la Share Extension et les métadonnées de build.
- `git diff --check` — succès.
- Vérification statique — la couleur locale participe au cache de configuration
  et chaque configuration de pin d'ami fournit explicitement sa couleur ou son
  repli déterministe.
- Obsidian — frontmatter `updated`, wikilinks, callout, tableau et nouvelle
  entrée de backlog rendus correctement en mode lecture dans `Documentation
  UX.md` et `Backlog features.md`.
- iPhone 17 Simulator — non exécuté : aucun iPhone 17 n'est actuellement
  démarré et le dépôt interdit d'en démarrer un sans approbation explicite.
- Revue — aucun finding P1, P2 ou P3 restant ; aucun fichier `todos/` créé.
- Compound — pas de note `docs/solutions/` : le changement réutilise les
  mécanismes existants sans apprentissage surprenant ou généralisable.

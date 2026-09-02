---
status: completed
approved_at: 2026-09-01
completed_at: 2026-09-01T21:50:00+09:00
---

# Uniformiser les marges du cluster replié

## Outcome

Donner au cluster social replié une marge visuelle identique de 7 pt en haut, en bas, à gauche et à droite autour de ses éléments de 34 pt.

## Scope

- Réduire la largeur compacte de 72 pt à 48 pt.
- Conserver la taille, le chevauchement vertical, l'animation et l'état déplié existants.

## Non-goals

- Modifier la liste verticale dépliée.
- Modifier les interactions ou la logique MapKit.

## Dependencies

- Aucune.

## Affected files

- `wander/MapSocialClusterAnnotationView.swift`
- `docs/plans/2026-09-01-uniformiser-marges-cluster-replie.md`

## Implementation checklist

- [x] Appliquer une largeur compacte calculée à partir de l'élément et de l'inset.
- [x] Vérifier le diff et compiler l'application.

## Risks

- La capsule plus étroite pourrait rogner une ombre ou un contour si sa largeur n'inclut pas exactement les deux insets.

## Validation

- `git diff --check` : réussi.
- Build Debug pour le simulateur iOS : réussi avec `xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/wander-social-cluster-derived-data -disableAutomaticPackageResolution build`.
- Géométrie contrôlée : `34 + 7 + 7 = 48 pt`.
- Aucun changement de l'état déplié ou des interactions.

## Acceptance criteria

- Les marges latérales du cluster replié sont égales aux marges haute et basse.
- L'état déplié et ses interactions restent inchangés.

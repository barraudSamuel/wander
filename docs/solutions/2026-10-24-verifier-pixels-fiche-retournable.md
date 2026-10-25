---
title: "Vérifier les pixels d’une fiche UIKit retournable"
module: "Carte Explorer"
date: "2026-10-24"
problem_type: ui_bug
component: frontend
severity: medium
symptoms:
  - "Le verso disparaît visuellement alors que ses boutons restent hittables et les tests UI passent"
root_cause: wrong_api
resolution_type: code_fix
framework_version: "UIKit, simulateur iOS 27.0"
tags: [mapbox, uikit, animation, saved-places, visual-testing]
---

# Vérifier les pixels d’une fiche UIKit retournable

## Problème observé

Pendant la correction des pins photo, le parcours automatisé ouvrait la fiche,
touchait Informations, trouvait le texte du verso et utilisait ses boutons.
Le test passait. Pourtant, la capture intitulée « Verso de la fiche ancrée »
ne montrait que la carte : aucun panneau ni texte.

Le résultat d’un hit-test et la présence dans l’arbre d’accessibilité ne prouvent
donc pas qu’une face transformée est effectivement dessinée. Cette distinction
est utile lorsqu’une animation modifie les couches sans modifier la hiérarchie UIKit.

## Cause et correction locale

L’ancienne composition faisait tourner le parent de 180 degrés et appliquait
une seconde rotation de 180 degrés au verso, avec `isDoubleSided = false`.
Dans cette hiérarchie UIKit, le verso était éliminé du rendu. Les observations
ne permettent pas de généraliser ce comportement à toutes les hiérarchies Core Animation.

Dans `wander/SavedPlaceCalloutView.swift`, la face change au passage de 90 degrés.
Seul le parent tourne ; l’angle visible vaut l’angle courant sur le recto et
l’angle courant moins π sur le verso. Le verso n’a plus sa propre demi-rotation.
À la fin, son parent est donc à zéro degré et ses textes sont droits.

```swift
isShowingInformation = cos(state.angle) < 0
let visibleAngle = isShowingInformation ? state.angle - .pi : state.angle
rotatingView.layer.transform = CATransform3DRotate(transform, visibleAngle, 0, 1, 0)
```

Le correctif est local, non commité. Une capture sur le simulateur après correction
montre le panneau blanc, le nom, l’adresse, les avertissements et les boutons.
Le plan `docs/plans/2026-10-24-pins-adresses-fidelite-video.md` conserve les preuves
et les résultats finaux ; la suite UI seule n’a pas servi de preuve visuelle.

## Prévention

Pour une transition 3D, conserver une capture des deux faces et une courte vidéo
des images intermédiaires. Vérifier les pixels avant de conclure à partir des
assertions `exists` ou `isHittable`. Les tests de géométrie restent nécessaires
pour l’ancrage et les collisions, mais répondent à une autre question.

---
title: "Stabiliser le rendu MapKit pendant le redimensionnement d'une fiche"
module: "Carte Explorer"
date: "2026-09-08"
problem_type: runtime_error
component: frontend
severity: high
symptoms:
  - "SIGABRT sur iPhone 12 mini pendant le redimensionnement de la carte"
  - "Assertion Metal lors de la libération d'une texture CAMetalLayer Display Drawable"
root_cause: async_timing
resolution_type: code_fix
framework_version: "iOS 26.5.2, MapKit sur GPU A14"
tags: [solution, mapkit, metal, viewport, swiftui, device-testing]
related_plan: "../plans/2026-09-08-corriger-crash-metal-et-arrondir-fiches.md"
---

# Stabiliser le rendu MapKit pendant le redimensionnement d'une fiche

## Problème et preuve

Les tests de gestes sur simulateur passaient, mais ouvrir une fiche au-dessus
de la carte faisait planter l'app sur l'iPhone 12 mini connecté. La session
Xcode avec Metal API Validation s'arrêtait sur SIGABRT. La pile remontait de
`MTLDebugDevice.notifyExternalReferencesNonZeroOnDealloc` jusqu'à
`CAMetalLayer.setDrawableSize`, `MetalSwapchain::resize` et `MKMapView.setFrame`.
Une texture restait utilisée par un command buffer au moment de sa destruction.

Cette pile désigne le redimensionnement du rendu MapKit natif. Elle ne prouve
pas un défaut des overlays de brouillard ou du renderer Core Graphics de Wander.
La cause interne de gestion des textures Apple reste hors du code applicatif.

## Déclencheur retiré

Le conteneur animait directement la hauteur de `MKMapView`. Le test de régression
mesurait 678,67 pt avant ouverture et 317,33 pt après. Conserver l'identité de
la vue ne suffisait donc pas : son drawable changeait de taille.

`MapDetailSplitView` transmet maintenant la taille entière disponible par
`mapRenderSize`. `MapViewportView` possède la carte et garde ses bounds à cette
taille. Il la centre dans sa propre fenêtre, qui peut changer de hauteur et se
faire découper par les coins arrondis. Les dimensions natives ne sont réassignées
que lorsque la taille totale disponible change, par exemple après rotation.
Cette correction est locale et reste non commitée au moment de la validation.

```swift
if mapView.bounds.size != size {
    mapView.bounds.size = size
}
mapView.center = CGPoint(x: bounds.midX, y: bounds.midY)
```

Un simple masque autour d'une carte toujours redimensionnée laisserait le
déclencheur intact. Désactiver la validation Metal masquerait le signal qui a
permis le diagnostic et ne constitue pas la correction retenue.

## Repère visible

La fenêtre convertie dans la carte native peut avoir une origine non nulle.
Les indicateurs hors champ et les listes de groupes utilisent ce rectangle ;
les gestes du rail utilisent les coordonnées locales de la petite fenêtre.
Les marges MapKit maintiennent ses contrôles natifs dans la partie visible.

Pour ajuster la caméra, projeter `centerCoordinate` avant de calculer la
translation. Dans le test réel avec safe area, ce point valait y=451 alors que
`bounds.midY` valait 437. Supposer leur égalité laissait un dépassement de 14 pt.
La position projetée d'une annotation peut aussi précéder son layout UIKit ;
les tests attendent que le cadre natif ait rejoint la projection.

## Validation et prévention

Le test UI échoue sur la version variable et passe avec le conteneur. Trois
tests du viewport contrôlent les dimensions natives aux positions intermédiaires,
les conversions et les changements de taille totale. Un test de groupe couvre
une fenêtre de 220 × 150 pt d'origine non nulle et la stabilité de sélection.

Sur iPhone 12 mini iOS 26.5.2, le test physique ouvre et ferme quatre fois une
sortie existante, parcourt douze positions et effectue quatre glissements.
`/tmp/wander-iphone-metal-smoke.xcresult` rapporte une réussite ; le journal de
cette exécution confirme `Metal API Validation Enabled`, sans assertion ni SIGABRT.
Le plan lié conserve les validations finales et leurs limites.

Pour une prochaine modification de ce conteneur, contrôler à la fois les bounds
natifs et les gestes sur appareil. Un simulateur peut prouver le contrat de
géométrie sans reproduire les conditions du GPU physique.

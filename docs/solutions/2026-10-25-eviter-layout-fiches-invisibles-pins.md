---
title: "Éviter le layout des fiches invisibles pendant les animations des pins"
module: "Carte Explorer"
date: "2026-10-25"
problem_type: performance_issue
component: frontend
severity: medium
symptoms:
  - "Le déplacement devient saccadé quand plusieurs photos changent de taille"
  - "Le calcul des collisions reste inférieur à une milliseconde malgré des frames longues"
root_cause: wrong_api
resolution_type: code_fix
framework_version: "Mapbox Maps 11.32.0, simulateur iPhone 18 Pro iOS 27"
tags: [mapbox, uikit, performance, animation, saved-places]
---

# Éviter le layout des fiches invisibles pendant les animations des pins

## Problème

Après activation des agrandissements pendant le mouvement, une première version du correctif produisait des intervalles de rendu au 95e percentile proches de 42 ms dans un scénario de 36 pins. Le calcul des collisions ne prenait qu’environ 0,7 ms. Accuser ce calcul aurait orienté la correction vers le mauvais coût.

## Symptômes mesurés

Un échantillonnage du processus montrait surtout les transactions Core Animation, le layout UIKit, le dessin du texte et les contraintes des UILabel. Les catégories se dessinaient correctement, mais chaque petite photo recalculait aussi sa fiche masquée : titre, boutons et scroll d’informations.

Le scénario utilise une carte Mapbox sans fond, 36 adresses, trois séquences identiques de déplacement et zoom. Les intervalles sont mesurés entre callbacks `onRenderFrameFinished`, séparément du temps passé dans le résolveur. Ce ne sont pas des mesures GPU ou une garantie de cadence sur appareil physique.

## Tentative insuffisante

Garder la priorité Mapbox des pins ordinaires constante évite des invalidations inutiles, mais n’a pas suffi à retrouver une cadence régulière. Le premier essai avec échantillonnage CPU était lui-même perturbé par le profileur ; il ne sert pas de comparaison chronométrique.

## Solution

Dans `wander/SavedPlaceCalloutView.swift`, `apply` calcule `hasCard` à partir du pied de fiche, de son opacité et de l’angle de retournement. Sans fiche visible, il met à jour la photo, la pointe et la catégorie, masque les contrôles et quitte avant les mesures du titre et le redimensionnement du scroll :

```swift
scrollView.isHidden = !hasCard
guard hasCard else { return }
```

Les éléments de la fiche continuent à être disposés pendant son ouverture, son retournement et sa fermeture. La correction reste locale, non commitée.

Après cette correction, trois passages sans profileur ont donné des intervalles au 95e percentile de 18,58 / 17,79 / 17,70 ms. La validation suivante, avec les corrections de stabilité et de précision, donne 17,73 / 17,77 / 18,01 ms ; le coût du résolveur au 95e percentile reste inférieur à 0,71 ms. La version antérieure au sprint avait aussi une cadence proche de 60 Hz, mais gelait les promotions : la comparaison à 42 ms concerne bien la première version du correctif, pas cette version antérieure.

## Pourquoi cela fonctionne

Une vue invisible peut encore générer du travail de layout si on continue à modifier sa géométrie. Le coût se multiplie par le nombre de pins et par les frames de leurs transitions. Éviter les calculs de fiche tant que seule la photo est visible conserve le même rendu sans faire travailler les contrôles masqués.

## Prévention

Mesurer séparément le temps du résolveur et les intervalles de rendu. Si le premier reste faible, profiler le layout et les vues enfants avant de réécrire l’algorithme de collision. Refaire la mesure sans profileur et vérifier l’ouverture/fermeture de la fiche après avoir supprimé du travail invisible.

## Références

- [Plan du correctif et validation](../plans/2026-10-25-fluidite-et-priorite-pins-adresses.md).
- Test reproductible : `wanderTests/SavedPlaceAnnotationTests.swift`, `testDenseCameraFrameCadence`.
- Mesures locales : `/private/tmp/wander-pin-motion-green1.log`, `/private/tmp/wander-pin-motion-cadence3.log`, `/private/tmp/wander-pin-motion-green3.log`.
- Profil CPU local : `/private/tmp/wander-pin-motion-cpu.txt`.

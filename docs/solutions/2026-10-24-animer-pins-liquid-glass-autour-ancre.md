---
title: "Animer les pins Liquid Glass autour de leur ancre"
module: "Carte Explorer"
date: "2026-10-24"
problem_type: ui_bug
component: frontend
severity: medium
symptoms:
  - "Le cercle se décale pendant la sélection malgré une géométrie cible correcte"
  - "La frame de présentation du matériau diffère de la transformation demandée à la vue"
root_cause: wrong_api
resolution_type: code_fix
framework_version: "iOS 27.0, simulateur iPhone 18 Pro"
tags: [solution, mapbox, uikit, liquid-glass, animation, saved-places]
related_plan: "../plans/2026-10-24-pins-adresses-etats-animations.md"
---

# Animer les pins Liquid Glass autour de leur ancre

## Problème

Un pin sélectionné semblait correctement placé à la fin de son animation, mais son cercle pouvait dériver pendant le mouvement. La première assertion projetait l'ancre de la géométrie cible dans la carte. Elle passait même lorsque le matériau dessiné s'en éloignait.

## Symptômes mesurés

Le test renforcé de `wanderTests/SavedPlaceAnnotationTests.swift` lit la couche de présentation pendant la transition et compare son centre à la projection Mapbox. Une mesure trouvait x=62,64 au lieu de x=71, soit un décalage de plus de 8 pt sur les deux axes.

Dans cette mesure, le parent avait déjà sa bonne frame. Le matériau présentait une frame `(0, 0, 31.27, 31.27)`, alors que sa frame modèle était `(0, 0, 48, 48)`. Le test de la seule géométrie cible ne pouvait pas détecter cette différence.

## Tentatives insuffisantes

- Animer directement la frame du `UIVisualEffectView` produisait le décalage.
- Fixer son centre et animer ses bounds produisait encore le même échec.
- Garder des bounds de 48 pt et appliquer directement une échelle au matériau ne donnait pas une mesure de présentation cohérente sur ce runtime. Huit échantillons montraient une transformation modèle de 0,8333, mais une transformation de présentation identité et une largeur de 48 pt.

Ces observations ne déterminent pas le mécanisme interne de UIKit. Elles suffisent à écarter ces approches dans le composant testé.

## Solution

Dans `wander/SavedPlaceAnnotation.swift`, un `UIView` ordinaire contient le matériau et le symbole. Ses bounds restent à 48 × 48 pt. Le matériau reste à 48 × 48 pt et l'icône à 24 × 24 pt, tous deux sans transformation. Seule l'échelle du conteneur change pour produire les diamètres visibles de 28, 40 et 48 pt.

Le centre du conteneur est fixé à l'ancre avant l'animation. Une interruption lit sa largeur dans la couche de présentation et reprend cette échelle. Le store réserve toujours l'espace nécessaire entre la taille courante et la cible. Mapbox garde la responsabilité de la position extérieure ; les textes restent mesurés indépendamment de ses anciennes frames.

La correction est locale et non commitée. Le 24 octobre 2026, les dix tests de `SavedPlaceAnnotationTests` passent sur le simulateur autorisé dans `/private/tmp/wander-pins-container.xcresult`. Les exécutions rouges du diagnostic sont conservées dans `/private/tmp/wander-pins-diagnostic.xcresult`, `/private/tmp/wander-pins-anchor-fix.xcresult` et `/private/tmp/wander-pins-glass-probe.xcresult`. Le plan lié contient la validation finale de l'application et ses captures.

## Pourquoi cette séparation fonctionne

L'animation porte sur une vue UIKit ordinaire, dont la couche de présentation décrit l'enveloppe transformée. Le matériau conserve sa géométrie interne. Les mesures n'assimilent plus la destination logique au contenu actuellement dessiné.

## Prévention

Conserver les assertions sur le centre réellement rendu pendant plusieurs images, y compris après interruption. Vérifier aussi les bounds et transformations fixes des enfants. Une capture au repos ou la seule comparaison avec l'ancre cible ne suffit pas à valider une animation géographique.

## Références

- [Plan des états et animations](../plans/2026-10-24-pins-adresses-etats-animations.md).
- [Stabiliser le rendu de carte pendant une fiche](2026-09-08-stabiliser-rendu-mapkit-pendant-fiche.md), pour distinguer les dimensions natives de la fenêtre visible.

---
title: "Rendre les interactions MapKit immédiates"
date: 2026-09-02
tags: [solution, mapkit, gestures, performance, ux]
related:
  - ../plans/2026-09-02-rendre-taps-carte-immediats.md
---

# Rendre les interactions MapKit immédiates

## Problème

L'ouverture d'un ami, d'un événement ou d'un groupe reposait uniquement sur
`MKMapViewDelegate.mapView(_:didSelect:)`. MapKit arbitre cette sélection avec
ses gestes de panoramique et de zoom, ce qui introduit un temps mort perceptible
avant que l'application reçoive le callback. Les animations de 360 ms pour un
groupe et de 420 ms pour une fiche événement amplifiaient ensuite cette lenteur.

## Résolution

`MapWithFogView.Coordinator` installe un `UILongPressGestureRecognizer` public
avec une durée minimale nulle, limité par son delegate aux vues d'annotations
sociales compactes. Il fournit un retour d'opacité dès le début du toucher,
s'annule lorsque le doigt dépasse la tolérance de mouvement, puis active
l'annotation au relâchement avant de demander sa sélection à MapKit.

Le même chemin d'activation reste appelé par `didSelect` pour VoiceOver et les
sélections programmatiques. Un identifiant d'annotation absorbe uniquement le
callback natif qui suit une activation immédiate afin de ne pas déclencher deux
rafraîchissements ou deux présentations.

Le reconnaisseur accepte également un toucher commencé sur le fond de carte.
S'il se termine sans dépasser la tolérance de mouvement, les annotations
sociales sélectionnées sont désélectionnées sans animation MapKit : la
fermeture ne dépend donc plus de `didDeselect` produit par le tap interne de la
carte. Un panoramique annule cette fermeture, et les contrôles ou éléments dont
le trait accessible est un bouton restent exclus.

L'ordre du hit-test est important : un `UIControl` enfant est exclu en premier,
mais une `MKAnnotationView` doit être reconnue avant d'examiner son trait
accessible `.button`. Sinon les pins accessibles sont eux-mêmes exclus et
l'ouverture retombe silencieusement sur la sélection différée de MapKit.

Les gestes MapKit restent simultanés. Les rangées interactives d'un groupe
ouvert sont exclues parce qu'elles sont des `UIControl`, tout comme les
accessoires de callout. Aucun reconnaisseur interne de MapKit n'est désactivé ou
reconfiguré.

L'ouverture d'un groupe et la transition de la fiche durent désormais 180 ms.
Le groupe rend ses rangées opaques dès la première frame et la fiche utilise une
transition d'échelle sans fondu initial.

## Preuves

- `git diff --check` réussit.
- Le build Debug pour iOS Simulator réussit.
- Les seuls avertissements sont les deux différences de `CFBundleVersion`
  préexistantes entre l'app et ses extensions.
- Le build est installé et lancé sur l'iPhone 17 Simulator existant.
- La validation de taps réels reste bloquée par l'écran de connexion Apple du
  simulateur et ne doit pas être considérée comme acquise.

## Prévention

- Une interaction applicative prioritaire ne doit pas dépendre exclusivement
  de la reconnaissance de sélection interne d'un composant cartographique.
- Conserver le callback natif comme fallback accessible et programmatique.
- Limiter tout reconnaisseur supplémentaire aux cibles nécessaires et annuler
  rapidement dès qu'un déplacement commence.
- Mesurer séparément le temps avant callback et la durée de l'animation ; une
  animation de plusieurs centaines de millisecondes peut être perçue comme de
  la latence même si l'état change immédiatement.

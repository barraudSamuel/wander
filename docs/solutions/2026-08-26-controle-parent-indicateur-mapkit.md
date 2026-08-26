---
title: "Transmettre le toucher d’un indicateur MapKit à son contrôle parent"
date: 2026-08-26
category: ux
tags: [solution, mapkit, uikit, events]
related_plan: "../plans/2026-08-26-recentrer-evenements-bord.md"
---

# Transmettre le toucher d’un indicateur MapKit à son contrôle parent

## Problem

Les indicateurs d’amis hors champ recentraient la carte au toucher, tandis que
les indicateurs d’événements visuellement équivalents ne répondaient pas.

## Root cause

`OutingOffscreenIndicatorView` est un `UIControl`, mais son contenu visuel est
un `OutingCategoryBadgeView`. Contrairement à l’`UIImageView` de l’indicateur
d’ami, cette sous-vue UIKit était interactive par défaut et devenait la cible
du hit test. Le contrôle parent ne recevait donc pas son événement
`touchUpInside`.

Une sélection demandée immédiatement après un recentrage animé peut être
ignorée tant que MapKit n’a pas recréé la vue de l’annotation hors écran.

## Solution

Le badge décoratif est rendu non interactif avec
`isUserInteractionEnabled = false`. Le contrôle parent reçoit ainsi le toucher
sur toute sa cible de 48 points. L’action de l’indicateur d’événement conserve
le recentrage animé et mémorise l’événement à sélectionner. Dès que la vue
d’annotation devient disponible pendant le mouvement ou son ajout, la demande
est consommée une seule fois par `selectAnnotation`.

Le délégué MapKit existant traite ensuite cette sélection comme le toucher d’un
pin visible et ouvre la fiche de l’événement.

## What did not work

Appeler `selectAnnotation` immédiatement après `setRegion(animated: true)`
n’est pas fiable lorsque le pin part hors écran. Ouvrir directement la fiche
sans sélectionner l’annotation aurait désynchronisé l’état MapKit. Modifier le
geste du rail d’amis aurait aussi traité le mauvais niveau, puisque les
indicateurs d’amis fonctionnaient déjà.

## Validation

- Revue du diff : le contrôle d’ami reste inchangé ; l’événement attend que sa
  vue MapKit existe avant de la sélectionner une seule fois.
- `git diff --check` réussit.
- Build Debug générique iOS Simulator réussi le 2026-08-26.
- Avertissement préexistant uniquement : `CFBundleVersion` de l’extension `15`
  différent de celui de l’app `26`.
- Validation interactive non exécutée : tous les iPhone 17 Simulator sont
  arrêtés et les règles du dépôt interdisent d’en démarrer un sans approbation.

## Reusable lesson and prevention

Le contenu décoratif d’un `UIControl` personnalisé doit être explicitement non
interactif, sauf s’il porte sa propre action. Pour des indicateurs composés,
vérifier le hit test de chaque sous-vue et valider séparément l’action du bouton
de bord et celle de l’annotation visible. Une action MapKit visant une
annotation hors écran doit aussi attendre la disponibilité de sa vue avant de
la sélectionner.

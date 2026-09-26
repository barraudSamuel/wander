---
title: "Conserver le défilement d’une liste sous une fiche carte"
date: 2026-09-10
last_updated: 2026-09-23
category: ux
tags: [solution, swiftui, events, navigation]
related_plan: "../plans/2026-09-10-liste-evenements-carte.md"
---

# Conserver le défilement d’une liste sous une fiche carte

## Problème

Le panneau partagé doit alterner entre une liste d’événements et une fiche
sans perdre la position de lecture ni la hauteur choisie avec la séparation.
La surface native MapKit doit également rester stable pendant ces transitions.

## Solution actuelle

Dans le changement local du 23 septembre, le panneau Événements reste dans le
même emplacement de `MapDetailSplitView`. `MapEventsPanelView` contient une
`NavigationStack` dont le chemin est dérivé de l’événement sélectionné encore
disponible. Le retour natif efface cette sélection ; il ne ferme pas le panneau.
La hauteur reste détenue par le split, et la navigation native conserve la
position de défilement de la liste.

Le tri utilise date et identifiant stable. Les données de la fiche proviennent
des mêmes présentations que celles de la carte. Les observations des lignes sont
suspendues pendant le détail ; le service conserve l’observation de l’événement
sélectionné.

## Vérification

`testEventDetailFromListReturnsAtSameScrollAndPanelHeight` charge dix-huit
événements, agrandit le panneau, rejoint la ligne 12, ouvre le détail puis revient.
Il vérifie position de cette ligne, rectangle utile de la liste, hauteur du
panneau et dimensions natives MapKit. Ce parcours passe sur l’iPhone 17 déjà
lancé, dans `/tmp/wander-event-detail-validation.xcresult`.

La collection native recouvre aussi la zone sous la barre de navigation et le
dock. Dans le diagnostic observé, elle renvoie `isHittable=false` alors que sa
première ligne renvoie `true`. Le toucher réel de cette ligne ouvre la fiche et
le bouton natif revient à la liste. La capture de hiérarchie et le journal du
scénario sont conservés sous `/tmp/wander-event-hit-diagnostic.xcresult` et
`/tmp/wander-event-hit-diagnostic.log`.

Les tests vérifient donc la racine de navigation, puis un enfant effectivement
interactif dans le viewport utile. Celui-ci est borné par le panneau, la barre
native et les contrôles inférieurs. Les gestes partent de ce viewport ; les
petits déplacements évitent de sauter un bouton dans une fiche compacte.
Ne pas remplacer les vrais touchers par la seule présence d’un élément.

## Historique

La version du 10 septembre conservait la liste dans un `ZStack`, sous une fiche
superposée. Elle utilisait ensemble opacité, `allowsHitTesting` et
`accessibilityHidden`. Son test de l’époque s’appelait
`testEventListResizeScrollAndReturnPreservePosition`. Ces détails décrivent
l’ancienne présentation, remplacée par la navigation native du 23 septembre.

Le principe demeure : l’existence d’un contrôle dans l’arbre XCTest ne suffit
pas à établir sa visibilité, et le rectangle d’une collection native n’est pas
nécessairement sa zone utile de lecture.

Plan actuel : [Détail événement dans le panneau](../plans/2026-09-23-detail-evenement-panneau.md).

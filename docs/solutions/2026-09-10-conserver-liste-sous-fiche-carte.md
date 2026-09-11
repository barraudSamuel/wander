---
title: "Conserver le défilement d’une liste sous une fiche carte"
date: 2026-09-10
category: ux
tags: [solution, swiftui, events, navigation]
related_plan: "../plans/2026-09-10-liste-evenements-carte.md"
---

# Conserver le défilement d’une liste sous une fiche carte

## Problème

Le panneau supérieur doit alterner entre une liste d’événements et une fiche
sans perdre la position de lecture ni la hauteur choisie avec la séparation.
La surface native MapKit doit également rester stable pendant ces transitions.

## Solution

`MapDetailSplitView` reste présenté. Sa position de redimensionnement n’est plus
réinitialisée quand la sélection devient vide. `MapEventsPanelView` conserve sa
`List` dans le même emplacement d’un `ZStack`, puis ajoute la fiche au-dessus.
La liste reçoit une opacité nulle, `allowsHitTesting(false)` et
`accessibilityHidden(true)` pendant la consultation. Son état de défilement
reste détenu par le même contrôle natif. Le retour retire seulement la fiche.

Le tri utilise date et identifiant stable. La liste réutilise les données de
présentation déjà accessibles à la carte, sans listener de participants par ligne.

## Vérification

`testEventListResizeScrollAndReturnPreservePosition` charge dix-huit événements,
agrandit la liste, vérifie que davantage de lignes sont visibles, fait défiler,
ouvre une ligne puis revient. Il compare la position verticale de cette ligne
et le rectangle du panneau avant et après consultation.

Un contrôle initial supposait à tort que la collection native disparaissait de
l’arbre XCTest quand la liste était masquée. Le contrôle attendu porte sur son
absence d’interaction pendant la fiche, puis sur son retour visible. Ne pas
confondre existence du contrôle natif et visibilité de son contenu.

Les résultats détaillés et les limites des données de démonstration se trouvent
dans le plan lié. Conserver les trois propriétés de masquage ensemble lors d’une
évolution de cette présentation.

---
title: "Fusionner visuellement des cellules H3 sans calcul d'union"
date: 2026-08-20
tags: [solution, mapkit, core-graphics, h3, friends]
related:
  - "../plans/2026-08-20-fusion-zones-exploration-amis.md"
---

# Fusionner visuellement des cellules H3 sans calcul d'union

## Problème

Dessiner chaque cellule H3 avec `.fillStroke` trace son contour complet. Les
arêtes partagées par deux cellules adjacentes restent donc visibles et la zone
ressemble à une grille d'hexagones au lieu d'une surface continue.

## Solution retenue

Construire un unique `CGMutablePath` contenant un sous-chemin fermé pour chaque
cellule visible, puis appeler `fillPath()` une seule fois. Aucun `stroke`, trait
élargi, union géométrique ou filtre bitmap n'est nécessaire.

## Pourquoi cette approche fonctionne

- Les sous-chemins utilisent exactement les coordonnées H3 existantes.
- Un remplissage unique évite d'ajouter une arête graphique sur les frontières
  communes.
- L'opacité et la couleur restent appliquées une seule fois par ami.
- Les overlays de plusieurs amis restent indépendants et continuent de se
  superposer dans l'ordre MapKit existant.

## Garde-fous

- Ne pas revenir à `.fillStroke` si aucun contour externe distinct n'est requis.
- Remplir tous les sous-chemins en une seule opération pour limiter les fissures
  d'anticrénelage entre cellules adjacentes.
- Ne pas utiliser d'arrondi en pixels pour des cellules dont la géométrie doit
  rester stable pendant le zoom.

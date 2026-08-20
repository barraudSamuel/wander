---
title: "Préserver les zones révélées MapKit pendant le dézoom"
date: 2026-08-18
tags: [solution, mapkit, core-graphics, fog-of-war, performance]
related:
  - "../plans/2026-08-18-fog-of-war-plus-clair-contours-lisses.md"
---

# Préserver les zones révélées MapKit pendant le dézoom

## Problème

Un filtre morphologique défini en pixels peut sembler arrondir un ensemble de
cellules H3 à un niveau de zoom donné, mais il modifie la géométrie en fonction
de sa taille à l'écran. Pendant le dézoom, l'ouverture érode les composantes
plus petites que son rayon et peut faire disparaître des zones révélées.

## Solution retenue

Le renderer remplit la tuile avec le voile uniforme à 22 %, construit un seul
chemin Core Graphics avec les cellules H3 qui intersectent la tuile, puis perce
directement ce chemin avec le mode `.clear`. Il n'utilise aucun bitmap hors
écran, filtre Core Image, trait élargi, halo, ombre ou flou.

## Pourquoi cette approche fonctionne

- La découpe utilise la géométrie géospatiale elle-même, pas une taille écran.
- Un dézoom réduit visuellement les cellules sans pouvoir les éroder ni les
  supprimer par un rayon fixe.
- Tous les sous-chemins sont percés ensemble, sans ajouter de séparation entre
  cellules adjacentes.
- Le renderer et l'ordre des overlays restent inchangés pour les autres couches.

## Garde-fous

- Ne pas appliquer d'érosion ou d'ouverture exprimée en pixels à des données
  géospatiales qui doivent rester visibles à tous les zooms.
- Vérifier les zones à plusieurs zooms et pendant la rotation, pas seulement
  sur une capture statique.
- Ajuster l'opacité du voile indépendamment du masque ; elle ne doit pas changer
  la donnée qui détermine quelles cellules sont découvertes.

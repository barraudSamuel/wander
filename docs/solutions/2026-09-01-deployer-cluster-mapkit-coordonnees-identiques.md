---
title: "Présenter verticalement un cluster MapKit à coordonnées identiques"
date: 2026-09-01
category: architecture
tags: [solution, mapkit, clustering, annotations, accessibility, ux]
related_plan: "../plans/2026-09-01-remplacer-deploiement-radial-par-pile-verticale.md"
---

# Présenter verticalement un cluster MapKit à coordonnées identiques

## Problem

Plusieurs positions et sorties au même endroit recouvraient leurs avatars,
leurs badges et les textes circulaires de présence. Un simple zoom ne pouvait
pas les séparer puisque leurs coordonnées géographiques restaient identiques.
Le premier déploiement radial résolvait le toucher mais créait une disposition
en étoile trop éloignée du langage visuel calme de la carte.

## Root cause

Des annotations partageant exactement une coordonnée ne peuvent pas être
séparées géographiquement par un zoom. Les afficher toutes avec une priorité
requise superpose leurs vues ; déplacer temporairement toutes les vues avec des
`centerOffset` rend leur relation avec le lieu moins évidente.

## Solution

Les vues de personnes et de sorties partagent un `clusteringIdentifier`, tandis
que le pin temporaire de création en reste exclu. Une vue dédiée de
`MKClusterAnnotation` possède deux états verticaux :

1. repliée, elle montre une pile compacte de trois représentations au maximum
   et un compteur ; lorsqu'un groupe mélange personnes et sorties, un badge de
   sortie garde toujours une place visible ;
2. déployée, elle allonge la même annotation en une colonne de contrôles UIKit
   ordonnés, avec avatar ou badge, nom et contexte ;
3. la hauteur est plafonnée et devient scrollable pour les grands groupes ; la
   largeur et les lignes augmentent pour les catégories Dynamic Type
   d'accessibilité ;
4. un recentrage n'est demandé que si la colonne sortirait de la zone sûre, et
   toute animation personnalisée est supprimée avec Réduire les animations.

Les lignes déployées sont des proxys d'interaction, mais pas des annotations de
remplacement. Lorsqu'une ligne est activée, le coordinateur retrouve
l'annotation réelle par son identifiant, désactive temporairement son
clustering, la réinsère avec une priorité requise, zoome sur sa coordonnée et la
sélectionne. Les callbacks, callouts et fiches existants restent ainsi portés
par le vrai marqueur. Une désélection, un geste de caméra ou une mutation de la
composition réinsère la cible dans le clustering.

MapKit expose la vue d'annotation comme un seul élément VoiceOver même lorsque
ses sous-contrôles sont visibles. Le groupe ouvert fournit donc aussi une action
d'accessibilité nommée pour chaque ligne, en plus de ses zones tactiles UIKit.

## What did not work

- Zoomer seulement : des coordonnées identiques restent indissociables.
- Afficher toutes les vues avec une priorité requise : les zones tactiles et les
  durées se superposent.
- Déployer radialement les annotations avec des connecteurs : l'interaction est
  fonctionnelle mais le résultat devient visuellement agité et occupe trop de
  carte.
- Utiliser une feuille détachée : la sélection serait lisible, mais perdrait la
  continuité demandée entre le groupe replié et son ouverture sur la carte.
- Déplacer les coordonnées des modèles : cela rendrait les positions affichées
  inexactes et contaminerait les calculs géographiques.

## Validation

- Build Debug iOS Simulator réussi après retrait de la fixture.
- Fixture temporaire vérifiée sur l'iPhone 17 Simulator iOS 26.3 avec deux amis,
  le compte et deux sorties à la même coordonnée, puis retirée du code final.
- Pile repliée et colonne ouverte contrôlées en modes sombre et clair.
- Sélection d'une sortie contrôlée : repli, zoom, marqueur réel au premier plan
  et callback de fiche.
- Repli extérieur et restauration du cluster contrôlés.
- Taille `accessibility-extra-large` contrôlée avec largeur et lignes adaptées ;
  libellés complets et actions VoiceOver générées pour chaque membre.
- `git diff --check` réussi.

## Reusable lesson and prevention

Pour des annotations MapKit qui peuvent partager exactement une coordonnée,
laisser le clustering natif gérer l'état compact et garder l'expansion dans la
vue du cluster. Ne sortir du clustering que la cible effectivement choisie :
cela préserve les coordonnées, réduit les mutations MapKit et maintient les
interactions sur les annotations réelles. Associer tout changement de région
programmatique à une garde bornée évite que le repli prévu pour les gestes
utilisateur annule le focus en cours.

Aucune règle supplémentaire n'est ajoutée à `AGENTS.md` : ce comportement est
spécifique à l'architecture cartographique de Wander.

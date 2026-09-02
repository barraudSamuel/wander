---
title: "Regrouper les marqueurs sociaux par proximité géographique"
date: 2026-09-02
category: architecture
tags: [solution, mapkit, clustering, core-location, annotations, ux]
related_plan: "../plans/2026-09-02-garantir-clusters-h3-visibles.md"
---

# Regrouper les marqueurs sociaux par proximité géographique

## Problem

Le compte courant, les amis et les événements représentant un même lieu réel
devaient rester regroupés à tous les niveaux de zoom. À l'inverse, deux lieux
distincts devaient rester séparés même si leurs marqueurs se superposaient à un
fort dézoom.

## Root cause

Le clustering natif de MapKit répond à la collision de vues en points et non à
une distance géographique. Sa composition change donc avec la caméra. Une
cellule H3 de résolution 10 est stable géographiquement mais trop grande pour
représenter un établissement et introduit une frontière arbitraire entre deux
positions proches.

Construire directement un `MKClusterAnnotation` ne remplace pas ce mécanisme :
ce type et son identifiant interne appartiennent à MapKit. Un groupe métier
stable doit être une annotation applicative ordinaire.

## Solution

`MapWithFogView.Coordinator` conserve les annotations sources séparément des
représentants attachés à la carte. À chaque changement de composition ou de
coordonnées sociales :

1. les distances Core Location de chaque paire sont calculées une seule fois ;
2. les groupes sont fusionnés de façon déterministe seulement si chaque paire
   de la fusion respecte sa limite, ce qui interdit les chaînes de proximité ;
3. une paire nouvelle peut se regrouper jusqu'à 20 mètres ;
4. une paire déjà regroupée reste liée jusqu'à 25 mètres pour absorber le bruit
   GPS ;
5. les associations déjà retenues sont reconstruites en priorité afin qu'un
   nouveau voisin ne déstabilise pas un groupe encore valide ;
6. un groupe d'au moins deux membres devient un
   `MapSocialProximityGroupAnnotation`, tandis qu'un membre isolé conserve son
   annotation source ;
7. un représentant existant est réutilisé selon le recouvrement de ses membres
   pour conserver l'état ouvert et éviter les clignotements.

La signature des sources et le membre éventuellement sélectionné sont mis en
cache. Un panoramique ou un zoom ne relance donc ni les calculs de distance ni
la synchronisation MapKit.

Toutes les vues sociales ont `clusteringIdentifier = nil` et une priorité
requise. `MapSocialClusterAnnotationView` conserve sa pile compacte et sa liste
verticale, mais elle présente désormais l'annotation applicative. Lorsqu'un
membre est choisi, sa vraie annotation est temporairement attachée séparément ;
les autres membres gardent leur représentant et le groupe complet est restauré
à la désélection.

## What did not work

- Le clustering visuel natif : sa composition varie avec le zoom.
- H3 résolution 10 : sa zone est trop large pour signifier « même café ».
- Une résolution H3 plus fine : deux personnes proches peuvent rester de part
  et d'autre d'une frontière de cellule.
- Une simple connexité à 20 mètres : une chaîne de personnes peut réunir des
  extrémités éloignées de plus de 20 mètres.
- Un seuil unique : les oscillations GPS autour de la limite font clignoter le
  groupe.
- Des `MKClusterAnnotation` construites par l'application : leur gestion interne
  appartient à MapKit.

## Validation

- Build Debug réussi pour le simulateur iOS.
- Fixture temporaire validée sur l'iPhone 17 Simulator iOS 26.3 puis retirée.
- Groupe mixte compte, ami et événement créé à 19 mètres.
- Composition inchangée aux zooms rue, ville et monde.
- Groupe conservé à 24 mètres puis séparé à 26 mètres.
- Paire initiale à 21 mètres laissée indépendante.
- Cas 0 m / 15 m / 30 m validé sans groupe unique par effet de chaîne.
- Tous les représentants sont restés visibles avec priorité requise.
- Build final réussi après le retrait complet de la fixture, puis application
  réinstallée et lancée normalement sur le simulateur actif.
- `git diff --check` réussi après la revue finale.

## Reusable lesson and prevention

Une notion produit exprimée en mètres doit être modélisée en mètres, pas avec
la collision de vues ni une grille choisie pour un autre domaine. Pré-calculer
les distances de paires, imposer une contrainte complète au groupe et séparer
les seuils d'entrée et de sortie donne un regroupement stable, testable et
indépendant de la caméra.

Aucune règle supplémentaire n'est ajoutée à `AGENTS.md` : les seuils et le
comportement restent spécifiques à la carte sociale de Wander.

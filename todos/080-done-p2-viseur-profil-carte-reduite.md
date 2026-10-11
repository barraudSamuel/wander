---
id: "080"
title: "Éviter le chevauchement du viseur et du profil"
status: done
priority: P2
source: visual-review
created: 2026-10-11
tags: [todo, map, ux]
---

# Éviter le chevauchement du viseur et du profil

## Constat

Après avoir rattaché le viseur à la carte visible, l'agrandissement maximal de
la liste pouvait placer le viseur devant le bouton de profil. Le premier test
vérifiait que le viseur restait dans la carte, sans contrôler cette intersection.

## Preuve

Capture initiale : `/tmp/wander-actions-captures/CA258E6B-40ED-40D6-8890-053618DAD0F5.png`.

## Résolution

`MapDetailSplitView.maximumListHeight` réserve une hauteur minimale à la carte
lorsque l'action de recentrage est présente. Le test
`testMapActionsStayRightAndRecenterFollowsResizedMap` vérifie aussi l'absence
d'intersection avec `map-own-profile` à l'agrandissement maximal.

La validation finale et ses captures sont consignées dans le
[plan approuvé](../docs/plans/2026-10-11-position-actions-carte.md).

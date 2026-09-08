---
id: "032"
title: "Préserver la fiche pendant les gestes de carte"
status: done
priority: P1
source: review
created: 2026-09-08
resolved: 2026-09-08
tags: [todo, map, ux]
---

# Préserver la fiche pendant les gestes de carte

## Constat

Relier la fermeture de la fiche supérieure à la désélection MapKit faisait
disparaître les informations pendant un panoramique ou un zoom. La disparition
du marqueur d'un ami devenu indisponible produisait le même effet, alors que
son profil devait rester consultable.

## Résolution

`ContentView` et le scénario local conservent une sélection de fiche indépendante
du focus natif. Une fermeture explicite, une nouvelle sélection ou l'invalidation
de l'entité pilote son remplacement. `MapWithFogView` ne réapplique une demande
de focus que lorsque l'identifiant demandé change ; un rafraîchissement ou un
redimensionnement ne resélectionne donc pas l'ancien marqueur.

## Acceptation et preuves

- [x] Le panoramique déplace réellement la carte sans retirer la fiche ni modifier sa hauteur.
- [x] Fermer la fiche annule aussi une sélection native encore en attente.
- [x] La revue confirme le maintien du profil sans position ; le retrait de l'amitié le ferme.
- [x] Les 48 tests ciblés passent sur l'iPhone 17 existant.

Le test `testNativePanWorksInMapBelowEventPane` contrôle le déplacement d'un
repère géographique, la présence de Café et la hauteur des deux zones.
Résultat : `/tmp/wander-split-tests-final.xcresult`.
La transition réelle du mode fantôme avec Firebase reste un contrôle manuel
distinct, consigné dans le backlog Obsidian et le
[plan](../docs/plans/2026-09-08-fiches-carte-ecran-partage.md).

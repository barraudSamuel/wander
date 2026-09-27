---
id: "065"
title: "Recibler la carte d'un événement déjà sélectionné"
status: done
priority: P2
source: review
created: 2026-09-26
resolved: 2026-09-26
tags: [todo, events, map, ios]
---

# Recibler la carte d'un événement déjà sélectionné

## Constat et preuve

Le nouveau `MapEventScrollRequest` distingue les demandes successives par UUID,
mais `MapWithFogView.endImmediateSocialPress` ignorait les annotations déjà
sélectionnées. Après avoir ouvert une carte puis défilé ailleurs, toucher à
nouveau son repère n'émettait pas la demande de défilement attendue.
La contre-lecture et la lecture SwiftUI l'ont identifié ; le validateur l'a
confirmé dans les sources. Aucun échec en exécution n'a été observé.

## Résolution

- Le geste mémorise si l'annotation était sélectionnée au début du toucher.
- Lorsque ce même repère est encore sélectionné au relâchement, seul un
  `OutingPlanAnnotation` émet à nouveau `onSelectOutingPlan`.
- La copie de cet état précède la restauration visuelle, qui le remet à zéro.
  Le premier toucher, éventuellement déjà traité par MapKit, ne gagne pas de
  callback supplémentaire dans cette branche.
- Profils, groupes et géométrie MapKit conservent leurs chemins existants.

## Vérification

- [x] Relecture ciblée indépendante du correctif, aucun autre constat retenu.
- [x] Scénario `testSelectingSameEventPinAgainReturnsToItsCard` adapté au second
  toucher sans défilement par helper après le tap du repère.
- [x] Scénario initial ajouté : `testInitiallyTargetedEventScrollsToItsCard`
  vérifie directement la carte 18, sans helper de défilement.
- [x] App et tests compilés avec `build-for-testing`, résultat
  `TEST BUILD SUCCEEDED`, code 0. Journal
  `/tmp/wander-autonomous-cards-final-build.log`. Aucun diagnostic Swift,
  trois avertissements AppIntents préexistants. `git diff --check` passe.

Les tests sont compilés seulement. L'exécution et le rendu restent non vérifiés
conformément au [plan approuvé](../docs/plans/2026-09-26-cartes-evenements-autonomes.md).

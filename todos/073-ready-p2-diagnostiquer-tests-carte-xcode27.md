---
id: "073"
title: "Diagnostiquer les échecs des tests de caméra et de destruction isolée"
status: ready
priority: P2
source: review
created: 2026-10-09
tags: [todo, map, xcode, testing]
---

# Diagnostiquer les échecs des tests de caméra et de destruction isolée

## Constat

La validation sur l'iPhone 17 Pro iOS 26.3 avec Xcode 27 révèle un échec dans
`MapFriendCameraControllerTests.testInsufficientSpaceAndInvalidGeometryDoNotMoveTheMap` :
le test attend `nil` et reçoit `(0.0, 0.0)`. Un autre test de cette classe quitte
ensuite le processus avec une erreur de libération mémoire.

La nouvelle fixture du Coordinator révélait aussi un plantage au nettoyage,
dans `swift_task_deinitOnExecutorImpl` pendant la destruction de
`ExplorationEngine.BoundaryCache`. Cette pile identifie le point de plantage,
pas sa cause profonde. La correction des sélections conserve un Coordinator
pour la durée du processus de test, puis remet ses sources, sa sélection, son
observateur et ses callbacks à zéro entre les cas. Elle ne corrige pas la
destruction du cache.

## Preuves

- `/private/tmp/wander-nearby-final.log` : échec géométrique et plantage avant
  redémarrage du runner. Les totaux après redémarrage ne sont pas le total de
  la commande et ne rendent pas ce lancement réussi.
- `/private/tmp/wander-nearby-baseline-comparison.log` : même assertion et même
  plantage du test de caméra avec les sources d'origine au commit
  `9076c1047b9b1c82e8ae3b36312ee9d0706dcb72`. Ils ne sont pas introduits par
  l'arbitrage des touchers.
- `/Users/samuelbarraud/Library/Logs/DiagnosticReports/wander-2026-10-09-112432.ips` :
  pile du plantage du cache isolé.
- La comparaison à la version d'origine et les résultats ciblés du correctif
  sont consignés dans [le plan](../docs/plans/2026-10-09-selection-unique-amis-proches.md).

## Critères d'acceptation

- [ ] Identifier pourquoi la géométrie invalide reçoit une cible `(0.0, 0.0)`.
- [ ] Isoler le plantage de destruction sans l'attribuer à un runtime sans preuve.
- [ ] Faire passer la classe de tests de caméra sans redémarrage du runner.
- [ ] Réévaluer la fixture partagée lorsque la destruction peut être testée normalement.

## Périmètre

Ce suivi ne change pas la correction des amis proches. Toute correction de
caméra, de cache ou de configuration nécessitera son propre plan approuvé.

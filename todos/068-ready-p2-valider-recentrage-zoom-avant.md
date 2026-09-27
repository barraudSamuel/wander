---
id: "068"
title: Valider le recentrage limité au zoom avant
status: ready
priority: P2
source: review
created: 2026-09-26
tags: [todo, map, validation]
---

# Valider le recentrage limité au zoom avant

## Constat

Le contrôleur acquiert désormais une cible uniquement lors d'une phase de zoom
avant. Dézoomer arrête le focus et conserve la caméra affichée comme référence.
L'app et les tests compilent ; les tests XCTest et les gestes n'ont pas été
exécutés, aucun simulateur n'étant démarré lors du contrôle.

## Validation attendue

- [ ] Exécuter `wanderTests/MapEdgeZoomControllerTests` sur l'iPhone 17 ouvert.
- [ ] Dézoomer directement : centre fixe, aucune attraction ni vibration.
- [ ] Zoomer : recentrage et retour haptique conservés.
- [ ] Inverser vers le dézoom avant, pendant et après le focus : pas de saut ni animation résiduelle.
- [ ] Revenir au zoom avant : acquisition possible depuis le cadrage courant.
- [ ] Vérifier sur les deux rails, sous une fiche, à vitesse lente et rapide.

## Revue

Les trois passes de simplification ont trouvé un calcul de coordonnées inutile
en dézoom ; il est supprimé. Aucun défaut de correction retenu lors de la
relecture ciblée. Le rendu au doigt reste à vérifier.

## Références

- [Plan](../docs/plans/2026-09-26-recentrage-zoom-avant.md)
- Journaux : `/private/tmp/wander-zoom-in-focus-build.log` et `/private/tmp/wander-zoom-in-focus-final.log`.

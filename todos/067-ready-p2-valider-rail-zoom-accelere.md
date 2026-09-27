---
id: "067"
title: Valider le rail de zoom élargi et accéléré sur iPhone 17
status: ready
priority: P2
source: review
created: 2026-09-26
tags: [todo, map, validation]
---

# Valider le rail de zoom élargi et accéléré sur iPhone 17

## Constat

La zone de bord mesure 44 points et le gain de zoom varie de ×1 à ×3 selon la
vitesse verticale. L'app et les tests compilent, mais aucun simulateur n'était
démarré lors de la vérification par `xcrun simctl list devices booted`.
Les tests XCTest et les gestes n'ont donc pas été exécutés.

## Validation attendue

- [ ] Exécuter `wanderTests/MapEdgeZoomControllerTests` sur l'iPhone 17 ouvert.
- [ ] Vérifier les deux rails, avec la carte entière puis sous une fiche.
- [ ] Comparer des déplacements identiques à vitesse lente puis rapide, vers le haut et le bas.
- [ ] Ralentir après un geste rapide et vérifier le retour à un réglage précis.
- [ ] Vérifier l'arrêt au relâchement, les limites de caméra, le panoramique hors rail et les contrôles proches du bord.

## Références

- [Plan](../docs/plans/2026-09-26-rail-zoom-acceleration.md)
- [Contrôleur](../wander/MapEdgeZoomController.swift)
- [Tests](../wanderTests/MapEdgeZoomControllerTests.swift)
- Journaux de compilation : `/private/tmp/wander-zoom-build.log` et `/private/tmp/wander-zoom-build-final.log`.

## Revue

Les trois revues de simplification ont relevé une assertion répétée sans
couverture supplémentaire. Elle a été supprimée. Aucun autre défaut retenu.
Relecture de correction : gain symétrique, plafond, limites, accumulation avant
centrage animé et arrêt du geste inspectés. La sensation au doigt reste à valider.
Les avertissements Xcode sur AppIntents et les CFBundleVersion des extensions
concernent des fichiers hors périmètre et n'ont pas été corrigés ici.

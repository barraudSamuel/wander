---
id: "075"
title: "Valider la migration Mapbox sur le simulateur existant"
status: done
priority: P1
source: review
created: 2026-10-09
completed_at: 2026-10-09T20:43:03+09:00
tags: [mapbox, ios, validation]
---

# Migration Mapbox validée sur le simulateur existant

## Résolution

La compilation, les tests et l’inspection de la carte sont terminés sur
l’iPhone 17 Pro iOS 26.3 existant. Les corrections du renderer, des contrôles,
des indicateurs hors champ et des scénarios UI sont vérifiées.

## Preuves

- [Plan et validation détaillée](../docs/plans/2026-10-09-remplacer-mapkit-par-mapbox.md).
- SDK officiels Maps/CoreMaps 11.32.0, Common 24.32.0 et Turf 4.0.0 résolus ;
  build app et tests réussi.
- Passe 5 : 113 tests natifs, zéro échec, 9,285 secondes.
  Preuve : `/tmp/wander-mapbox-validation-5.log`.
- 26 scénarios UI distincts ont un dernier résultat réussi dans les passes
  ciblées 2 à 6. Agrégation : `/tmp/wander-mapbox-ui-results.json`.
  La passe 5 était à 11/12 UI ; la reprise de trois scénarios dans la passe 6
  passe intégralement en 58,45 secondes. Il ne s’agit pas d’une unique suite
  de 26 tests. Preuve finale : `/tmp/wander-mapbox-validation-6.log`.
- Vingt répétitions du renderer passent après correction de la course pendant
  le traitement GeoJSON : `/tmp/wander-mapbox-fog-fixed.log`.
- Vraies tuiles, couronne H3 et sept cellules centrales masquées,
  désactivation/restauration, retour au premier plan et choix de télémétrie
  inspectés. Capture du profil compact avec attribution au-dessus de la fiche
  et boussole sous le profil : `/tmp/wander-mapbox-evidence/`. Les captures
  `fog-final.png` et `attribution-final.png` confirment le dernier contrôle
  sur la build finale, après retour de l’écran d’accueil.
- La revue de suivi ne retient aucun finding actif. Les fichiers de stockage,
  localisation, migration et profil sont identiques à leur copie initiale.

## Critères d’acceptation

- [x] Résoudre les dépendances officielles et compiler Debug ainsi que les tests.
- [x] Exécuter les suites caméra, viewport, zoom, annotations et masque.
- [x] Vérifier groupes, fiches, événements, appui long, zoom, déplacement et
  retour d’arrière-plan à taille de texte standard.
- [x] Vérifier les vraies tuiles, le brouillard et l’attribution avec les panneaux.
- [x] Corriger les régressions, conserver les données et actualiser les documents.

## Limites

Les parcours utilisent le scénario local et ne prouvent pas de nouveaux
échanges Firebase. Le ressenti haptique et les performances sur appareil
physique restent hors de cette validation. Aucun autre simulateur, nouveau
runtime, test dédié d’accessibilité ou déploiement Firebase n’a été utilisé.

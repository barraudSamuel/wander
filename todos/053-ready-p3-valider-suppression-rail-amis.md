---
id: "053"
title: "Vérifier la carte après suppression du rail d’amis"
status: ready
priority: P3
source: review
created: 2026-09-20
tags: [todo, map]
---

## Constat

La vérification interactive reste à faire : `xcrun simctl list devices booted`
ne retourne aucun appareil démarré. Aucun simulateur n’a été démarré ou créé.
Ce point est une limite de validation, sans défaut fonctionnel identifié.

## Validation attendue

- [ ] Sur l’iPhone 17 démarré par Samuel, vérifier qu’un tirage depuis le bord
  droit ne révèle plus la roue et que le panoramique fonctionne.
- [ ] Vérifier le placement des commandes de carte et l’accès aux amis depuis
  l’onglet Amis et les annotations.

## Référence

[Plan approuvé](../docs/plans/2026-09-20-supprimer-rail-amis.md).

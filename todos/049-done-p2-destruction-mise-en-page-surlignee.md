---
id: "049"
title: Crash Swift à la libération d’une mise en page surlignée
status: done
priority: P2
source: review
created: 2026-09-10
tags: [ios, events, tests]
---

# Destruction de la mise en page surlignée

Le test synchrone de changement de largeur provoquait un arrêt dans le chemin
Swift de destruction isolée, lorsque le label remplaçait son ancienne mise en page.
La pile comporte `MapDetailHighlightedLayout`, `swift_task_deinitOnExecutorImpl`,
`TaskLocal::StopLookupScope` puis malloc. Les parcours UI ne reproduisaient pas
cet arrêt ; il ne fallait pas conclure sur leurs seuls résultats.

Le `nonisolated deinit` vide explicite reprend le correctif déjà présent dans
`MapSocialProximityController`. La mise en page reste possédée et utilisée uniquement
par le label sur l’acteur principal. Aucun changement de runtime ou de configuration.

- [x] Reproduire et identifier la pile d’appel.
- [x] Appliquer le correctif local, retirer les diagnostics temporaires.
- [x] Valider les neuf tests unitaires et le retour après défilement dans
  `/tmp/wander-rounded-highlights-final.xcresult` (`TEST SUCCEEDED`).

Plan : `../docs/plans/2026-09-10-surlignages-arrondis-emojis.md`.
Explication existante : `../docs/solutions/2026-09-02-regrouper-marqueurs-par-proximite.md`.

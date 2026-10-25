---
id: "085"
title: "Faire suivre au toucher la perspective de la fiche"
status: done
priority: P2
source: review
created: 2026-10-25
tags: [todo, map, saved-places]
---

# Constat

Les photos voisines restent maintenant visibles pendant le retournement d'une fiche. À 60°, une fiche de 300 pt laisse exposé un voisin situé à (100, -100) relativement à son ancre. Le test tactile utilisait pourtant encore le rectangle avant rotation ; la priorité de la fiche lui attribuait ce toucher.

# Correction et validation

La silhouette est calculée dans `SavedPlaceCalloutView`, après conversion vers la face réellement tournée et projetée. L'hôte et le résolveur de superposition partagent ce calcul pour le corps arrondi, le texte et la pointe. Les marges minimales restent réservées aux petites photos.

Tests ajoutés : `testTurningCardOnlyInterceptsItsProjectedSilhouette` à 60° et 120°, et `testExposedNeighborReceivesTapWhileSelectedCardTurns` pour l'activation réelle via le store. Ces deux tests passent dans la suite finale de 50 tests natifs sans échec (`/private/tmp/wander-refonte-check4.xcresult`). La revue ciblée `resolution-addendum.json` confirme le correctif source sans nouveau constat. Un test supplémentaire vérifie qu’une photo visible passe avant la marge invisible d’un voisin.

Revue : `/private/tmp/compound-engineering-501/ce-code-review/20261025-121931-2c0b2122/`.
Plan : [Refonte depuis la vidéo](../docs/plans/2026-10-25-refonte-mise-en-avant-adresses.md).

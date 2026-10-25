---
id: "083"
title: "Recalculer les pins quand le viewport change"
status: done
priority: P2
source: review
created: 2026-10-25
tags: [todo, map, saved-places]
---

# Constat

Le nouveau classement dépend du centre utile et du crop visible. Le callback de
viewport annulait les recadrages et actualisait les marqueurs sociaux, mais ne
relançait pas le résolveur des adresses. À caméra constante, des pins pouvaient
rester masqués après expansion et conserver un classement périmé.

# Résolution et validation

`MapWithFogView` appelle `annotationStore.updateSavedPlaceOverlap()` lors du
changement de viewport. Le test de production
`testViewportExpansionRevealsPinsWithoutChangingTheCamera` réduit puis agrandit
le viewport sans changer le drawable ni la caméra ; les visibilités sont vérifiées
immédiatement après le layout.

Les deux tests passent sur le simulateur existant dans
`/private/tmp/wander-pin-motion-viewport.xcresult`, puis dans la suite native
finale de 30 tests sans échec (`/private/tmp/wander-pin-motion-final2.xcresult`).
Validation statique indépendante : revue
`20261025-102747-f728099c` sous `/tmp/compound-engineering-501/ce-code-review/`.

Plan : [Fluidité et priorité des pins](../docs/plans/2026-10-25-fluidite-et-priorite-pins-adresses.md).

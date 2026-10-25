---
id: "084"
title: "Réserver les avatars partiellement visibles"
status: done
priority: P2
source: review
created: 2026-10-25
tags: [todo, map, saved-places]
---

# Constat

Le filtre de projection rejetait les ancres hors du crop avant de mesurer les
marqueurs sociaux. Le bord visible d’un avatar pouvait donc être recouvert par
une adresse pourtant censée respecter sa priorité.

# Résolution et validation

`MapAnnotationStore` rejette les projections invalides et le sentinel Mapbox,
puis réserve les rectangles sociaux qui intersectent le viewport. Les adresses
restent filtrées selon leur ancre. Le test
`testPartiallyVisibleSocialPinStillReservesSpaceInsideTheCrop` place l’ancre sociale
hors crop, vérifie le masquage du favori dans sa silhouette, puis sa réapparition
quand l’avatar est retiré.

Les deux tests passent sur le simulateur existant dans
`/private/tmp/wander-pin-motion-viewport.xcresult`, puis dans la suite native
finale de 30 tests sans échec (`/private/tmp/wander-pin-motion-final2.xcresult`).
Validation statique indépendante : revue
`20261025-102747-f728099c` sous `/tmp/compound-engineering-501/ce-code-review/`.

Plan : [Fluidité et priorité des pins](../docs/plans/2026-10-25-fluidite-et-priorite-pins-adresses.md).

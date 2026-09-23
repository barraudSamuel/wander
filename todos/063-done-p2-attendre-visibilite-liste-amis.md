---
id: "063"
title: "Attendre la visibilité de la liste Amis dans les tests UI"
status: done
priority: P2
source: review
created: 2026-09-22
completed: 2026-09-22
tags: [todo, friends, testing]
---

## Constat

La liste Amis reste montée dans un `ZStack` pour conserver son défilement.
Les assertions héritées du panneau superposé exigeaient sa disparition de
l’arbre XCTest à la fermeture. Un contrôle natif masqué peut toujours exister ;
ces assertions ne décrivaient donc plus le comportement attendu.

## Correction

Dans `MotionDockUITests` et `MapSocialGestureUITests`, les assertions Amis
attendent désormais `(exists && isHittable) == expected` avec un prédicat borné.
Elles couvrent l’ouverture, la fermeture, le changement de liste et les fiches.

## Validation

Relecture locale et `build-for-testing` réussis après correction ; journal
`/tmp/wander-friends-split-build.log`. Pas d’exécution UI : la validation sur
l’iPhone 17 autorisé reste suivie dans `062-ready-p2-valider-amis-sous-carte.md`.

Principe déjà documenté dans
`docs/solutions/2026-09-10-conserver-liste-sous-fiche-carte.md`.

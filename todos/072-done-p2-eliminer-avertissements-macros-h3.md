---
id: "072"
title: Éliminer les avertissements de macros H3 sans masquer les diagnostics
status: done
priority: P2
source: review
created: 2026-10-07
completed_at: 2026-10-07
tags: [todo, h3, build, warnings]
---

# Constat et correction

La première compilation de H3Swift local, sans `-w`, révèle 37 diagnostics
`-Wambiguous-macro` pour `M_PI` et `M_PI_2`. Les fallbacks de
`Vendor/H3Swift/Sources/Ch3/internal/constants.h` précèdent parfois l'import
des mêmes macros du module Darwin. Une revue indépendante a confirmé le
conflit et l'identité des valeurs binary64 des deux écritures.

Le manifeste utilise deux `CSetting.define` avec les littéraux du SDK Darwin.
Les gardes `#ifndef` H3 n'ajoutent alors plus de définition concurrente.
Les 46 sources restent identiques à la révision upstream. Aucun diagnostic
n'est désactivé et aucune option unsafe n'est réintroduite.

## Validation

- Compilation ciblée du vrai `polygon.c` avec les options du build : deux
  avertissements avant les définitions, zéro après.
- Compilation Debug et huit tests intégrés réussis après correction :
  `/private/tmp/wander-h3-fix/final-tests.xcresult` et `final-tests.log`.
- Aucun diagnostic H3 dans ce passage final.
- Les 19 sources C recompilées en Release pour appareil n'émettent aucun
  avertissement H3 ; le build réussit sans signature.
- La vérification complète appareil est consignée dans le
  [plan H3](../docs/plans/2026-10-07-corriger-dependance-h3.md).

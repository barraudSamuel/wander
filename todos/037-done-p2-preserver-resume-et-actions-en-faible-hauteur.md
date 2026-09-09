---
id: "037"
title: "Préserver le résumé et les actions en faible hauteur"
status: done
priority: P2
source: ui-test
created: 2026-09-08
tags: [todo, map, accessibility, swiftui]
---

# Préserver le résumé et les actions en faible hauteur

## Constat et preuves

La première validation du panneau narratif mesure une cible Itinéraire de
42 points. Les colonnes de largeur égale font également déborder le libellé
de participation. En police AX5 et paysage, le résumé n'a que 29 points de
hauteur, insuffisants pour lire une ligne entière.

Résultats : `/tmp/wander-responsive-first.xcresult` et
`/tmp/wander-responsive-final.xcresult` (57/60, dont deux échecs en cascade
après une orientation paysage non rétablie par le test interrompu).

## Acceptation

- [x] Cibles d'au moins 44 points, sur une ligne, sans chevauchement.
- [x] Résumé défilant d'au moins 70 points en AX5 paysage, carte visible.
- [x] Réponses, itinéraire et interactions carte passent les tests de régression.

## Résolution

Les actions gardent leur largeur intrinsèque ; ViewThatFits choisit les
libellés ou les icônes. Les seuils typographiques suivent Dynamic Type et le
panneau conserve davantage de hauteur sur les fenêtres courtes. Le test
réinitialise l'orientation avant chaque parcours.

Voir le [plan approuvé](../docs/plans/2026-09-08-fiches-carte-responsives.md).
Validation : `/tmp/wander-responsive-regression.xcresult`, 55/60 puis
`/tmp/wander-responsive-recheck.xcresult`, 5/5 sur les contrôles restants.
Les trois tests unitaires et les deux tests UI repris passent sans changement
de code. Les nouveaux scénarios responsive passent dès la suite complète.
Capture claire inspectée : `/tmp/wander-fiche-responsive-clair.png`.

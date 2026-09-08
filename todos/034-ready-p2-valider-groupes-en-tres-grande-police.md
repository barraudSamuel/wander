---
id: "034"
title: "Valider les groupes en très grande police"
status: ready
priority: P2
source: ui-test
created: 2026-09-08
tags: [todo, map, accessibility]
---

# Valider les groupes en très grande police

## Constat et preuves

Sur l'iPhone 17 existant, avec `accessibility-extra-extra-extra-large`, le groupe
mixte de cinq membres reste fermé après un toucher correctement centré dans
deux exécutions ciblées. La capture montre la caméra immobile autour du geste.
Le test injecte `(201, 275.667)` et le groupe mesure
`{{177, 224.7}, {48, 102}}` : l'hypothèse d'un toucher à côté n'est pas étayée.

La liste atteint son plafond de 360 points et dépasserait le bord supérieur de
la carte d'environ 95 points dans ce cadrage. `MapSocialProximityController.expand`
recentre sur les mêmes coordonnées sans compenser la hauteur de cette liste.
Ce débordement est mesuré ; la cause exacte de la non-ouverture reste à établir.
Le scénario local réduit aussi l'espace avec son pied de page agrandi.

Résultats : `/tmp/wander-split-large-text-final.xcresult` et
`/tmp/wander-split-large-profile.xcresult`.
Capture : `/tmp/wander-large-text-group-failure.mp4`.
Les 48 tests de sélection/gestes en taille standard passent. Le défilement de la
fiche événement passe aussi à la taille maximale.

## Acceptation

- [x] Reproduire avec le groupe initialement centré en très grande police.
- [ ] Établir la cause de non-ouverture avant de modifier les gestes natifs.
- [x] Rendre toutes les lignes atteignables lorsque la liste dépasse le bord supérieur.
- [ ] Vérifier les groupes mixtes, personnes et événements, puis VoiceOver.

## Périmètre

La refonte des groupes ne fait pas partie du
[plan des fiches partagées](../docs/plans/2026-09-08-fiches-carte-ecran-partage.md).
Son contrôle de contenu peut placer préalablement le groupe plus bas pour rendre
sa liste visible ; cette précondition ne constitue pas une correction de ce constat.

## Mise à jour après correction du viewport

Le [correctif suivant approuvé](../docs/plans/2026-09-08-corriger-crash-metal-et-arrondir-fiches.md)
borne la liste à la fenêtre disponible et translate la caméra à partir du centre
MapKit réellement projeté. Le test de groupe avec huit événements vérifie le
scroll, les cadres visibles et la conservation de sélection.

Le test du profil ne déplace plus préalablement le groupe. Il passe maintenant
en texte maximal avec Réduire les animations actif, depuis le groupe mixte
initialement centré : `/tmp/wander-rounded-map-accessibility.xcresult`, 3/3 avec
les contrôles de fiche événement et de poignée. La non-ouverture initiale n'est
plus reproduite après ce changement ; son enchaînement précis de callbacks dans
l'ancienne version n'a pas été isolé. Le parcours VoiceOver des groupes reste
à valider, d'où le maintien de ce suivi ouvert.

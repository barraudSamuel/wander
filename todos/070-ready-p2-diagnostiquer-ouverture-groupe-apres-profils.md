---
id: "070"
title: "Diagnostiquer l'ouverture d'un groupe après les profils"
status: ready
priority: P2
source: review
created: 2026-09-28
tags: [todo, map, ui-tests]
---

# Diagnostiquer l'ouverture d'un groupe après les profils

## Constat

Dans le scénario local mixte avec 18 événements, après avoir défilé la liste
et ouvert/fermé le profil personnel, un appui sur le groupe compact ne fait pas
apparaître le groupe ouvert attendu. L'échec survient avant de choisir Amina.
La cause précise n'est pas établie ; aucun comportement de groupe n'a été modifié
pendant le retrait de la barre Explorer.

## Preuves

- L'ancien binaire de l'app et le nouveau reproduisent l'échec au même helper
  `openMixedFriend` de `wanderUITests/MapSocialGestureUITests.swift`.
- Le groupe existe, son cadre de 48 × 102 points est entièrement dans le viewport
  carte de 402 × 538,3 points. L'hypothèse d'un tap hors carte est écartée.
- Capture et hiérarchie : `/tmp/wander-group-failure.png` et
  `/tmp/wander-group-failure.txt`.
- Journaux : `/tmp/wander-centered-events-stale-app-tests.log` et
  `/tmp/wander-centered-events-verified-tests.log`.
- Le même parcours avait réussi dans `/tmp/wander-profile-final-validation.log`,
  avant cette session. Ne pas attribuer la cause à la nouvelle géométrie sans
  observation des callbacks de sélection, d'expansion et de désélection.

## Périmètre de validation

Le test de conservation du défilement passe désormais par le profil personnel
puis sa ligne Amina, parcours natif déjà utilisé par un autre test. Toutes ses
assertions de hauteur, position de ligne, observations et taille de carte sont
conservées. Le helper de groupe et les tests consacrés aux groupes restent
inchangés. Cette adaptation ne corrige pas l'échec d'ouverture du groupe.

## Critères d'acceptation

- [ ] Identifier la transition qui empêche ou annule l'expansion après l'appui.
- [ ] Vérifier le parcours initial après défilement et fermetures de profil.
- [ ] Confirmer que les choix de membres et la fermeture du groupe fonctionnent.

Plan de découverte : [Calendrier centré](../docs/plans/2026-09-28-supprimer-navigation-centrer-evenements.md).

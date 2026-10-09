---
id: "074"
title: "Vérifier la disponibilité tactile d'Itinéraire après un profil de groupe"
status: ready
priority: P2
source: review
created: 2026-10-09
tags: [todo, map, ui-tests, profiles]
---

# Vérifier la disponibilité tactile d'Itinéraire après un profil de groupe

## Constat

Sur l'iPhone 17 Pro iOS 26.3 avec Xcode 27, le test existant
`testOwnProfileFromGroupThenFriendProfile` ouvre puis ferme le profil personnel
depuis le groupe, choisit Amina et trouve sa fiche. L'assertion immédiate
`app.buttons["Itinéraire"].isHittable` échoue ensuite. La cause précise reste
inconnue : une attente d'animation insuffisante et un problème d'interaction
réel restent à distinguer.

## Preuves

- `/private/tmp/wander-nearby-final.log` : échec à la ligne 142 du fichier UI.
- `/private/tmp/wander-nearby-baseline-comparison.log` : même échec avec
  `MapWithFogView.swift` et les tests unitaires d'origine au commit
  `9076c1047b9b1c82e8ae3b36312ee9d0706dcb72`.
- Aucun changement d'assertion ou de code de fiche n'a été fait pour masquer
  cet échec. Le correctif des amis proches a été restauré après comparaison.
- Ce cas diffère de `070` : le groupe et la fiche s'ouvrent ici correctement.
- `/private/tmp/wander-nearby-verified.log` : le test
  `testMixedGroupOpensFriendSheetOverMap` échoue aussi sur `Itinéraire.isHittable`,
  ligne 574, après ouverture de la fiche. Ce cas précis n'a pas été comparé
  individuellement à HEAD ; sa ressemblance avec le premier échec ne prouve
  pas qu'il a la même cause ou qu'il est préexistant.

## Critères d'acceptation

- [ ] Observer la géométrie et les animations au moment de l'assertion.
- [ ] Distinguer une attente de test insuffisante d'un bouton réellement inaccessible.
- [ ] Vérifier qu'un appui effectif sur Itinéraire ouvre le choix d'application.

## Périmètre

Suivi distinct de la double sélection d'amis. Une modification du produit
nécessitera son propre plan approuvé.

---
id: "056"
title: "Vérifier le zoom du recentrage sur iPhone 17"
status: ready
priority: P3
source: review
created: 2026-09-20
tags: [todo, map]
---

## Constat

Samuel a invalidé les deux premières tentatives : dézoom/rezoom persistant au
second appui. La révision suivante, explicitement approuvée, remplace le suivi
natif par `MapUserCameraController`. Le recentrage ne lance qu’une région cible ;
le suivi des nouvelles positions ne modifie que le centre. Les gestes et les
cadrages sociaux arrêtent ce suivi.

L’application et les six tests MapKit compilent. Aucun test exécuté : Samuel a
refusé le démarrage du simulateur et choisi de vérifier sur son iPhone.
La disparition du symptôme reste donc à confirmer.

## Validation attendue

- [ ] Depuis un zoom proche et éloigné, appuyer sur le recentrage et constater
  le retour au cadrage initial de 800 mètres autour de la position.
- [ ] Après stabilisation, appuyer de nouveau sans geste intermédiaire :
  aucun dézoom/rezoom ni mouvement si le cadrage est déjà atteint.
- [ ] Appuyer rapidement pendant l’animation : pas de relance du cadrage.
- [ ] Répéter après zoom manuel pendant le suivi et après interruption par
  un panoramique : retour au cadrage normal sans verrouillage du bouton.
- [ ] Confirmer que la position reste suivie après l’animation, à zoom constant.
- [ ] Après sélection d’un ami ou d’un événement, vérifier que la carte ne
  revient pas toute seule sur la position utilisateur ; le bouton doit reprendre le suivi.
- [ ] Exécuter `MapUserCameraControllerTests` lorsque l’environnement le permet.
- [ ] Sans position disponible, vérifier que la demande attend une position.

## Référence

[Plan approuvé](../docs/plans/2026-09-20-recentrage-zoom-carte.md).

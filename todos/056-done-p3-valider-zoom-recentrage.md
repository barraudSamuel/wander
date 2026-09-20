---
id: "056"
title: "Vérifier le zoom du recentrage sur iPhone 17"
status: done
priority: P3
source: review
created: 2026-09-20
completed_at: 2026-09-20T12:43:20+09:00
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
Samuel confirme ensuite « c good mtn » après son test sur iPhone. Le symptôme
est résolu selon ce retour et le finding est clôturé. Les tests automatisés
restent non exécutés ; les scénarios secondaires ne sont pas confirmés un par un.

## Scénarios prévus, détail d’exécution non fourni

- [ ] Depuis un zoom proche et éloigné, appuyer sur le recentrage et constater
  le retour au cadrage initial de 800 mètres autour de la position.
- [x] Résolution du dézoom/rezoom au second appui confirmée par Samuel sur iPhone.
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

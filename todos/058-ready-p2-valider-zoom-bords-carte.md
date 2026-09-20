---
id: "058"
title: Valider le zoom de bord et sa bulle sur iPhone
status: ready
priority: P2
source: review
created: 2026-09-20
tags: [todo, map, gestures]
---

# Valider le zoom de bord et sa bulle sur iPhone

## Constat

Le zoom à un doigt et la bulle sont implémentés et compilés avec leurs tests,
mais l'arbitrage réel des gestes MapKit et le rendu en mouvement ne sont pas
confirmés par une compilation. Aucun simulateur n'était démarré. Aucun appareil
supplémentaire n'a été lancé et aucun test automatisé n'a été exécuté.

## Preuves

- Plan : `docs/plans/2026-09-20-zoom-bords-carte.md`.
- Sources : `wander/MapEdgeZoomController.swift`, `wander/MapEdgeZoomFeedbackView.swift`.
- Tests : `wanderTests/MapEdgeZoomControllerTests.swift` et trois nouveaux parcours
  dans `wanderUITests/MapSocialGestureUITests.swift`.
- Compilation : `/tmp/wander-edge-zoom-final-build.log`.
- Revue : `/tmp/wander-edge-zoom-review/report.md`.

## Critères d'acceptation

- [ ] Glisser verticalement sur chacun des bords : haut pour zoomer, bas pour dézoomer,
  autour du repère social visible le plus central, choisi automatiquement et figé
  pendant le geste ; centre fixe sans cible et inversion immédiate aux limites.
- [ ] La bulle reste attachée au bon bord et suit le doigt sans traverser l'écran
  lors d'un changement de côté ; elle se rétracte au relâchement.
- [ ] Le panoramique horizontal au bord, le panoramique central, le pincement,
  le double toucher, les annotations et l'appui long restent fonctionnels.
- [ ] Vérifier avec une fiche ouverte et après redimensionnement de la carte.
- [ ] Vérifier l'annulation lors de l'ajout d'un second doigt et d'une interruption.
- [ ] Après un zoom de bord, le suivi reste arrêté jusqu'au bouton de recentrage,
  qui restaure le zoom local et le suivi sans oscillation.

## Résolution

En attente d'une validation fonctionnelle sur iPhone ou sur l'iPhone 17 déjà
démarré lors d'une prochaine session. Pas de tests dédiés d'accessibilité.

Le premier essai iPhone de Samuel montre que la bulle se déclenche mais que le
zoom saute puis reste bloqué. Le calcul utilisait les sentinelles -1 de
`MKMapCameraZoomDefault` comme des distances. Correction appliquée à chaque
borne indépendamment, sans changer les gestes ni le dessin de la bulle.

Défaut de calcul reproduit sur macOS avec une plage MapKit réelle puis résolu :
trois échecs avant, huit cas passants après. Journaux
`/tmp/wander-edge-zoom-default-red.log` et `/tmp/wander-edge-zoom-default-green.log`.
Deux tests iOS de régression ajoutés, compilation `TEST BUILD SUCCEEDED` dans
`/tmp/wander-edge-zoom-sentinel-build.log`. Tests iOS non exécutés ; confirmation
du correctif sur iPhone alors attendue.

Samuel confirme ensuite « ça fcntionne » sur son iPhone, puis demande un zoom
légèrement plus rapide. Le fonctionnement général du correctif est donc validé.
Ce retour ne détaille pas chacun des scénarios secondaires ci-dessus.

Après approbation, la sensibilité passe de 180 à 150 points, soit une réponse
20 % plus rapide. Huit cas de calcul passent avec cette valeur, journal
`/tmp/wander-edge-zoom-speed-check.log`. Les tests existants sont ajustés.
Le ressenti du nouveau réglage et les scénarios secondaires restent à confirmer.

## Ciblage automatique ajouté après approbation

Plan `docs/plans/2026-09-20-zoom-cible-centrale.md`. La cible est l'ami,
l'événement ou le groupe réellement visible le plus central. Le profil personnel est désormais éligible, après approbation de Samuel. La coordonnée est figée jusqu'au relâchement ;
aucune fiche n'est ouverte. Sans cible, le centre reste fixe.

Sept tests unitaires supplémentaires compilés, parcours UI des deux bords
adapté. `TEST BUILD SUCCEEDED` dans
`/tmp/wander-edge-zoom-target-final-build.log`. 71 vérifications sur Mac passent,
dont la projection sur carte tournée/inclinée :
`/tmp/wander-edge-zoom-target-probe.log`. Les tests iOS ne sont pas exécutés,
aucun simulateur n'étant démarré.

- [ ] Vérifier la sélection automatique d'un ami, d'un événement et d'un groupe,
  sans ouverture de fiche ni changement de cible pendant le geste.
- [ ] Vérifier le repli sans repère social visible, lorsqu’aucun profil, ami, événement ou groupe n’est visible.
- [ ] Apprécier le dézoom à forte inclinaison : dans le probe macOS, MapKit réduit
  nativement 50° à 35° à certaines distances et l'ancrage dérive d'environ 19 points.
  À 0°/30°, les cas vérifiés restent sous un point de dérive. La précision aux
  échelles continentales/globe n'est pas validée par le probe local.

## Recentrage et haptique approuvés

Le focus déplace désormais le repère au centre visible en 0,18 seconde, tandis
que le zoom suit le doigt. Un impact léger natif est déclenché une seule fois
au début si une cible existe. Un swipe court laisse terminer le recentrage ;
une nouvelle touche ou une annulation l'interrompt. Sans cible, zoom seul.

77 vérifications Mac passent, compilation finale réussie dans
`/tmp/wander-edge-zoom-focus-final-build.log`. Deux tests de cycle de vie ajoutés,
compilés mais non exécutés. Revue et limites dans le plan de ciblage.

- [ ] Sur iPhone, confirmer le centrage fluide dès le début du geste, y compris
  avec une fiche et un swipe court ; vérifier qu'un nouveau geste reprend la main.
- [ ] Confirmer un seul impact léger par prise de focus, sans vibration répétée
  pendant le zoom et sans vibration lorsqu'aucune cible n'est disponible.

## Profil personnel inclus

Le profil personnel utilise désormais le même focus/recentrage/haptique que
les autres repères, sans priorité forcée. Les tests de filtre et de compétition
sont adaptés, ainsi que le parcours UI des deux bords ; un scénario profil seul
est ajouté. Onze vérifications de logique passent sur Mac, compilation app/tests
réussie. Tests iOS non exécutés faute de simulateur démarré.

- [ ] Confirmer sur iPhone le recentrage et l'impact léger sur son propre profil,
  seul puis en présence d'autres repères ; le plus central doit être choisi.

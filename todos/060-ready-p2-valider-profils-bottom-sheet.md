---
id: "060"
title: "Vérifier le rendu et les gestes des profils en bottom sheet"
status: ready
priority: P2
source: review
created: 2026-09-21
tags: [todo, ios, friends]
---

# Vérifier le rendu et les gestes des profils en bottom sheet

## Constat

La nouvelle feuille native est implémentée et compilée. Samuel a explicitement
limité la validation à la compilation. Aucun test n’a été exécuté et aucun
simulateur n’a été démarré. La hauteur mesurée, les gestes natifs et les transitions
ne sont donc pas confirmés en exécution par Codex.

La vidéo fournie par Samuel révèle un défaut P2 : l’ouverture centre d’abord la
carte puis la décale. Après un repli au centrage simple, Samuel approuve la mesure
anticipée : hauteur native préparée avant affichage et un seul mouvement vers le
pin au-dessus de la feuille. Les anciens centrages ami sont désormais délégués à
ce chemin unique. La correction visuelle reste à confirmer.

## Références

- `docs/plans/2026-09-21-profils-amis-bottom-sheet.md`.
- `docs/plans/2026-09-21-cadrage-ami-bottom-sheet.md`.
- `docs/plans/2026-09-21-supprimer-double-cadrage-ami.md`.
- `docs/plans/2026-09-21-cadrage-ami-mesure-anticipee.md` : comportement actuel.
- `wander/MapFriendCameraController.swift` : recentrage de fermeture de 0,22 seconde.
- `wander/FriendProfileSheet.swift` : contenu et hauteur compacte.
- `wander/ContentView.swift` : sélection, ouverture et fermeture avant Itinéraire.
- `wander/DebugSocialMapScenario.swift` : données locales pour les différents états.
- Tests existants adaptés dans `wanderUITests/MapSocialGestureUITests.swift` et
  `wanderUITests/MotionDockUITests.swift`, compilés sans exécution.

## Critères de clôture, lors d’une validation autorisée

- [ ] Vérifier à la taille de texte standard le nom, l’avatar, les deux informations
  de position et le bouton Itinéraire visible au palier compact.
- [ ] Vérifier l’ouverture depuis un pin et la liste Amis, le changement d’ami,
  l’agrandissement natif, la croix et la fermeture par glissement.
- [ ] Confirmer que la carte ne se découpe plus pour un ami et que sa portion
  exposée reste interactive au palier compact.
- [ ] Vérifier une seule trajectoire vers le pin entièrement visible au-dessus
  de la feuille, depuis la liste, un pin, un groupe et un indicateur hors champ.
  Aucun mouvement préalable au milieu de l’écran ou après fin d’ouverture.
- [ ] Vérifier que le palier initial correspond au contenu dès la première image,
  y compris avec un nom long, une position ancienne ou une position indisponible.
- [ ] Vérifier qu’agrandir ou réduire la feuille ne déplace pas la caméra.
- [ ] Après disparition complète de la feuille, vérifier le recentrage rapide
  sur l’ami, avec le même zoom, y compris quand la liste d’événements revient.
- [ ] Vérifier la priorité d’un geste ou d’une nouvelle sélection et l’absence
  de recentrage vers une position devenue indisponible.
- [ ] Vérifier position ancienne, mode fantôme et position indisponible.
- [ ] Confirmer la fermeture avant le choix d’application et la revalidation de
  l’amitié et de la destination, puis la restauration de la liste d’événements.
- [ ] Exécuter les tests UI pertinents sans démarrer ni créer d’autre appareil que
  celui explicitement autorisé et consigner les résultats.

Les avertissements préexistants de versions des extensions restent suivis dans
`054-ready-p2-aligner-build-extensions.md`.

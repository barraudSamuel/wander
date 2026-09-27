---
id: "064"
title: "Restaurer la hauteur du détail après fermeture du panneau"
status: done
priority: P2
source: review
created: 2026-09-26
resolved: 2026-09-26
tags: [todo, events, ios]
---

# Restaurer la hauteur du détail après fermeture du panneau

## Constat

Fermer un détail événement en glissant sa poignée sous le seuil de fermeture
conservait une `eventDetailPosition` proche de zéro. La sélection de l'événement
restant active, la réouverture du panneau réutilisait cette hauteur au lieu des
85 % attendus. Les lectures de correction et adversariale ont identifié le même
cas ; une validation indépendante l'a confirmé dans le code.

## Preuves et résolution

- `wander/MapDetailSplitView.swift` : le glissement écrit la hauteur dans
  `listPosition`, puis `selectListHeight` ferme le panneau sans effacer la
  sélection. Le traitement de fermeture remet maintenant la position du détail
  à `.expanded`, en plus de la hauteur de liste à `.third`.
- Le passage temporaire vers Amis conserve la hauteur manuelle du détail : la
  réinitialisation ne s'applique que lorsque le panneau est fermé.
- `wanderUITests/MapSocialGestureUITests.swift` : le scénario
  `testEventDetailResizesIndependentlyAndReopensExpanded` vérifie aussi la
  fermeture par glissement, la réouverture du même événement et sa hauteur
  agrandie. Il conserve les étapes de fermeture par bouton et de passage par
  Amis.

## Critères de résolution

- [x] Réinitialisation du détail lors de la fermeture des événements.
- [x] Conservation de la hauteur du détail lors du passage par Amis.
- [x] Scénario fonctionnel adapté et compilé.
- [x] App et cibles de tests compilées après correction, sans diagnostic Swift.

## Validation

`xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build-for-testing`

Résultat : `TEST BUILD SUCCEEDED`, code 0, journal
`/tmp/wander-event-cards-final-build.log`. Trois avertissements préexistants
d'extraction AppIntents sans dépendance AppIntents.framework. Aucun test lancé
et aucun comportement en simulateur revendiqué, conformément au
[plan approuvé](../docs/plans/2026-09-26-cartes-evenements-agrandies.md).

## Remplacement du parcours

Le [plan de cartes autonomes](../docs/plans/2026-09-26-cartes-evenements-autonomes.md),
approuvé ensuite le même jour, supprime la fiche et sa position indépendante.
Ce constat reste une trace historique ; aucun parcours de détail ne subsiste.

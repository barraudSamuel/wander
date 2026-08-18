---
id: "014"
title: "Fournir une création d’événement accessible"
status: ready
priority: P1
source: review
created: 2026-08-17
tags: [todo, accessibility, events, map]
---

# Fournir une création d’événement accessible

## Finding

L’appui long sur une zone vide de la carte est le seul parcours de création
d’événement. Le libellé et l’indication VoiceOver rendent l’intention
compréhensible, mais ne fournissent pas une action équivalente fiable aux
personnes qui utilisent VoiceOver, Switch Control ou un autre mode
d’interaction ne permettant pas de choisir puis maintenir un point vide.

Cette lacune est classée P1 parce qu’elle empêche une partie des utilisateurs
d’accéder à une fonction principale. La correction doit faire l’objet d’un
choix produit distinct : le Sprint 3 approuvé interdit explicitement tout
second parcours de création.

## Evidence

- `wander/MapWithFogView.swift` installe un
  `UILongPressGestureRecognizer` comme unique entrée de création.
- `wander/ContentView.swift` n’expose plus de bouton d’ajout ou d’action
  d’accessibilité dédiée.
- `docs/plans/2026-08-17-evenements-multiples-sprint-03-creation-appui-long.md`
  fixe l’appui long comme seul parcours visible et classe toute autre entrée
  hors périmètre.

## Acceptance criteria

- [ ] Une personne utilisant VoiceOver ou Switch Control peut choisir un lieu
      et ouvrir le compositeur sans effectuer l’appui long cartographique.
- [ ] L’alternative reste native, explicite et ne crée pas d’événement à une
      coordonnée inattendue.
- [ ] Le parcours tactile par appui long et les gestes MapKit ne régressent pas.
- [ ] Le comportement est vérifié avec VoiceOver et Switch Control sur le
      simulateur ou un appareil réel.

## Resolution notes

Finding relevé lors de la revue du Sprint 3. Aucun second parcours n’a été
ajouté dans ce sprint afin de respecter son périmètre approuvé.

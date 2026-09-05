---
id: "025"
title: "Valider les gestes de carte sociale après extraction"
status: ready
priority: P2
source: review
created: 2026-09-05
tags: [todo, mapkit, architecture, accessibility, validation]
---

# Valider les gestes de carte sociale après extraction

## Finding

L'extraction du cycle de carte sociale passe ses 25 tests et l'analyse Xcode,
mais les tests du contrôleur n'exécutent pas l'observateur passif de taps du
Coordinator, sa déduplication avec `didSelect`, ni les callbacks produit de
`ContentView`. Une validation dans l'app reste nécessaire avant de clore le
sprint. Aucun défaut de comportement n'a été confirmé par la revue statique.

## Evidence

- [Plan approuvé et résultats exacts](../docs/plans/2026-09-05-architecture-carte-sociale-sprint-01.md).
- `wanderTests/MapSocialProximityControllerTests.swift` utilise un vrai
  `MKMapView` et les vraies vues de groupe, avec des marqueurs individuels de test.
- Le lancement normal sur l'iPhone 17 Pro, iOS 26.3, le 5 septembre 2026,
  s'arrête à l'écran « Continue with Apple » ; la carte n'est pas accessible
  sans connexion du propriétaire.

## Acceptance criteria

- [ ] Après connexion, un tap sur un groupe l'ouvre ; un tap sur un membre
      déclenche une seule action produit, malgré le callback natif qui suit.
- [ ] Un tap sur le fond restaure le membre dans son groupe sans doublon.
- [ ] Double tap, panoramique et zoom restent disponibles, y compris pendant
      un recentrage animé ; les groupes restent indépendants du niveau de zoom.
- [ ] VoiceOver ouvre le groupe, choisit un membre et permet de quitter la
      sélection ; les états sélectionné/ouvert sont annoncés correctement.
- [ ] Mettre à jour le plan et les deux notes Obsidian avec le résultat réel.

## Resolution notes

En attente de la connexion Apple dans le simulateur déjà démarré. Aucun nouvel
appareil ou runtime n'a été créé. Ce suivi appartient au sprint 01, sans
autoriser de sprint supplémentaire.

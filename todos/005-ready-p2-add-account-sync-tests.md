---
id: "005"
title: "Ajouter des tests automatisés de réconciliation de compte"
status: ready
priority: P2
source: review
created: 2026-08-09
tags: [todo, tests, firebase, swiftdata]
---

# Ajouter des tests automatisés de réconciliation de compte

## Finding

La restauration repose sur des invariants critiques — snapshot serveur initial,
union monotone, idempotence et protection des modifications de profil — mais le
projet ne possède pas encore de cible XCTest pour les exercer automatiquement.

## Evidence

- Aucun target `wanderTests` n'est déclaré dans `wander.xcodeproj`.
- La validation actuelle combine compilation, revue statique et futur test
  manuel avec un compte Apple réel.

## Acceptance criteria

- [ ] Ajouter une cible `wanderTests` suivant la convention
  `<TypeName>Tests.swift`.
- [ ] Couvrir union local/distant, doublons, snapshot cache initial, document
  sans `sharedAt`, échec de persistance et changement de compte.
- [ ] Couvrir l'hydratation remote-first et une modification utilisateur faite
  avant la réponse du serveur.
- [ ] Les tests et le build Debug simulateur passent en CI ou en local.

## Resolution notes

Le code Firebase devra être isolé derrière des dépendances injectables ou testé
avec l'émulateur Firestore pour rendre ces scénarios déterministes.

---
id: "027"
title: "Valider le mode fantôme sur iOS et appareils"
status: ready
priority: P2
source: review
created: 2026-09-05
tags: [todo, privacy, testing, location-push, accessibility]
---

# Valider le mode fantôme sur iOS et appareils

## Finding

La compilation et les tests de protocole ne prouvent pas les interactions
CoreLocation, APNs, SwiftUI et VoiceOver. La revue ne confirme pas de défaut
supplémentaire dans ces flux, mais leur exécution reste nécessaire.

## Evidence

- [Plan approuvé et validation exacte](../docs/plans/2026-09-05-mode-fantome.md).
- `wanderTests/GhostModeTests.swift` teste l'état et les politiques.
- `firebase-tests/tests/ghost-mode.test.mjs` teste une fixture du protocole
  sous Firestore local, sans exécuter les publishers Swift.
- Aucun simulateur n'était démarré lors du contrôle. L'autorisation de démarrer
  l'iPhone 17 Pro existant a été demandée conformément à `AGENTS.md`.

## Acceptance criteria

- [ ] Exécuter la suite XCTest sur un simulateur autorisé.
- [ ] Vérifier bouton carte, profil, liste d'amis, fiche déjà ouverte,
  groupes, indicateurs hors champ, itinéraire, Dynamic Type et VoiceOver.
- [ ] Vérifier attente hors ligne, erreur, relance, conflit entre appareils,
  nouvelle mesure de reprise et synchronisation différée des cellules.
- [ ] Couvrir les callbacks natifs : résultat APNs tardif après révocation,
  enregistrement en vol suivi de suppression et ancienne réponse refresh.
- [ ] Rejouer l'activation sur deux comptes et une demande APNs sur appareil.
- [ ] Reporter les preuves dans le plan et les notes Obsidian avant clôture.

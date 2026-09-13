---
title: Vérifier qu’un swipe complet ne répond pas automatiquement
status: done
priority: p2
date: 2026-09-11
---

## Constat de revue

Les tests révélaient les actions avec `swipeLeft()`, sans contrôler explicitement
la réponse après un glissement sur toute la largeur. Le contrat approuvé exige
un toucher sur Participer ou Refuser, même après ce geste.

## Correction

`testGuestSwipeActionsRespondAtEverySize` effectue maintenant un glissement de
95 % à 5 % de la largeur de la ligne, puis vérifie la réponse inchangée, les deux
actions visibles et la sélection conservée avant de toucher une action.
Le parcours couvre les trois hauteurs du panneau et les deux réponses.

Validation ciblée réussie le 2026-09-11 : un test UI, zéro échec, sur l’iPhone 17 déjà démarré. Résultat : `/tmp/wander-native-event-full-swipe.xcresult`.
Plan : `../docs/plans/2026-09-11-actions-evenement-par-balayage.md`.

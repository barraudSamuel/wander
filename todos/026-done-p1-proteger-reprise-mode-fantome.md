---
id: "026"
title: "Protéger la reprise du mode fantôme contre les états anciens"
status: done
priority: P1
source: review
created: 2026-09-05
completed: 2026-09-05
tags: [todo, privacy, concurrency, firestore, ghost-mode]
---

# Protéger la reprise du mode fantôme contre les états anciens

## Finding

La première implémentation pouvait rejouer une désactivation persistée après
l'activation d'un autre appareil. L'identifiant rendait une demande idempotente,
mais aucune révision de départ ne protégeait le choix distant plus récent.
L'acquittement pouvait également perdre le statut mémorisé lors d'une relance.
Enfin, un réabonnement pouvait afficher un ancien snapshot du cache ou traiter
le callback d'un abonnement déjà retiré.

## Resolution

- `GhostModeState.Change` conserve sa révision de départ et les prédécesseurs
  locaux admis. Une révision tierce produit un conflit sans écriture.
- L'intention obsolète est retirée ; un message explique le choix conservé.
  Le partage attend la confirmation serveur.
- Le statut et la révision acquittés sont persistés indépendamment de cette
  confirmation.
- Les lecteurs filtrent les positions antérieures à la reprise et invalident
  chaque ancien callback par l'identité de son abonnement.

## Validation

Les correctifs ont été relus sans nouveau défaut confirmé. La compilation de
l'app, de l'extension et des 21 tests fantôme réussit. Les 49 tests Firestore
passent, dont 11 scénarios fantôme et trois contrôles du conflit/idempotence.
Un harness macOS exécute 13 assertions sur `GhostModeState.swift` de production.

Les tests XCTest et parcours iOS/APNs restent suivis séparément dans
[la validation native](027-ready-p2-valider-mode-fantome-ios.md), sans prétendre
que les fixtures JavaScript exécutent les services Swift.

---
id: "030"
title: "Un lancement normal remet la durée de présence à zéro"
status: ready
priority: P2
source: review
created: 2026-09-05
tags: [todo, privacy, ghost-mode, review]
---

# Un lancement normal remet la durée de présence à zéro

## Finding

Les amis voient une nouvelle durée « au même endroit depuis » chaque fois que l’utilisateur relance Wander, même s’il n’a jamais activé le mode fantôme et n’a pas bougé. L’état commence non confirmé à chaque lancement, puis l’hydratation visible fait passer isLocationSharingAllowed à true; ce nouvel observateur appelle systématiquement clearCurrentSpotPresence via resetSharedPresenceAndRequestLocation et détruit la présence que LocationTracker vient de restaurer. Il faut distinguer une simple hydratation du compte d’une véritable nouvelle reprise après invisibilité.

## Evidence

- Constat #3 de la revue indépendante du 5 septembre 2026.
- [wander/ContentView.swift:248](/Users/samuelbarraud/Documents/code/wander/wander/ContentView.swift:248).
- wander/ContentView.swift:247-248 — if isAllowed { locationTracker.resetSharedPresenceAndRequestLocation()
- wander/LocationTracker.swift:329-332 — func resetSharedPresenceAndRequestLocation() { clearCurrentSpotPresence(); latestProcessedSpotSampleAt = Date()
- wander/LocationTracker.swift:153 restaure la présence au démarrage; 457-460 rétablit currentSpotAnchor, latestProcessedSpotSampleAt et currentSpotEnteredAt depuis la persistance.
- wander/FriendSyncService.swift:1057-1067 recrée GhostModeState lors de l’authentification; GhostModeState.swift:60-61 interdit le partage tant que confirmedEnabled est nil; FriendSyncService.swift:1457-1458 reçoit ensuite le profil serveur visible.
- Cette hydratation produit le passage false→true observé en ContentView.swift:242-249 sans aucune action fantôme. clearCurrentSpotPresence efface l’ancre et le timestamp persisté (LocationTracker.swift:678-688); la prochaine mesure établit enteredAt à son propre timestamp (491-493).

Le harness macOS sur GhostModeState confirme la transition partage interdit -> autorisé à l’hydratation visible sans bascule fantôme. Le reset du tracker est établi par lecture des appels ; le parcours iOS reste à exécuter.

## Suggested response

Séparer la demande d’une mesure fraîche du reset de présence. Lors d’une hydratation normale du même compte, demander la mesure sans effacer l’ancre restaurée; réserver l’effacement à une nouvelle frontière locationSharingResumedAt qui invalide cette présence (ou à un changement effectif de compte). Ne pas utiliser seulement oldValue == false: l’hydratation initiale suit aussi cette transition. Ajouter un scénario relance visible au même endroit qui conserve enteredAt et un scénario véritable sortie fantôme qui le renouvelle.

## Acceptance criteria

- [ ] Une relance normale du même compte visible au même endroit conserve la date de présence restaurée.
- [ ] Une véritable sortie fantôme exige une mesure fraîche et recommence la durée partagée.
- [ ] Un changement de compte ne réutilise pas la présence du compte précédent.

## Resolution notes

Aucun correctif appliqué pendant cette revue. Voir le [plan approuvé](../docs/plans/2026-09-05-mode-fantome.md) et les critères natifs du [todo 027](027-ready-p2-valider-mode-fantome-ios.md).

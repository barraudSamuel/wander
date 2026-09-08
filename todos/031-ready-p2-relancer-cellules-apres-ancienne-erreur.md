---
id: "031"
title: "Une erreur ancienne interrompt la reprise des cellules"
status: ready
priority: P2
source: review
created: 2026-09-05
tags: [todo, privacy, ghost-mode, review]
---

# Une erreur ancienne interrompt la reprise des cellules

## Finding

Les cellules découvertes peuvent rester non synchronisées après la désactivation du mode fantôme si un upload antérieur termine en erreur après la confirmation de reprise. Lors du nouveau profil, uploadMissingExplorationCellsIfNeeded est encore bloqué par isUploadingExploration ; le callback tardif remet ce drapeau à false, puis quitte parce que sa révision est ancienne, sans effectuer la reprise qu’il vient de débloquer. Si le téléphone reste immobile et connecté sans autre événement de profil, de métadonnées ou de scène, les cellules restent en attente jusqu’à une action ultérieure.

## Evidence

- Constat #4 de la revue indépendante du 5 septembre 2026.
- [wander/FriendSyncService.swift:1730](/Users/samuelbarraud/Documents/code/wander/wander/FriendSyncService.swift:1730).
- wander/FriendSyncService.swift:1730 — self.ghostModeState.confirmedRevision == expectedRevision else { return }
- wander/FriendSyncService.swift:1684 — !isUploadingExploration else {
- wander/FriendSyncService.swift:1726 — self.isUploadingExploration = false
- wander/FriendSyncService.swift:1741-1742 — if self.ghostModeState.confirmedRevision != expectedRevision { self.uploadMissingExplorationCellsIfNeeded() } ; this recovery exists for a false transaction result but not for an error.
- wander/FriendSyncService.swift:293-316 — receiveGhostModeProfile triggers uploadMissingExplorationCellsIfNeeded after accepting the new profile; syncDiscoveredCells, addDiscoveredCells, own-exploration snapshots and scene activation are the other retry triggers inspected.

Scénario établi statiquement dans les callbacks Swift et validé indépendamment. Les fixtures JS de protocole ne couvrent pas cet ordonnancement natif ; un test déterministe reste nécessaire.

## Suggested response

Après avoir libéré isUploadingExploration, traiter aussi le changement de révision dans le chemin d’erreur : appeler uploadMissingExplorationCellsIfNeeded lorsque la révision actuelle diffère de expectedRevision, puis quitter sans afficher l’ancienne erreur. Le guard de cette méthode conserve la suspension tant que le partage reste interdit. Ajouter un test qui livre le profil de reprise avant l’erreur de l’ancien upload et vérifie qu’un upload sous la nouvelle révision démarre sans nouvel événement externe.

## Acceptance criteria

- [ ] Le profil de reprise reçu pendant un upload antérieur ne perd pas sa demande de synchronisation.
- [ ] Une erreur tardive de cet upload déclenche un nouvel envoi sous la révision courante, sans événement externe supplémentaire.
- [ ] Le partage interdit et le changement de compte continuent à bloquer les envois.

## Resolution notes

Aucun correctif appliqué pendant cette revue. Voir le [plan approuvé](../docs/plans/2026-09-05-mode-fantome.md) et les critères natifs du [todo 027](027-ready-p2-valider-mode-fantome-ios.md).

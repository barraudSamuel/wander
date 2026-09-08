---
id: "029"
title: "Une activation annulée annonce à tort une position masquée"
status: ready
priority: P2
source: review
created: 2026-09-05
tags: [todo, privacy, ghost-mode, review]
---

# Une activation annulée annonce à tort une position masquée

## Finding

Un utilisateur visible peut activer puis désactiver le fantôme hors ligne avant que l’activation soit confirmée. Le profil affiche alors « Ta position reste masquée jusqu’à la confirmation », alors que la première transaction n’a jamais supprimé sa dernière position distante. Le texte utilise le choix pending, pas l’état de confidentialité confirmé, et rassure donc à tort sur une position que les amis peuvent toujours consulter.

## Evidence

- Constat #2 de la revue indépendante du 5 septembre 2026.
- [wander/ContentView.swift:1462](/Users/samuelbarraud/Documents/code/wander/wander/ContentView.swift:1462).
- wander/ContentView.swift:1460-1462 — service.isGhostModeEnabled ? "En attente de confirmation. Ta dernière position partagée peut rester visible jusque-là." : "Ta position reste masquée jusqu’à la confirmation."
- wander/GhostModeState.swift:56-57 — var isEnabled: Bool { pendingChange?.enabled ?? confirmedEnabled ?? rememberedEnabled }
- wander/ContentView.swift:1977-1980 laisse le toggle disponible pendant un pending; FriendSyncService.swift:231-240 accepte une nouvelle demande lorsque pendingChange est présent, sans exiger que l’activation antérieure ait été confirmée.
- Scénario: compte visible avec une position distante, perte réseau, activation pending puis désactivation pending. Les transactions hors ligne n’ont pas supprimé la position; pendingChange.enabled vaut false, isGhostModePending reste true et le texte de la ligne 1462 affirme néanmoins qu’elle est masquée.

Le harness macOS compile le vrai GhostModeState et confirme la combinaison pending désactivé / serveur visible. Il ne valide pas le rendu SwiftUI. Preuves : /private/tmp/wander-ghost-second-review-aoo_241p/reproduce-ux-state.swift et /private/tmp/wander-ghost-second-review-aoo_241p/reproduce-ux-state.log.

## Suggested response

Rendre la copie pending indépendante de la seule cible du toggle: ne promettre une position masquée que si une activation est effectivement confirmée. Pour une annulation avant confirmation ou un état distant encore inconnu, indiquer que les nouveaux envois sont suspendus sur cet appareil et que la dernière position partagée peut rester visible. Tester visible→activation pending→désactivation pending sans confirmation, ainsi que la désactivation d’un fantôme réellement confirmé.

## Acceptance criteria

- [ ] Visible -> activation en attente -> désactivation en attente sans connexion ne promet jamais que la dernière position est masquée.
- [ ] La désactivation en attente d’un fantôme confirmé affiche une information cohérente avec cet état confirmé.
- [ ] Le rendu SwiftUI des deux parcours est vérifié.

## Resolution notes

Aucun correctif appliqué pendant cette revue. Voir le [plan approuvé](../docs/plans/2026-09-05-mode-fantome.md) et les critères natifs du [todo 027](027-ready-p2-valider-mode-fantome-ios.md).

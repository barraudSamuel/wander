---
id: "028"
title: "Une transaction republie après l’arrêt du suivi"
status: ready
priority: P1
source: review
created: 2026-09-05
tags: [todo, privacy, ghost-mode, review]
---

# Une transaction republie après l’arrêt du suivi

## Finding

Quand l’utilisateur désactive « Enregistrer mes déplacements » pendant une publication, sa position peut réapparaître chez ses amis après sa suppression. La nouvelle transaction peut terminer après deleteOwnLocation : elle ne lit que le profil, tandis que stopSharingLocation ne change ni le statut fantôme ni sa révision. Son guard reste donc valide et son setData recrée locations/{uid}, même si le suivi est maintenant arrêté ; aucune nouvelle mesure ni ancienne application n’est nécessaire pour produire cette course.

## Evidence

- Constat #1 de la revue indépendante du 5 septembre 2026.
- [wander/FriendSyncService.swift:2373](/Users/samuelbarraud/Documents/code/wander/wander/FriendSyncService.swift:2373).
- wander/FriendSyncService.swift:2373 — transaction.setData(locationData, forDocument: locationReference) ; wander/FriendSyncService.swift:2402 — db.collection("locations").document(userID).delete { [weak self] error in
- wander/ContentView.swift:227 — .onChange(of: locationTracker.trackingEnabled, initial: true) { _, isEnabled in ; wander/ContentView.swift:229 — friendSyncService.stopSharingLocation()
- wander/FriendSyncService.swift:938-944 — stopSharingLocation clears latestLocationForSharing/lastLocationPush, sets shouldDeleteLocationWhenAuthenticated, then invokes deleteOwnLocation without changing the profile revision.
- wander/FriendSyncService.swift:2364 — let profile = try transaction.getDocument(profileReference)
- wander/FriendSyncService.swift:2366-2372 — The transactional guards check LocationSharingPolicy with the captured revision and sample freshness; neither tracking consent nor shouldDeleteLocationWhenAuthenticated is checked, and the location document is not read.

Course reproduite sur Firestore local avec un propriétaire et un ami fictifs : suppression confirmée, puis commit de la transaction retenue et lecture ami réussie. Le script ne pilote pas le service Swift. Preuves : /private/tmp/wander-ghost-second-review-aoo_241p/reproduce-stop-race.cjs et /private/tmp/wander-ghost-second-review-aoo_241p/reproduce-stop-race.log.

## Suggested response

Donner aux transactions de publication et à stopSharingLocation un ordre commun par compte : invalider immédiatement les nouveaux envois, puis exécuter la suppression finale seulement après l’achèvement des transactions de position déjà engagées, en respectant la génération de compte et une éventuelle reprise plus récente. Un simple guard local avant setData ne couvre pas un commit déjà envoyé. Ajouter un test qui retient une transaction après sa lecture du profil, arrête le suivi, puis libère la transaction et vérifie l’absence finale du document.

## Acceptance criteria

- [ ] Une publication retenue après lecture du profil, suivie de l’arrêt du suivi puis libérée, laisse le document de position absent.
- [ ] Aucun ami accepté ne peut lire une position recréée par cette ancienne publication.
- [ ] Une reprise plus récente et un changement de compte ne sont pas annulés par une suppression tardive.

## Resolution notes

Aucun correctif appliqué pendant cette revue. Voir le [plan approuvé](../docs/plans/2026-09-05-mode-fantome.md) et les critères natifs du [todo 027](027-ready-p2-valider-mode-fantome-ios.md).

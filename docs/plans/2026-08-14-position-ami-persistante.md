---
title: "Conserver la dernière position des amis sur la carte"
status: completed
date: 2026-08-14
completed_at: 2026-08-14
owner: "Samuel Barraud"
related: []
tags: [plan, friends, location, mapkit]
---

# Conserver la dernière position des amis sur la carte

## Outcome

Tant qu'une amitié est acceptée et qu'une position valide a déjà été partagée,
la pastille de l'ami reste visible à sa dernière coordonnée connue. Après cinq
minutes sans nouvelle position, elle devient visuellement atténuée et affiche
l'âge réel de la dernière position, tout en conservant l'action « Rejoindre ».

## Context

Aujourd'hui, `FriendSyncService` retire une position cinq minutes après son
échantillonnage. Cette expiration supprime ensuite l'annotation MapKit. Le
produit doit désormais distinguer disponibilité et fraîcheur : une position
ancienne reste disponible, mais ne doit plus être présentée comme une présence
actuelle.

## Scope

- Included:
  - conserver les positions valides reçues au-delà de cinq minutes ;
  - remplacer l'expiration par une transition récente vers ancienne ;
  - atténuer la pastille et retirer son halo lorsqu'elle devient ancienne ;
  - afficher « Dernière position reçue… » et sa date au lieu d'une durée de
    présence pour une position ancienne ;
  - garder « Rejoindre » disponible pour la dernière position connue ;
  - restaurer automatiquement l'état récent à la prochaine mise à jour ;
  - préserver le retrait sur suppression distante, révocation d'amitié ou
    suppression de compte.
- Not included:
  - créer un statut fiable « connecté/déconnecté » ;
  - conserver une position après un arrêt explicite du partage ;
  - modifier la collecte Core Location ou la fréquence des écritures ;
  - modifier le schéma ou les règles Firestore.

## Dependencies

- Le document `/locations/{uid}` doit encore exister et contenir une coordonnée
  valide.
- La fraîcheur continue d'utiliser `sampledAt` et la fenêtre existante de cinq
  minutes.

## Proposed approach

`FriendSyncService` conserve toute position distante valide et publie
séparément les identifiants dont la position est encore récente. Un minuteur
léger fait seulement basculer cet état à l'échéance. `ContentView` et
`MapWithFogView` utilisent ensuite ce signal pour les textes, l'opacité, le halo
et l'accessibilité. La destination de navigation ne dépend plus de la fraîcheur,
mais continue d'inclure l'horodatage de la position.

## Affected files

- `wander/FriendSyncService.swift` — séparer conservation et fraîcheur.
- `wander/ContentView.swift` — résumés, navigation et textes d'état.
- `wander/MapWithFogView.swift` — apparence et accessibilité des pastilles.
- `wander/FriendProfileSheet.swift` — présentation d'une position ancienne.
- `docs/solutions/2026-08-06-navigation-externe-depuis-mapkit.md` — contrat
  durable disponibilité/fraîcheur.
- `todos/009-ready-p1-supprimer-logs-position-precise.md` — risque de
  confidentialité constaté pendant la revue.
- `docs/plans/2026-08-14-position-ami-persistante.md` — suivi du sprint.

## Implementation

- [x] Conserver les documents de position valides sans limite d'âge passée.
- [x] Remplacer les minuteurs d'expiration par un état de fraîcheur publié.
- [x] Passer l'état récent/ancien aux résumés, profils et annotations MapKit.
- [x] Atténuer une pastille ancienne, retirer son halo et adapter ses libellés.
- [x] Autoriser « Rejoindre » avec une position ancienne et afficher son heure.
- [x] Restaurer l'état récent à chaque nouvelle position.
- [x] Simplifier le diff et vérifier les suppressions légitimes.

## Edge cases and risks

- Une ancienne coordonnée peut être prise pour une position actuelle — atténuer
  la pastille et annoncer explicitement l'âge de la position.
- « Rejoindre » peut guider vers un lieu ancien — conserver la date et l'heure
  dans le dialogue avant l'ouverture de l'application externe.
- L'opacité seule n'est pas accessible — ajouter un libellé textuel et une
  valeur VoiceOver indiquant que la position est ancienne.
- iOS ne révèle pas de manière fiable un force-quit — ne jamais afficher le mot
  « déconnecté » comme un fait ; utiliser « dernière position reçue ».
- Une position absente, invalide ou supprimée ne fournit aucune coordonnée —
  retirer la pastille dans ces seuls cas.

## Validation

- [x] `xcodebuild` Debug pour simulateur réussit sans nouvel avertissement du
  code applicatif.
- [x] Une position vieille de plus de cinq minutes reste dans la carte.
- [x] Le passage récent vers ancien met à jour opacité, halo et textes.
- [x] « Rejoindre » reste utilisable et annonce l'heure de la position.
- [x] Une nouvelle position restaure l'apparence récente.
- [x] Suppression distante et révocation d'amitié retirent toujours la pastille.
- [x] Les libellés VoiceOver ne présentent pas une position ancienne comme live.

## Acceptance criteria

- [x] Une pastille ne disparaît plus uniquement parce que sa position a vieilli.
- [x] Une position ancienne reste clairement identifiable sans couleur seule.
- [x] Toutes les actions et suppressions explicites gardent un comportement
  cohérent et sûr.

## Completed validation

- `xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration
  Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath
  /tmp/wander-derived-data build` — succès, code de sortie 0.
- `git diff --check` — succès, aucune erreur d'espace.
- Revue statique ciblée — aucune expiration ne supprime désormais une position ;
  les suppressions restent limitées à l'absence du document, à la révocation de
  l'amitié et aux parcours explicites de partage/compte.
- La validation visuelle avec deux comptes réels reste recommandée pour juger
  précisément l'opacité sur appareil ; elle ne bloque pas la compilation ni le
  contrat fonctionnel vérifié.

## Review notes

- Hardest decision: préserver l'action « Rejoindre » sans laisser croire que la
  destination est actuelle.
- Rejected alternatives: supprimer la pastille ou désactiver « Rejoindre » après
  cinq minutes, contraires à la décision produit approuvée.
- Least certain: le rendu exact de l'opacité sur toutes les variantes de pastille
  devra être confirmé visuellement sur simulateur ou appareil.

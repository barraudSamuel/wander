---
title: "Création d’événement — feuille partielle et pin temporaire"
status: in_progress
date: 2026-08-20
approved_at: "2026-08-20T17:20:33+09:00"
started_at: "2026-08-20T17:20:33+09:00"
zoom_revision_approved_at: "2026-08-20T17:30:52+09:00"
owner: "Samuel Barraud"
related:
  - "2026-08-17-evenements-multiples-sprint-03-creation-appui-long.md"
tags: [plan, ios, swiftui, mapkit, ux, events]
---

# Création d’événement — feuille partielle et pin temporaire

## Outcome

Après un appui long sur la carte, ouvrir le compositeur de création à environ
deux tiers de la hauteur, afficher un pin temporaire au point choisi et recadrer
ce point dans la partie supérieure encore visible. La carte reste manipulable
derrière la feuille partielle, tandis que l’édition d’un événement existant
conserve sa présentation en grand format.

## Context

- Le flux actuel transmet correctement la coordonnée depuis
  `MapWithFogView` vers `ContentView`, mais force la feuille sur `.large`.
- La coordonnée en attente alimente uniquement le formulaire et ne produit
  aucune annotation cartographique.
- Le formulaire existant, le géocodage inverse et le contrat persistant ne
  changent pas.
- Plan d’origine :
  [Sprint 3 — Création par appui long](2026-08-17-evenements-multiples-sprint-03-creation-appui-long.md).

## Scope

- Included:
  - detent initial de création à `0,66`, extensible à `.large` ;
  - interaction avec la carte autorisée au detent partiel ;
  - pin MapKit temporaire, distinct des événements publiés ;
  - translation unique du centre pour placer le point dans la zone non
    couverte, sans modifier le zoom, l’orientation ou l’inclinaison ;
  - suppression du pin à la fermeture ou après publication ;
  - prévention d’une nouvelle création et de son haptique pendant l’ouverture ;
  - documentation UX et technique correspondante.
- Not included:
  - modification du point depuis le formulaire ;
  - recherche de lieu ou mini-carte dans le compositeur ;
  - changement du formulaire, du modèle, de Firestore ou des notifications ;
  - modification de la présentation d’édition.

## Proposed approach

`ContentView` conserve la coordonnée brouillon comme source de vérité et
configure la feuille selon le mode création ou édition. `MapWithFogView`
synchronise une annotation temporaire avec cette coordonnée et désactive son
reconnaisseur d’appui long tant que le compositeur est présenté. Il projette le
centre de la zone supérieure visible en coordonnée MapKit, puis translate le
centre actuel de l’écart nécessaire pour y placer le pin. Cette opération
conserve le zoom, l’orientation et l’inclinaison. Elle n’est rejouée que lorsque
la coordonnée brouillon change afin de ne pas annuler les manipulations
ultérieures de la carte.

## Affected files

- `wander/ContentView.swift` — mode de présentation et état transmis à la carte.
- `wander/MapWithFogView.swift` — pin temporaire, garde du geste et recadrage.
- `docs/plans/2026-08-20-creation-evenement-feuille-partielle-pin.md` — suivi.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md` — parcours utilisateur.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md` — orchestration SwiftUI/MapKit.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md` — suivi uniquement si la validation interactive reste ouverte.

## Implementation

- [x] Configurer le compositeur de création avec les detents `0,66` et `.large`.
- [x] Autoriser l’interaction de fond seulement au detent de création.
- [x] Conserver l’édition exclusivement en `.large`.
- [x] Transmettre la coordonnée brouillon et l’état d’activation du geste.
- [x] Ajouter, déplacer et retirer le pin temporaire de manière incrémentale.
- [x] Remplacer le cadrage à 800 mètres par une translation conservant le zoom.
- [x] Désactiver l’appui long et son haptique pendant la présentation.
- [ ] Mettre à jour la documentation Obsidian concernée.
- [x] Simplifier et revoir les changements.

## Edge cases and risks

- Une mise à jour SwiftUI pourrait rejouer le cadrage et contrer le panoramique ;
  la dernière coordonnée cadrée est mémorisée dans le coordinateur.
- Une interaction derrière la feuille pourrait déclencher un second haptique ;
  le reconnaisseur complet est désactivé tant que le compositeur est visible.
- Le pin temporaire pourrait être confondu avec un événement publié ; il utilise
  une vue marker native et un libellé d’accessibilité spécifique.
- La projection écran/carte peut varier avec la rotation et l’inclinaison ; la
  translation part de la caméra courante afin de préserver ces deux propriétés,
  puis le résultat est vérifié sur l’iPhone 17 existant.

## Validation

- [x] Le build Debug réussit sans nouvelle erreur ni nouvel avertissement Swift.
- [ ] Un appui long valide ouvre une seule feuille à environ deux tiers.
- [ ] Le pin correspond au point choisi et reste visible dans la partie haute.
- [ ] La carte peut être déplacée derrière la feuille partielle.
- [ ] Aucun second appui long ni haptique ne se déclenche pendant la feuille.
- [ ] L’agrandissement et la réduction de la feuille restent natifs et fluides.
- [ ] Fermer la feuille retire le pin provisoire.
- [ ] Publier remplace le pin provisoire par le marqueur normal.
- [ ] Modifier un événement existant ouvre toujours une feuille `.large`.
- [ ] Les modes clair/sombre, Dynamic Type et VoiceOver sont vérifiés.
- [ ] Les notes Obsidian sont vérifiées en vue de lecture.
- [x] Aucun Git, déploiement Firebase ou changement distant n’est exécuté.

## Acceptance criteria

- La création commence sur un detent partiel montrant clairement la carte.
- Le lieu choisi est matérialisé et repositionné sans modifier la coordonnée
  publiée ni le niveau de zoom.
- Le formulaire et l’édition existants conservent leur comportement.
- La carte reste manipulable sans permettre une création concurrente.

## Review notes

- Hardest decision: permettre l’interaction cartographique derrière une feuille
  modale sans rendre le geste de création réentrant.
- Rejected alternatives: `.medium` seul, car sa disponibilité dépend de la
  hauteur compacte ; mini-carte dans le formulaire, contraire au parcours
  approuvé ; feuille non interactive, qui limite le contrôle de la carte.
- Least certain: perception exacte du ratio `0,66` et du padding sur l’appareil,
  à confirmer par validation interactive.

## Work log

### Résultats au 20 août 2026

- Build : `xcodebuild -quiet -project wander.xcodeproj -scheme wander
  -configuration Debug -destination 'generic/platform=iOS Simulator'
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build` réussit
  avec le code de sortie `0`. Aucun avertissement Swift n’est émis. Le seul
  avertissement concerne la divergence préexistante de `CFBundleVersion` entre
  l’app (`20`) et la Share Extension (`15`), déjà documentée dans des plans
  antérieurs.
- Revue structurelle : le detent est réinitialisé explicitement selon le mode,
  la coordonnée brouillon reste la source de vérité, la translation est gardée
  par `lastFocusedDraftCoordinate`, et le reconnaisseur complet est désactivé
  tant que la feuille est présentée. Aucun changement du formulaire, du modèle
  ou du backend n’a été introduit. Aucun finding supplémentaire n’est ouvert.
- Révision de conservation du zoom : le cadrage à 800 mètres et
  `setVisibleMapRect` ont été retirés. La caméra courante est translatée avec
  `setCenter` à partir de la projection écran/carte du centre de la zone
  supérieure. Le build Debug suivant réussit avec le code de sortie `0` et
  n’émet aucun avertissement.
- Simulator : l’iPhone 17 `6F13855D-10B8-45AF-9205-17C8393379E3` existe mais
  son état est `Shutdown`. Les règles du dépôt interdisent de le démarrer sans
  autorisation explicite ; toute la validation interactive reste donc ouverte.
- Obsidian : le vault demandé est lisible mais se trouve hors des racines
  d’écriture de cette session. Les mises à jour encore requises sont
  `Documentation UX.md`, section « Sorties prévues » (feuille initiale à 66 %,
  pin temporaire, recadrage et interaction de fond), et
  `Documentation technique.md`, section « Événements et participations »
  (état brouillon SwiftUI, annotation MapKit incrémentale, garde de cadrage et
  désactivation du reconnaisseur). `Backlog features.md` doit recevoir un suivi
  « validation interactive en attente » seulement si cette validation ne peut
  pas être close. Aucune validation Obsidian n’est revendiquée.

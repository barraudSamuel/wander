---
title: "Recentrer et sélectionner les événements depuis le bord"
status: in_progress
date: 2026-08-26
owner: "Samuel Barraud"
related:
  - "2026-08-18-indicateurs-amis-hors-champ.md"
tags: [plan, map, events]
---

# Recentrer et sélectionner les événements depuis le bord

## Outcome

Un toucher sur l’indicateur de bord d’un événement recentre la carte,
sélectionne son pin et ouvre sa fiche, comme le recentrage et la tooltip d’un
ami.

## Context

Les indicateurs d’amis répondent au toucher, mais le badge UIKit contenu dans
le contrôle d’un événement peut recevoir le toucher à la place de son contrôle
parent.

Le comportement a d’abord été approuvé comme un recentrage seul, puis révisé à
la demande de Samuel. Le présent comportement, recentrage et sélection comme
pour les amis, a été approuvé explicitement le 2026-08-26.

## Scope

- Included:
  - transmettre le toucher du badge d’événement à son contrôle parent ;
  - recentrer la carte au toucher d’un indicateur d’événement ;
  - sélectionner le pin dès qu’il est visible et ouvrir sa fiche ;
  - conserver le toucher direct d’un pin visible et le comportement des amis.
- Not included:
  - modification visuelle des indicateurs ;
  - changement du rail d’amis ;
  - modification des événements, de Firebase ou des règles Firestore.

## Proposed approach

Rendre la vue décorative du badge non interactive, comme l’image utilisée par
l’indicateur d’ami, afin que `touchUpInside` soit reçu par le `UIControl`
parent. Séparer ensuite le recentrage de bord de la sélection MapKit : le
bouton d’événement applique la même région que l’indicateur d’ami, puis
sélectionne l’annotation dès que sa vue MapKit est disponible.

## Affected files

- `wander/MapOffscreenIndicatorView.swift` — laisser le contrôle parent gérer
  le toucher du badge d’événement.
- `wander/MapWithFogView.swift` — recentrer puis sélectionner l’événement
  depuis l’indicateur de bord.
- `docs/plans/2026-08-26-recentrer-evenements-bord.md` — suivi du travail et de
  sa validation.
- `docs/solutions/2026-08-26-controle-parent-indicateur-mapkit.md` — consigner
  la cause réutilisable après validation.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md`
  — préciser le comportement et son statut.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`
  — documenter le recentrage et l’ouverture de fiche.

## Implementation

- [x] Rendre le contenu visuel du badge non interactif.
- [x] Recentrer puis sélectionner l’événement depuis l’indicateur de bord.
- [x] Vérifier le diff et simplifier le changement.
- [x] Compiler le projet sans nouvel avertissement.
- [ ] Valider le toucher sur l’iPhone 17 Simulator déjà démarré, s’il est
  disponible.
- [x] Mettre à jour les documents de référence et consigner la solution.

## Edge cases and risks

- Le changement pourrait désactiver le toucher direct d’un pin visible — seule
  la sous-vue décorative est rendue non interactive ; l’annotation MapKit reste
  interactive.
- Une sélection demandée pendant que le pin est encore hors écran peut être
  ignorée par MapKit — conserver la demande jusqu’à ce que la vue d’annotation
  soit disponible, puis la consommer une seule fois.
- Le vault Obsidian peut ne pas être accessible en écriture depuis la session —
  dans ce cas, les sections restantes seront signalées exactement.

## Validation

- [x] Le build Debug générique réussit sans nouvel avertissement lié au
  changement. L’avertissement préexistant de `CFBundleVersion` reste présent.
- [ ] Un toucher sur chaque bord recentre l’événement.
- [ ] La fiche s’ouvre une seule fois depuis l’indicateur de bord.
- [ ] Un toucher direct sur le pin visible continue d’ouvrir la fiche.
- [ ] Les indicateurs d’amis et le rail d’amis restent inchangés.
- [x] Les notes Obsidian modifiées sont vérifiées en mode Lecture.

## Review notes

- Hardest decision: sélectionner seulement après la disponibilité de la vue
  MapKit, tout en conservant le recentrage animé.
- Rejected alternatives: ouvrir directement la fiche sans sélectionner le pin,
  car cela désynchroniserait l’état MapKit ; modifier le rail d’amis, car son
  comportement fonctionne déjà.
- Least certain: validation tactile et visuelle sur le simulateur disponible.

## Validation notes

- `git diff --check` réussit le 2026-08-26.
- `xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration
  Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath
  /tmp/wander-derived-data -disableAutomaticPackageResolution build` réussit
  le 2026-08-26.
- Seul avertissement : divergence préexistante de `CFBundleVersion` entre
  l’extension (`15`) et l’app (`26`).
- Les deux iPhone 17 disponibles, l’iPhone 17 Pro et l’iPhone 17 Pro Max sont
  tous `Shutdown`. Aucun simulateur n’a été démarré.
- `Backlog features.md` et `Documentation UX.md` ont été vérifiés dans Obsidian
  en mode Aperçu/Lecture : propriétés, wikiliens, liste de backlog, paragraphe
  de comportement et point UX à valider sont rendus correctement.
- Le build a été relancé après l’ajout de la sélection différée et réussit avec
  le même unique avertissement préexistant de `CFBundleVersion`.
- L’iPhone 17 a ensuite été démarré par le propriétaire. Le build a été installé
  et Wander se lance correctement sur iOS 26.3, mais le simulateur affiche
  l’écran d’authentification « Bienvenue sur Wander » sans session Apple. La
  carte et le toucher d’événement ne peuvent pas être validés sans connexion.
- Après la révision du comportement, `Backlog features.md` et
  `Documentation UX.md` ont de nouveau été vérifiés en mode Aperçu/Lecture :
  frontmatters, wikiliens et textes « recentre, sélectionne et ouvre la fiche »
  sont rendus correctement.

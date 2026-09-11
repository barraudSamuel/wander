---
id: "048"
title: "Rétablir la police emoji du simulateur existant"
status: ready
priority: P2
source: review
created: 2026-09-10
tags: [todo, ios, simulator, design]
---

# Police emoji manquante dans le runtime du simulateur

## Constat

Sur l’iPhone 17 existant, les emojis de la nouvelle liste et ceux de la fiche
UIKit existante sont remplacés par des caractères manquants. Le redémarrage
du même appareil ne change pas le résultat. Le rendu coloré des emojis n’est
donc pas validé dans cet environnement ; les huit parcours UI fonctionnels passent.

## Preuves

- Plan : `../docs/plans/2026-09-10-liste-evenements-sociale-emojis.md`.
- Capture liste : `/tmp/wander-social-list-after-reboot.png`.
- Comparaison avec la fiche existante : `/tmp/wander-existing-detail-emoji.png`.
- Diagnostic temporaire `/tmp/wander-emoji-diagnostic.swift`, compilé pour iOS
  Simulator et exécuté avec `simctl spawn` sur le même iPhone 17.
- Core Text signale « Requested font not available » pour
  `System/Library/Fonts/Core/AppleColorEmoji.ttc` du runtime iOS 26.3
  (`iOS_23D8133`), puis « fallback to LastResort » pour `.AppleColorEmojiUI`
  et `AppleColorEmoji`. Les caractères Unicode transmis sont corrects.

## Suite

- [ ] Rétablir la police système de cet environnement, ou vérifier le rendu sur
  un appareil disposant de cette police, puis confirmer les emojis de la liste
  et de la fiche existante.

Aucune modification du runtime, copie de police, installation ou création de
simulateur n’a été effectuée. Le projet ne contourne pas le défaut du runtime
avec une police embarquée ou un comportement propre au simulateur.

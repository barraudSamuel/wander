---
id: "042"
title: "Préserver les confirmations du profil lors du routage"
status: done
priority: P2
source: code-review
created: 2026-09-10
completed_at: 2026-09-10
tags: [todo, ios, navigation, account]
---

# Préserver le profil pendant une confirmation

## Constat

Le dock remplace son contenu. Une notification sélectionnant Amis ou Explorer
pouvait donc retirer `ProfilePanelView`, propriétaire de la confirmation Apple,
de son état d'erreur et de ses actions de compte.

## Résolution

- Le profil expose l'état actif de ses confirmations, erreurs et opérations.
- La sélection du dock et le routage des notifications attendent la fin du flux.
- Le routage asynchrone d'une sortie vérifie encore cet état après le chargement.
- La notification reste en attente et est réexaminée à la fin du flux de compte.
- Relecture ciblée indépendante : les deux chemins de notification sont protégés.

Les notifications réelles concurrentes à une confirmation Apple nécessitent une
validation avec compte connecté ; voir `044-ready-p2-valider-dock-sur-compte-reel.md`.

Plan : [panneaux Amis et Profil](../docs/plans/2026-09-10-panneaux-amis-profil.md).

---
title: "Alertes de confirmation du compte"
status: completed
date: 2026-08-09
owner: "Samuel Barraud"
related:
  - "./2026-08-09-deconnexion-suppression-compte.md"
tags: [plan, authentication, swiftui, interface]
---

# Alertes de confirmation du compte

## Outcome

La déconnexion et la suppression du compte utilisent des alertes iOS natives
au lieu de menus de confirmation présentés depuis le bas de l'écran.

## Scope

- Remplacer les deux `confirmationDialog` de `ProfileView` par des `alert`.
- Conserver les textes, les rôles des actions et les comportements existants.
- Conserver la feuille de réauthentification Apple, qui héberge le bouton Apple.

## Affected files

- `wander/ContentView.swift`

## Implementation

- [x] Remplacer l'alerte de déconnexion.
- [x] Remplacer l'alerte de suppression.
- [x] Compiler et relire le diff.

## Risks and validation

- Vérifier que les boutons d'annulation et de confirmation gardent leurs rôles.
- Vérifier que l'action destructive ouvre toujours la feuille Apple.
- Compiler le schéma Debug pour le simulateur iOS.

Validation effectuée : build Debug iOS Simulator réussi et `git diff --check`
sans erreur.

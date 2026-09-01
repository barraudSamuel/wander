---
id: "020"
title: "Refactoriser progressivement la codebase Wander"
status: ready
priority: P2
source: product-owner
created: 2026-09-01
tags: [todo, architecture, refactor, swift]
---

# Refactoriser progressivement la codebase Wander

## Finding

Plusieurs fichiers concentrent aujourd’hui trop de responsabilités UI, état,
synchronisation et orchestration. Cette taille rend les changements difficiles
à relire, augmente le temps de compilation SwiftUI et favorise les régressions
transversales. Le chantier doit être mené par incréments fonctionnels vérifiables,
et non comme une réécriture globale.

## Evidence

- `wander/MapWithFogView.swift` dépasse 2 600 lignes et regroupe rendu MapKit,
  annotations, interactions, caméra et adaptation SwiftUI.
- `wander/ContentView.swift` dépasse 2 300 lignes et orchestre plusieurs domaines
  produit, feuilles, alertes, listeners et cycles de vie.
- `wander/FriendSyncService.swift` dépasse 2 300 lignes et concentre profil,
  amitiés, localisation, exploration et suppression de compte.
- Un ajout récent dans `ContentView` a déclenché un timeout de type-check SwiftUI,
  corrigé seulement après extraction de frontières `some View` plus petites.

## Acceptance criteria

- [ ] Cartographier les responsabilités, dépendances et flux d’état avant de
      déplacer du code.
- [ ] Définir des incréments indépendants, chacun avec comportement et fichiers
      explicitement bornés.
- [ ] Extraire les responsabilités cohérentes sans modifier simultanément leurs
      contrats produit ou Firestore.
- [ ] Réduire significativement la taille et la complexité des trois fichiers
      principaux sans créer de nouveaux objets « fourre-tout ».
- [ ] Préserver le langage visuel iOS natif, l’accessibilité et les parcours
      existants.
- [ ] Pour chaque incrément, réussir le parsing Swift, le build, l’analyse Xcode
      et les validations interactives concernées.
- [ ] Documenter l’architecture cible et les décisions réutilisables.

## Resolution notes

Dette explicitement demandée par le propriétaire le 2026-09-01. Aucun refactor
n’est inclus dans la création de ce finding.

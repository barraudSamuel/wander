---
title: "Recentrer pendant la fermeture de la fiche ami par la croix"
status: proposed
date: 2026-09-21
approved_at: 2026-09-21
approval: "je valide après le plan présenté dans la conversation"
revision: "Extension de coordination du viewport proposée après revue, non approuvée"
---

# Résultat attendu

La croix lance la fermeture et le recentrage dans la même action. La carte
n’attend plus le callback de fin de fermeture. Aucun second recentrage ensuite.
Le glissement, le cadrage à l’ouverture et la priorité des gestes sont conservés.

## Cause et approche

La vidéo de Samuel montre la fermeture suivie du recentrage. Actuellement,
`FriendProfileSheet` appelle `dismiss()` depuis la croix, puis `ContentView`
émet la demande de caméra dans le callback `onDismiss` de la feuille.
Les tests existants vérifient la position finale, pas le début du mouvement.

Faire remonter l’action de la croix à la vue propriétaire de la sélection.
Cette action efface la sélection et émet immédiatement la demande de recentrage.
Elle consomme aussi l’identifiant du profil présenté, afin que `onDismiss`
ne puisse pas émettre une deuxième demande. Le callback final conserve son rôle
pour le glissement et l’ouverture des options d’itinéraire.

## Périmètre et fichiers

- `wander/FriendProfileSheet.swift` : action explicite de fermeture par la croix.
- `wander/ContentView.swift` : fermeture et demande de caméra groupées.
- `wander/DebugSocialMapScenario.swift` : même chemin dans le scénario local.
- `wander/MapFriendCameraController.swift`, `wander/MapWithFogView.swift` :
  actualiser uniquement le commentaire décrivant la demande de fermeture.
- `wanderUITests/MapSocialGestureUITests.swift` : examiner la couverture existante.
- `wanderTests/FriendProfilePresentationTests.swift` : adapter le nom du callback.
- Ce plan et `todos/060-ready-p2-valider-profils-bottom-sheet.md`.
- Vault `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Backlog features.md`, `Documentation UX.md`, `Documentation technique.md`.

## Exécution et validation

- [x] Appliquer la fermeture simultanée et supprimer le deuxième déclenchement.
- [x] Examiner le glissement, une nouvelle sélection et les options d’itinéraire.
- [ ] Simplifier et revoir le diff ciblé.
- [x] Compiler l’application et les cibles de tests sans exécution.
- [x] Actualiser le suivi et les trois notes Obsidian avec `updated`.

Validation limitée à la compilation, conformément à la demande persistante de
Samuel. Aucun simulateur démarré, aucun test exécuté. Pas de mutation Git.
Le risque principal est un deuxième mouvement au callback final, ou un recentrage
qui remplace une sélection plus récente. Le timing visuel reste à confirmer sur
appareil ; ne pas présenter une compilation comme une preuve de synchronisation.

## Notes de réalisation

- `onClose` distingue maintenant l’action de la croix du callback natif
  `onDismiss`, jusqu’au contenu partagé et au scénario de test.
- La demande réutilise le contrôleur existant et ses gardes. Aucun timer, délai,
  état supplémentaire ou nouveau mécanisme d’animation.
- Les tests UI de fermeture après redimensionnement, de glissement et d’itinéraire
  sont conservés. Pas d’ajout d’assertion chronométrée via `XCUIElement.tap()` :
  la synchronisation XCTest avec l’inactivité ne prouverait pas le départ pendant
  la fermeture. Le suivi décrit le contrôle visuel restant. Le test natif de
  présentation est adapté au nom `onClose`, sans prétendre tester ce timing.
- Trois revues de simplification réalisées : aucun problème de réutilisation
  ou d’efficacité ; clarification du nom du callback appliquée après la revue
  de qualité.

## Revue et extension proposée

La compilation finale réussit (`TEST BUILD SUCCEEDED`,
`/tmp/wander-close-recenter-final-build.log`). Aucun test exécuté. Deux avis
App Intents d’extraction ignorée, aucun avertissement Swift. `git diff --check`
réussit. Revue `ce-code-review` complète, résultat `Ready with fixes`, rapport
`/tmp/compound-engineering-501/ce-code-review/20260921-122227-4ebf30df/review.json`.

Défaut P2 non corrigé : lorsque la liste Événements était déployée, fermer la
fiche la restaure et anime la zone visible de carte pendant 0,25 seconde.
`onViewportChange` annule alors le recentrage immédiat déjà consommé.
Le correctif simple n’est donc pas terminé pour ce parcours. Ne pas committer
cette version comme correction complète. Les changements actuels sont conservés.

Extension proposée, en attente d’approbation :

1. Faire fournir par `MapDetailSplitView` la géométrie finale attendue de la carte,
   distincte de sa géométrie animée, à travers `MapViewportView`.
2. Démarrer le recentrage unique vers le centre de cette zone sûre finale.
3. Laisser cette animation traverser uniquement la restauration automatique de
   ce viewport ; une nouvelle destination de layout, rotation, nouvelle sélection
   ou geste manuel reste prioritaire et annule le mouvement.
4. Compiler des tests de géométrie finale et d’annulation, ainsi que les tests
   existants. Aucun deuxième recentrage de secours dans `onDismiss`.
5. Revoir et compiler l’ensemble, actualiser ce suivi et les mêmes notes Obsidian.

Fichiers supplémentaires : `wander/MapDetailSplitView.swift`,
`wander/MapViewportView.swift`, tests de viewport et de caméra.
`wander/MapFriendCameraController.swift` et `wander/MapWithFogView.swift` passent
d’un simple commentaire à une adaptation fonctionnelle. Cette coordination
supplémentaire requiert l’approbation explicite avant modification.

---
title: Recentrage magnétique uniquement en zoom avant
status: in_progress
date: 2026-09-26
owner: Samuel
tags: [plan, map]
---

# Recentrage magnétique uniquement en zoom avant

## Résultat et accord

Plan approuvé par Samuel dans la conversation le 26 septembre 2026.
Conserver le recentrage en zoom avant et supprimer l'attraction et le retour
haptique de focus en zoom arrière. Lors d'une inversion vers le dézoom, arrêter
le centrage en cours et conserver le centre actuellement affiché, sans saut.
Le rail de 44 points et l'accélération ×1 à ×3 restent identiques.

## Fichiers concernés

- `wander/MapEdgeZoomController.swift` : sélectionner la cible au passage au zoom avant, arrêter le focus au passage au zoom arrière et figer une nouvelle caméra de référence à chaque changement de sens.
- `wanderTests/MapEdgeZoomControllerTests.swift` : adapter les tests de focus et couvrir dézoom, inversion pendant/après focus, retour au zoom avant, geste nul et annulation.
- `docs/plans/2026-09-26-recentrage-zoom-avant.md` : suivi.
- `todos/` : validation et constats de revue.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md` : section Zoom à un doigt au bord de la carte et propriété updated.

## Mise en œuvre

- [x] Démarrer une session neutre sans cible ni vibration.
- [x] Déduire le sens du déplacement incrémental, pas de la translation totale.
- [x] Acquérir une cible en entrant en zoom avant seulement, et la conserver pendant cette phase.
- [x] Au passage en dézoom, arrêter le display link et repartir de la caméra affichée sans cible ni déplacement différé de la phase précédente.
- [x] Adapter et compléter les tests.
- [x] Compiler, simplifier, relire et mettre à jour la note UX.
- [ ] Exécuter les tests et vérifier le geste sur l'iPhone 17 déjà ouvert.

## Risques et validation

L'inversion pendant les 0,18 seconde du focus est le cas sensible : aucune
ancienne animation ne doit continuer à déplacer la caméra après le dézoom.
Un déplacement nul ne doit pas acquérir de cible. Une nouvelle phase de zoom
avant peut choisir la cible visible la plus centrale depuis le cadrage courant.
Vérifier aussi les limites de zoom, les gestes rapides, l'annulation et la fin.

Aucun simulateur démarré lors de l'inspection. Compiler avec `build-for-testing`
sans démarrer de simulateur. Tests ajoutés avant le code ; leur exécution reste
conditionnée à un iPhone 17 ouvert. Ne pas revendiquer une phase rouge exécutée.

## Revue et résultat

- Première compilation : `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution -skipPackageUpdates build-for-testing`, résultat **TEST BUILD SUCCEEDED**.
- Compilation finale après simplification : **TEST BUILD SUCCEEDED**, même commande, journal `/private/tmp/wander-zoom-in-focus-final.log`.
- `git diff --check` : succès.
- Tests modifiés avant le code, compilés mais non exécutés. Aucun simulateur démarré selon `xcrun simctl list devices booted`.
- Revue `ce-simplify-code` : trois passes. Suppression du calcul de coordonnées en dézoom, aucun autre constat retenu.
- `ce-test-xcode` : XcodeBuildMCP absent ; compilation via xcodebuild, sans démarrer de simulateur.
- `ce-code-review` : même limitation de périmètre que pour le rail accéléré, l'outil inclut les modifications préexistantes sans filtre par fichier. Relecture de correction effectuée sur les seules différences de cette intervention, comparées aux copies antérieures dans `/private/tmp/wander-zoom-direction-before.swift` et `/private/tmp/wander-zoom-direction-tests-before.swift`. Aucun défaut retenu ; vérifier le rendu au doigt.
- Couverture ajoutée : dézoom sans recherche de cible ni vibration, centre conservé, inversion avant la première image / pendant / après focus, sens incrémental, reprise du zoom avant et annulation.
- Note Obsidian `Documentation UX.md` mise à jour, propriété `updated` comprise.
- Avertissements d'extraction AppIntents déjà présents, hors périmètre.
- Validation restante : `todos/068-ready-p2-valider-recentrage-zoom-avant.md`.
- Aucune commande Git modificatrice ni changement aux autres travaux.
- Pas de nouvelle note de solution : changement de comportement local, sans nouvelle leçon d'architecture vérifiée.

Le statut reste `in_progress` jusqu'à l'exécution des tests et à la validation du geste.

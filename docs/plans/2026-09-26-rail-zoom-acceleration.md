---
title: Rail de zoom élargi et accélération progressive
status: in_progress
date: 2026-09-26
owner: Samuel
tags: [plan, map]
---

# Rail de zoom élargi et accélération progressive

## Résultat et périmètre

Plan approuvé explicitement dans la conversation le 26 septembre 2026.
Élargir la zone tactile des deux bords de 28 à 44 points et amplifier le zoom
selon la vitesse verticale du doigt. Le gain augmente progressivement de ×1
à ×3, puis revient immédiatement à ×1 quand le geste ralentit.
Le dessin du retour de bord et le mécanisme de centrage restent hors périmètre.

## Fichiers concernés

- `wander/MapEdgeZoomController.swift` : largeur et pondération des déplacements.
- `wanderTests/MapEdgeZoomControllerTests.swift` : limites et accélération.
- `docs/plans/2026-09-26-rail-zoom-acceleration.md` : suivi et validation.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md` : section Zoom à un doigt au bord de la carte et propriété updated.
- `todos/` : éventuels constats de revue et validation restante.

## Mise en œuvre

- [x] Passer les deux zones tactiles à 44 points.
- [x] Pondérer chaque déplacement par la vitesse verticale instantanée : ×1 jusqu'à 100 pt/s, interpolation douce jusqu'à ×3 à 900 pt/s.
- [x] Ajouter les tests des vitesses lente et rapide, des directions, du plafond et des valeurs invalides. Le ralentissement du geste réel reste dans la validation manuelle.
- [x] Compiler, relire, mettre à jour la documentation UX.
- [ ] Vérifier le geste sur l'iPhone 17 déjà démarré.

## Risques et validation

Une zone plus large peut intercepter un panoramique vertical près du bord.
La détection d'intention verticale et l'exclusion des contrôles restent actives.
Le gain s'applique à chaque déplacement avant accumulation pour conserver la
vitesse de chaque échantillon pendant le centrage animé. Les limites de caméra
existantes restent applicables. Aucun déplacement supplémentaire après relâchement.

Compiler l'application et les tests avec les dépendances locales existantes.
Exécuter les tests MapEdgeZoomControllerTests et vérifier lent/rapide, haut/bas,
ralentissement, panoramique hors rail et zoom aux limites sur l'iPhone 17.
Aucun simulateur démarré lors de l'inspection : ne pas en démarrer sans accord.
Les tests seront ajoutés mais aucune phase rouge exécutée n'est revendiquée.

## Revue

À compléter après vérification. Préserver les modifications préexistantes et
n'exécuter aucune commande Git modificatrice. Pas de nouvelle note de solution
pour ce réglage local, sauf découverte réutilisable.


## Résultats de validation

- Première compilation `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution -skipPackageUpdates build-for-testing` : **TEST BUILD SUCCEEDED**.
- Compilation finale après simplification : **TEST BUILD SUCCEEDED**, même commande, journal `/private/tmp/wander-zoom-build-final.log`.
- `git diff --check` : succès.
- Tests ajoutés et compilés, mais non exécutés : aucun simulateur démarré.
- Note Obsidian `Documentation UX.md` mise à jour, propriété `updated` comprise.
- `ce-simplify-code` : trois revues, une assertion redondante supprimée ; aucun autre changement proposé.
- `ce-test-xcode` : XcodeBuildMCP absent. Compilation effectuée via xcodebuild ; gestes non vérifiés.
- `ce-code-review` : le calcul automatique de périmètre inclut les nombreux changements préexistants et ne propose pas de filtre par fichier. Relecture manuelle du diff limité aux deux fichiers de zoom, sans élargir cette tâche aux autres travaux. Aucun défaut de correction retenu.
- Risque restant : calibrage au doigt et panoramique près des zones élargies. Suivi dans `todos/067-ready-p2-valider-rail-zoom-accelere.md`.
- Avertissements hors périmètre observés : extraction AppIntents ignorée faute de dépendance, CFBundleVersion des extensions 15 et 27 contre 47 pour l'app.
- Pas de nouvelle note de solution : réglage local sans apprentissage réutilisable.

Le plan reste `in_progress` jusqu'à l'exécution des tests et la validation du geste.

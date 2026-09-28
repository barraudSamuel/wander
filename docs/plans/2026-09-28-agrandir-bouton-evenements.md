---
title: Agrandir le bouton événements
status: completed
completed_at: 2026-09-28
date: 2026-09-28
---

# Résultat et périmètre

Plan présenté dans la conversation puis explicitement approuvé par Samuel.
Passer le bouton événements de 44 à 56 points, en conservant son centrage en
bas et son action. Le bouton profil reste à 44 points.

## Fichiers concernés

- `wander/MapImageButton.swift` : taille configurable avec défaut à 44 points.
- `wander/NativeMapTabView.swift` : taille événements unique à 56 points pour
  l'image SwiftUI et les contraintes du contrôleur UIKit.
- `wanderUITests/MotionDockUITests.swift` : attentes événements à 56 points.
- Le présent plan.
- Dans le coffre Obsidian
  `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Documentation UX.md`, `Documentation technique.md`, `Backlog features.md`,
  `00 - Wander.md`. Mettre à jour les dimensions actuelles et `updated`, en
  conservant les wikiliens et les validations historiques.

## Mise en œuvre

- [x] Adapter le composant et les contraintes, préserver les marges calculées.
- [x] Adapter les assertions existantes sans ajouter de tests dédiés.
- [x] Simplifier et relire le changement limité à cet agrandissement.
- [x] Compiler et vérifier les scénarios ciblés sur l'iPhone 17 déjà démarré.
- [x] Mettre à jour les quatre notes et consigner la validation.

## Risques et validation

Risque principal : une image plus grande que son hôte UIKit, ou la dernière
ligne masquée. La même dimension doit alimenter les deux couches ; la marge
inférieure utilise déjà la position réelle du bouton.

Exécuter les tests existants de centrage après bascules, toucher aux bords et
dégagement de la dernière ligne. Vérifier une capture à taille de texte normale.
La modification est visuelle : pas de cycle rouge préalable, les assertions
existantes seront adaptées puis exécutées sur le résultat.
Ne pas créer de simulateur ni de tests d'accessibilité dédiés.

## Contraintes et suivi

Exécution locale native. Les changements de la tâche précédente sont conservés.
Les règles du dépôt interdisent toute commande Git mutante, donc aucune création
de branche ni aucun commit. Elles priment sur les recommandations du skill.
Pas de modification des groupes de carte, de Firebase ou des parcours.
Pas de nouvelle note de solution attendue pour ce réglage courant.

## Validation et revue

- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'platform=iOS Simulator,id=6F13855D-10B8-45AF-9205-17C8393379E3' -parallel-testing-enabled NO -disableAutomaticPackageResolution` avec `test` et les trois sélecteurs ci-dessous : **TEST SUCCEEDED**, 3 tests, 0 échec.
- Sélecteurs `-only-testing:wanderUITests/MotionDockUITests/` :
  `testEventsButtonStaysCenteredAcrossRepeatedListToggles`,
  `testImageButtonEdgesOpenTheirSheets`,
  `testBottomOfEventsListClearsEventsButton`.
- Journal : `/private/tmp/wander-events-56-tests.log`.
- Résultats : `/Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx/Logs/Test/Test-wander-2026.09.28_11-11-04-+0900.xcresult`.
- Capture inspectée : `/private/tmp/wander-events-56-evidence/89F34064-7C5B-40B3-9764-54D9D2F4F682.png`.
  Calendrier agrandi centré, dernière carte entièrement au-dessus.
- Les deux sources et les tests ont été recompilés ; les binaires app et tests
  sont datés de 11:11:23. Aucun contournement du cache nécessaire cette fois.
- XcodeBuildMCP absent : validation CLI équivalente appliquée selon AGENTS.md.
  App et schéma `wander`, iPhone 17 iOS 26.3 existant, scénario DEBUG local.
  Aucun échange Firebase réel ni test d'accessibilité dédié.
- Avertissements préexistants d'extraction AppIntents sans framework ; aucun
  nouveau diagnostic Swift dans les sources modifiées.
- `git diff --check` réussi. Pas de commande de lint dédiée configurée.
- Simplification : trois relectures réutilisation, qualité et efficacité,
  aucune correction nécessaire. Revue de code légère du delta de taille :
  aucune anomalie ; reçu dans
  `/private/tmp/compound-engineering-501/ce-code-review/events-56-20260928/review.json`.
- Décision principale : un diamètre configurable conserve le profil à 44 points
  et partage les 56 points entre SwiftUI et UIKit. Modifier la constante commune
  aurait aussi agrandi le profil. Les marges existantes suivent le cadre réel,
  donc aucune nouvelle règle de padding n'est nécessaire.
- Les quatre notes Obsidian sont mises à jour avec `updated` et wikiliens
  conservés. Les validations à 44 points sont identifiées comme historiques.
- Aucun nouveau constat à ouvrir ni apprentissage réutilisable à consigner.
  Les changements de navigation et le suivi 070 de la tâche précédente restent
  distincts de cet agrandissement.

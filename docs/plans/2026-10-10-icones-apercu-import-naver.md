---
title: Icônes de catégorie dans l’aperçu Naver
date: 2026-10-10
status: completed
approved_at: 2026-10-10
completed_at: 2026-10-10T14:14:00+09:00
---

# Résultat et périmètre

Plan proposé dans le chat et approuvé par Samuel avec « je valide ».
Ajouter une petite icône système à gauche de chaque adresse de l'aperçu :
tasse pour `CAFE`, couverts pour `DINING`, repère pour les autres catégories
ou une catégorie absente. Utiliser le champ `mcid` déjà fourni par Naver.
La catégorie reste transitoire, sans modification du stockage ni de la carte.

## Fichiers affectés

- `wander/NaverListImport.swift` : décodage optionnel et choix du symbole.
- `wander/NaverImportView.swift` : icône à gauche du contenu existant.
- `wander/DebugSocialMapScenario.swift` : catégorie de la fixture café.
- `wanderTests/NaverListImportTests.swift`, `wanderUITests/NaverImportUITests.swift`.
- Ce plan ; `todos/` si la revue révèle un constat.
- Coffre Obsidian `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Backlog features.md`, `Documentation UX.md`, `Documentation technique.md`.

## Travail et validation

- [x] Décoder la catégorie et ajouter l'icône native alignée à gauche.
- [x] Adapter les tests et fixtures existants : café, restaurant, autre, absent.
- [x] Compiler et tester sur l'iPhone 17 Pro déjà démarré ; inspecter une capture.
- [x] Simplifier, relire et mettre à jour les trois notes Obsidian.

Changement visuel limité : pas de nouveau test dédié d'accessibilité et pas de
cycle rouge préalable pour cette présentation réversible. Les tests existants
du lecteur et du parcours sont renforcés, puis exécutés après modification.
Une catégorie inconnue ne doit jamais bloquer l'import. Aucun Git mutateur,
commit, dépendance ou transfert de code externe. Les modifications existantes
de l'import Naver restent présentes, cette unité les complète en place.

## Revue et documentation

Trois lectures de simplification réalisées : aucun changement utile en réemploi
ou efficacité ; indentation du contenu de la ligne corrigée après la lecture
qualité. Pas de nouvelle abstraction. Les trois notes Obsidian prévues ont été
mises à jour avec `updated` et leurs wikilinks conservés, sans ouvrir Obsidian.
Pas de leçon nouvelle nécessitant une note `docs/solutions/`.

XcodeBuildMCP indisponible dans cette session : validation équivalente avec
`xcodebuild` et capture XCTest, conformément au fallback autorisé par AGENTS.md.

Revue `ce-code-review` terminée sur le seul incrément des icônes, sans constat.
Reçu : `/tmp/compound-engineering-501/ce-code-review/20261010-141311-c6903bd6/review.json`.

## Validation finale

- Projet `wander.xcodeproj`, scheme `wander`, Debug, iPhone 17 Pro déjà démarré
  `C0DADF07-7E14-4D5E-AE4B-B17844A9C454`.
- Compilation et 9 tests réussis : les 8 `NaverListImportTests` et
  `NaverImportUITests.testSingleFieldPreviewSaveAndReimportWithoutDuplicates`.
- Sélection via `xcodebuild test -only-testing:wanderTests/NaverListImportTests`
  et `-only-testing:wanderUITests/NaverImportUITests/testSingleFieldPreviewSaveAndReimportWithoutDuplicates`,
  avec `-disableAutomaticPackageResolution -parallel-testing-enabled NO`.
- Journal : `/tmp/wander-naver-icons-tests.log`.
- Résultat :
  `/Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx/Logs/Test/Test-wander-2026.10.10_14-11-54-+0900.xcresult`.
- Capture inspectée : `/tmp/wander-naver-icon-screens/9D17436D-EA5B-4D71-860E-FC91E09003B5.png`.
  La tasse est visible à gauche du nom, les deux avertissements restent lisibles.
- Aucun échec ni nouvelle erreur Swift ; avertissements AppIntents préexistants
  sur les cibles sans framework AppIntents. `git diff --check` réussi.
- Aucun contrôle humain requis. Résultat du périmètre : PASS.

Limite : rendu simulateur inspecté pour café ; restaurant et valeur inconnue
vérifiés par les tests du mapping. Pas de nouvelle validation dédiée sur appareil
physique ni de tests d'accessibilité, conformément au périmètre approuvé.

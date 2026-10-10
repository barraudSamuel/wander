---
title: Placer les attributions Mapbox en bas
status: completed
completed_at: 2026-10-10T10:31:16+09:00
date: 2026-10-10
approved_at: 2026-10-10
---

# Placer les attributions Mapbox en bas

Samuel a approuvé le plan présenté dans la conversation. Placer le logo dans
le coin inférieur gauche et le bouton d'attribution dans le coin inférieur
droit, au-dessus de la zone du geste d'accueil. Les remonter au-dessus d'une
fiche native ouverte. Garder le cadrage, les gestes et les commandes actuels.

## Fichiers

- `wander/MapViewportView.swift`
- `wanderTests/MapViewportViewTests.swift`
- `docs/README.md`
- Ce plan.
- Coffre `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Documentation technique.md` et `Documentation UX.md`, avec `updated` actualisé.

## Étapes et validation

- [x] Plan approuvé.
- [x] Séparer le bas des attributions de la marge réservée aux commandes.
- [x] Adapter les tests de géométrie et de fiches natives.
- [x] Compiler, exécuter les tests et inspecter le simulateur existant.
- [x] Revue et documentation.

Risque principal : chevauchement avec les commandes ou une fiche. Vérifier la
zone système, l'absence de déplacement caméra et le rétablissement après
fermeture d'une fiche. Utiliser seulement l'iPhone 17 Pro déjà démarré.
Pas de tests d'accessibilité dédiés, de changement Git, commit ou publication.
Le code préexistant des thèmes est conservé.

## Résultat et validation

Le calcul conserve les limites supérieures et latérales du viewport, mais
prend sa limite basse dans la zone sûre système. La marge caméra des commandes
n'influence plus le bas des attributions. L'ancien décalage horizontal du ⓘ
est supprimé. Le suivi des fiches reste identique.

Compilation Debug réussie et 7 tests `MapViewportViewTests` réussis, dont
fiches synthétiques, présentation native, changements de hauteur et fermeture.
Les tests existants sont adaptés au nouveau comportement ; les assertions
sur les frames natives vérifient que les attributions restent à 8 points du
bas système malgré la marge caméra. Validation après modification, pas de
preuve rouge préalable pour cet ajustement visuel local.

Projet `wander.xcodeproj`, scheme `wander`, iPhone 17 Pro existant
`C0DADF07-7E14-4D5E-AE4B-B17844A9C454`, iOS 26.3. Deux états inspectés :
carte seule et fiche profil ouverte. Logo à gauche, ⓘ à droite, remonte au-dessus
de la fiche. Aucun changement caméra constaté. Résultat **PASS**.
Vérifications humaines requises : 0. Échecs restants : 0.
Aucun nouveau warning Swift ; avertissements AppIntents préexistants.
Les logs stdout/stderr du scénario sont vides, zéro erreur capturée.
Les tests utilisent des données synthétiques, sans validation Firebase réelle.

### Commandes

```bash
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'platform=iOS Simulator,id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' -derivedDataPath /Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx -disableAutomaticPackageResolution -skipPackageUpdates -parallel-testing-enabled NO build-for-testing
```

Tests : mêmes options communes, `test-without-building`,
`-only-testing:wanderTests/MapViewportViewTests`,
`-resultBundlePath /tmp/wander-bottom-attribution-validation.xcresult`.
XcodeBuildMCP indisponible : Xcode CLI et contrôle UI natif, comme autorisé.

Logs `/tmp/wander-bottom-attribution-build.log`,
`/tmp/wander-bottom-attribution-validation.log`,
`/tmp/wander-bottom-attribution-stdout.log`,
`/tmp/wander-bottom-attribution-stderr.log`.
Captures dans `/Users/samuelbarraud/.codex/visualizations/2026/10/09/01a122f5-3532-75a0-8b63-e8eca3c2d3a5/bottom-attribution/` :
`01-map.png`, `02-profile.png`.

## Revue et documentation

Trois passes `ce-simplify-code` terminées, aucun constat.
`ce-code-review` lite terminé sans constat :
/tmp/compound-engineering-501/ce-code-review/20261010-bottom-attribution-63b344dd/review.json.
README et notes Obsidian technique et UX actualisés, `updated` et wikilinks
préservés. Aucun constat à ajouter à `todos/`.
`ce-compound` : Documentation skipped, calcul local expliqué dans le code.
Aucune commande Git mutante ni commit. `git diff --check` réussit.

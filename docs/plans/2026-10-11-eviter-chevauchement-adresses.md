---
title: "Masquer les adresses qui se chevauchent sur la carte"
status: completed
date: 2026-10-11
approved_at: 2026-10-11
completed_at: 2026-10-11
owner: Samuel
tags: [plan, map, saved-places]
---

# Masquer les adresses qui se chevauchent

## Résultat et accord

Plan présenté dans le chat puis approuvé par Samuel avec « je valide ».
Les adresses enregistrées ne doivent plus superposer leurs icônes et leurs
libellés. Les marqueurs masqués réapparaissent dès que la caméra libère assez
de place. Les avatars, événements et interactions existants restent disponibles.

## Périmètre et approche

Utiliser les collisions natives des view annotations Mapbox pour les adresses,
avec leur rectangle complet, déjà mis à jour lorsque les libellés changent.
Préserver les autres annotations et leur priorité, y compris lors d'une sélection.
Pas de clustering supplémentaire, de transparence, de modification des données,
de Firebase ou du style du fond de carte.

## Fichiers concernés

- `wander/MapAnnotations.swift` : collisions et priorité des annotations.
- `wander/SavedPlaceAnnotation.swift` : seulement si un ajustement de géométrie est nécessaire.
- `wanderTests/SavedPlaceAnnotationTests.swift` : couverture pertinente si nécessaire.
- `wanderUITests/NaverImportUITests.swift` : adapter le scénario dense existant et vérifier les interactions.
- `wander/DebugSocialMapScenario.swift` : seulement si le scénario existant ne suffit pas.
- Ce plan et les éventuels constats de revue dans `todos/`.
- Obsidian `Documentation UX.md`, section « Import d'une liste Naver ».
- Obsidian `Documentation technique.md`, section « Favoris Naver locaux ».

Les notes Obsidian sont dans
`/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander`.
Mettre à jour leur propriété `updated` et conserver les wikilinks. Si l'écriture
n'est pas disponible, consigner les sections à mettre à jour ici sans créer de copie.

## État initial et dépendances

- HEAD : `0b8e686a78f8485197ea9358de3482d7853bba43`, branche `main`.
- Modifications préexistantes : `ContentView.swift`, `DebugSocialMapScenario.swift`,
  `OutingPlanComposerView.swift`, `SavedPlace.swift`, `SavedPlaceDetailView.swift`,
  `SavedPlaceTests.swift`, `NaverImportUITests.swift` et le plan événement depuis adresse.
- Préserver ces modifications. Aucun Git modifiant le dépôt, conformément aux instructions de Samuel.
- Mapbox 11.32.0 déjà installé ; un seul scénario de correction, exécuté localement.
- Simulateur existant : iPhone 17 Pro, `C0DADF07-7E14-4D5E-AE4B-B17844A9C454`.

## Mise en œuvre

- [x] Approbation explicite du plan.
- [x] Adapter le test dense et constater son échec avant correction.
- [x] Appliquer la politique de collision ciblée et préserver les priorités sociales.
- [x] Simplifier et revoir le changement.
- [x] Valider la compilation, les collisions, le zoom et la sélection.
- [x] Mettre à jour les notes Obsidian.
- [x] Consigner la validation exacte et terminer le plan.

## Risques et critères d'acceptation

- Le rectangle des noms longs peut masquer beaucoup de lieux : vérifier la lisibilité
  et la réapparition au zoom.
- Les changements de taille ou de priorité ne doivent pas créer de superpositions
  persistantes ou de clignotements au repos.
- Dans la zone dense de 36 adresses, seuls les marqueurs sans chevauchement apparaissent.
- Un lieu isolé reste visible et sa fiche s'ouvre après un zoom/dézoom.
- Avatars et événements restent utilisables.

## Validation prévue

Tests natifs `SavedPlaceAnnotationTests`, couverture pertinente du magasin d'annotations,
scénarios UI existants Naver pour la densité, les libellés au zoom et l'ouverture des
fiches, sur le seul simulateur déjà démarré et à taille de texte standard.
Examiner les captures XCTest et la sortie de compilation. Aucun test d'accessibilité dédié.

## Revue et limites

Décision : masquer les annotations en collision plutôt que rendre les noms translucides.
Le scénario dense existant exigeait auparavant 36 marqueurs simultanés ; cette attente
sera remplacée conformément au nouveau comportement explicitement approuvé.
Les tests actuels des vues vérifient leur taille et le seuil des libellés, pas les
collisions réelles du moteur de carte.

## Preuves recueillies

- Reproduction avant correction : le test dense échoue sur la condition de
  non-chevauchement, `/tmp/wander-collision-red.log`, résultat
  `Test-wander-2026.10.11_14-36-45-+0900.xcresult`.
- Après correction : compilation et 11 tests ciblés réussis, 6 natifs et 5 UI,
  `/tmp/wander-collision-green.log`, résultat
  `Test-wander-2026.10.11_14-38-04-+0900.xcresult`.
- Validation finale du scénario dense recentré : réussite en 28,490 s,
  `/tmp/wander-collision-centered.log`, résultat
  `Test-wander-2026.10.11_14-42-04-+0900.xcresult`. Même commande ci-dessous avec
  seulement `-only-testing:wanderUITests/NaverImportUITests/testDenseAddressesAvoidOverlapAndReappearOnZoom`.
- Captures finales inspectées : trois adresses lisibles après recentrage, puis
  six après zoom, sans collision entre favoris. Les marqueurs sociaux gardent
  leur place. Captures dans `/tmp/wander-collision-centered-captures/` :
  `646332D7-B4DA-43CC-8859-D0327D6770A0.png` et
  `59B261D7-7D39-4A27-957D-B3126571E642.png`.
- Vérification finale : `git diff --check` réussit. Changements de production
  limités à `MapAnnotations.swift` ; géométrie et scénarios Debug réutilisés sans
  modification. Les changements préexistants du fichier UI sont conservés.
- Les résultats sont dans
  `/Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx/Logs/Test/`.
- Les tests couvrent le rectangle complet des adresses denses, la réapparition au
  zoom, les seuils des libellés, les noms longs, l'ouverture répétée de la fiche,
  le réimport et les interactions sociales. Le scénario dense a ensuite été
  renforcé par un panoramique avant le zoom pour garder ses lieux dans l'écran.
- `ce-simplify-code` : trois lectures indépendantes, aucun changement nécessaire.
  Une suggestion de micro-optimisation d'un ensemble dans le test a été écartée,
  sans bénéfice utile pour cette fixture de 36 lieux.
- `ce-code-review` : revue ciblée, aucun constat actionnable. Reçu dans
  `/tmp/compound-engineering-501/ce-code-review/20261011-wander-map-collision/review.json`.
- Obsidian : sections prévues mises à jour dans les deux notes, avec `updated`,
  sans ouvrir le logiciel. Aucun changement de backlog ou de vision produit.
- XcodeBuildMCP n'est pas disponible ; équivalent exécuté avec `xcodebuild`,
  `simctl` et captures XCTest conformément au fallback du dépôt.
- Aucun nouvel avertissement Swift. Xcode signale un diagnostic AppIntents sans
  dépendance ; la compilation initiale signale aussi les numéros de versions
  préexistants des extensions 27 et 15 face à celui de l'app 53. Hors périmètre.
- Aucun changement de données ou contrat Firebase. Pas de validation sur appareil
  physique ni avec la liste personnelle de la capture utilisateur.
- Pas de note de solution distincte : simple configuration native de collision,
  documentée ici et dans les notes techniques. Aucun nouveau constat pour `todos/`.

Commande de validation principale :

```bash
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'platform=iOS Simulator,id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' -only-testing:wanderTests/SavedPlaceAnnotationTests -only-testing:wanderTests/MapSocialProximityControllerTests/testAnnotationStoreBatchOperationsPreserveIdentityAndCleanUpOnce -only-testing:wanderTests/MapSocialProximityControllerTests/testAnnotationStoreMovesResizesAndRemovesItsNativeView -only-testing:wanderTests/MapSocialProximityControllerTests/testVisibleSingletonCanBeSelectedAndActivatedRepeatedlyWithoutBeingReplaced -only-testing:wanderUITests/NaverImportUITests/testDenseAddressesAvoidOverlapAndReappearOnZoom -only-testing:wanderUITests/NaverImportUITests/testMapLabelsAppearOnZoomAndDisappearOnZoomOut -only-testing:wanderUITests/NaverImportUITests/testSingleFieldPreviewSaveAndReimportWithoutDuplicates -only-testing:wanderUITests/MapSocialGestureUITests/testNearbyFriendTapSelectsOnlyThatFriendAndAllowsNextFriendTap -only-testing:wanderUITests/MapSocialGestureUITests/testOpeningGroupAndClosingOnBackground -parallel-testing-enabled NO -collect-test-diagnostics never -disableAutomaticPackageResolution test
```

Documentation de référence consultée :
[View annotations Mapbox](https://docs.mapbox.com/ios/maps/guides/add-your-data/view-annotations/).

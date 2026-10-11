---
title: Afficher les noms d'adresses plus tôt au zoom
date: 2026-10-11
status: completed
completed_at: 2026-10-11T11:48:05+09:00
approved_at: 2026-10-11
---

# Résultat approuvé

Samuel a approuvé l'apparition du nom et du type au zoom 15,5 au lieu de 16,
avec masquage sous 15,2 au lieu de 15,7. Le réglage reste commun aux adresses.
Les icônes restent visibles à tous les niveaux ; leur apparence ne change pas.
Les noms proches peuvent se chevaucher plus tôt.

## Périmètre et étapes

- `wander/SavedPlaceAnnotation.swift` : changer les deux seuils existants.
- `wanderTests/SavedPlaceAnnotationTests.swift` : adapter le test des seuils.
- Ce plan et les notes `Documentation UX.md`, `Documentation technique.md`,
  `Backlog features.md` du coffre Obsidian Wander existant, avec `updated`.
- [x] Ajuster le seuil et son test sans ajouter de mécanisme.
- [x] Compiler et exécuter les tests d'annotation et le parcours UI existant
  de zoom/dézoom sur l'iPhone 17 Pro déjà démarré.
- [x] Relire le changement et actualiser les trois notes.

## Validation et limites

Petit réglage visuel : test existant adapté, sans ajout de test dédié ni nouveau
cycle rouge. Aucun changement des données, de Firebase, du filtrage des icônes
ou des marqueurs sociaux. Aucun Git mutateur ni nouveau simulateur.
Vérification à taille standard ; pas de test sur appareil physique.

Compilation Debug réussie, 4 tests réussis sur le simulateur existant
`C0DADF07-7E14-4D5E-AE4B-B17844A9C454` : les 3 tests de
`SavedPlaceAnnotationTests` et
`NaverImportUITests/testMapLabelsAppearOnZoomAndDisappearOnZoomOut`.
Le test des seuils couvre 15,5 à l'apparition, le maintien à 15,2 puis le
masquage à 15,19. Le parcours UI couvre zoom, dézoom et ouverture de la fiche.

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' -disableAutomaticPackageResolution -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -only-testing:wanderTests/SavedPlaceAnnotationTests -only-testing:wanderUITests/NaverImportUITests/testMapLabelsAppearOnZoomAndDisappearOnZoomOut test
```

Journal : `/tmp/wander-earlier-labels-tests.log`. Résultat :
`/Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx/Logs/Test/Test-wander-2026.10.11_11-46-38-+0900.xcresult`.
Les captures du parcours sont dans `/tmp/wander-earlier-labels-screens/`.
Aucun avertissement Swift, uniquement les avertissements AppIntents préexistants.
`git diff --check` passe. XcodeBuildMCP absent : validation CLI équivalente.

Revue manuelle de ce réglage trivial contre `/tmp/wander-earlier-labels-before` :
une ligne de production et les valeurs du test changent. Les deux appelants
existants, création des annotations et changement de caméra, appliquent le
même seuil. Écart de 0,3 conservé ; aucune simplification supplémentaire ou
anomalie à consigner dans `todos/`. Aucune nouvelle leçon durable à ajouter.
Les trois notes Obsidian sont actualisées avec leur propriété `updated`.
Les plans antérieurs conservent leurs seuils historiques.

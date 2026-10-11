---
title: Afficher les noms d'adresses dès le zoom 14
date: 2026-10-11
status: completed
completed_at: 2026-10-11T12:00:49+09:00
approved_at: 2026-10-11
---

# Résultat approuvé

Samuel a choisi explicitement 14 en réponse au nouveau seuil proposé.
Le nom et le type apparaissent au zoom 14, avec masquage sous 13,7 pour
conserver la marge existante de 0,3. Réglage commun aux adresses, toutes
les icônes restent visibles. Les textes peuvent se superposer davantage.

## Périmètre et validation

- `wander/SavedPlaceAnnotation.swift` : deux seuils.
- `wanderTests/SavedPlaceAnnotationTests.swift` : valeurs du test existant.
- `wanderUITests/NaverImportUITests.swift` : adapter les attentes initiales,
  car le scénario démarre désormais au-dessus du seuil ; garder le parcours
  de dézoom/zoom et l'affichage immédiat des 36 adresses.
- Ce plan, `Documentation UX.md`, `Documentation technique.md` et
  `Backlog features.md` dans le coffre Obsidian existant, propriété `updated`.
- [x] Appliquer le seuil et adapter les tests existants.
- [x] Compiler et valider annotations et parcours Naver sur le simulateur
  iPhone 17 Pro déjà démarré.
- [x] Relire le diff, actualiser les trois notes et consigner les résultats.

Petit réglage visuel sans ajout de mécanisme ni de test dédié. Aucun Git
mutateur, changement de stockage/Firebase ou nouveau simulateur. Le test UI
est adapté au nouveau seuil sans modifier la caméra de production.
Validation standard, sans test dédié d'accessibilité ni appareil physique.

## Résultats

Revue manuelle de ce réglage : une ligne de production modifiée, test des
seuils actualisé, scénario UI réordonné pour vérifier les noms visibles dès
l'import puis masqués au dézoom et réaffichés au zoom. Le test dense conserve
l'assertion des 36 adresses, avec leurs libellés désormais visibles à la caméra
initiale. Comparaison exacte dans `/tmp/wander-zoom14.diff`, état antérieur dans
`/tmp/wander-zoom14-before`. Aucun nouveau mécanisme ni simplification utile,
aucun constat actionnable à consigner dans `todos/`.

Les trois notes Obsidian ont été actualisées, `updated` compris. Les plans
précédents gardent leurs valeurs historiques. Ce réglage ne fournit pas de
nouvelle leçon justifiant une note dans `docs/solutions/`.
XcodeBuildMCP absent : tests équivalents via xcodebuild sur le simulateur existant.
Compilation Debug et 8 tests réussis : 3 tests d'annotation et les 5 parcours
UI Naver. Le test des seuils couvre apparition à 14, maintien à 13,7 et retrait
à 13,69. Le scénario UI vérifie le nom dès l'import, sa disparition au dézoom,
son retour au zoom et l'ouverture de la fiche. Les 36 adresses de la fixture
dense sont présentes immédiatement ; les tests d'import et réimport passent.

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' -disableAutomaticPackageResolution -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -only-testing:wanderTests/SavedPlaceAnnotationTests -only-testing:wanderUITests/NaverImportUITests test
```

Journal : `/tmp/wander-zoom14-tests.log`. Résultat :
`/Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx/Logs/Test/Test-wander-2026.10.11_11-53-34-+0900.xcresult`.
Captures exportées dans `/tmp/wander-zoom14-screens/` ; le rendu initial
`B4E0DDBE-2245-46EE-9595-383EFC89ECE4.png` montre nom et type à la caméra de départ.
Aucun échec de test. `git diff --check` passe. Pas de validation sur appareil physique.

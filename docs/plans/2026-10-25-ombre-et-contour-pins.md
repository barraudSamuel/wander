---
title: Ombre légère et contour blanc des pins
date: 2026-10-25
status: completed
completed_at: 2026-10-25T13:36:32+05:30
approved_at: 2026-10-25
---

# Ombre légère et contour blanc des pins

Samuel a approuvé le plan présenté dans la conversation par « j'approuve ».

## Résultat et périmètre

Ajouter une ombre noire à 15 %, avec rayon de 2 pt et décalage vertical de 1 pt, sous la silhouette photo et pointe. Renforcer le contour blanc des catégories en passant le stroke de -14 à -30, avec des marges horizontales de 16 pt au lieu de 12. Garder le dessin des contours avant le remplissage noir des lettres.

L'ombre suit la géométrie actuelle et la rotation de la fiche avec un shadowPath explicite. L'algorithme de taille, les priorités et le toucher restent ceux du sprint précédent. Aucun changement de données ou dépendance.

## Fichiers concernés

- `wander/SavedPlaceCalloutView.swift` : ombre de la silhouette.
- `wander/SavedPlacePresentation.swift` : contour du texte et marge de mesure.
- Ce plan et les captures sous `docs/plans/assets/2026-10-25-ombre-contour-pins/`.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md` : rendu des pins, propriété `updated`, wikilinks conservés. Ne pas ouvrir Obsidian.

## Étapes

- [x] Examiner le renderer et obtenir l'approbation du plan.
- [x] Ajouter l'ombre, renforcer le contour et ajuster les marges.
- [x] Relire le delta et vérifier qu'il reste simple.
- [x] Compiler, vérifier sur le simulateur existant et inspecter les captures.
- [x] Mettre à jour la note UX et consigner les résultats.

## Risques et validation

Vérifier que le contour des lettres accentuées et des libellés longs n'est pas coupé. Utiliser un chemin d'ombre explicite pour éviter l'analyse des sous-vues ; ne pas activer la rasterisation, qui pourrait flouter les agrandissements. L'ombre décorative ne modifie pas les zones de toucher.

Utiliser exclusivement l'iPhone 18 Pro iOS 27 déjà autorisé et démarré dans cette session (`CD1E7A76-F65E-495D-A525-F328746F152F`). Compiler et exercer les recettes existantes de pan/zoom et de fiche compact/détaillé/recto-verso, à taille de texte standard. Pas de nouveau test reproduisant les constantes de style. Vérifier le libellé long avec les tests de présentation existants. Conserver une capture de la carte et des deux faces de fiche.

## Résultats

**Projet :** `wander.xcodeproj` ; **scheme :** `wander`.
**Simulateur :** iPhone 18 Pro iOS 27 déjà démarré.
**Build :** réussi. **Écrans inspectés :** 3, carte et deux faces de fiche.

| Vérification | Résultat | Preuve |
|---|---|---|
| Contour accentué, marge et ombre sur photos compactes/détaillées | PASS | [Carte](assets/2026-10-25-ombre-contour-pins/carte-pins.png) |
| Déplacement et zoom sans ouverture automatique | PASS | `testDensePinsFollowPanAndZoomWithoutOpeningCard` |
| Ouverture, retournement et fermeture depuis les deux tailles | PASS | `testPhotoCardFlipsAndClosesFromBothPinSizes` ; [recto](assets/2026-10-25-ombre-contour-pins/fiche-photo.png), [verso](assets/2026-10-25-ombre-contour-pins/fiche-informations.png) |
| Géométrie des libellés longs, ancrage et transitions | PASS | 21 tests natifs existants |

Le run `/private/tmp/wander-shadow-outline-check1.xcresult` et son `.log` contiennent **21 tests natifs et 2 parcours UI sans échec**, avec sortie `TEST SUCCEEDED`. Le contour blanc est plus épais sur les captures, les lettres noires restent intactes et la jonction de pointe ne montre pas de bande grise. L'ombre suit la silhouette sans être coupée par les corps qui masquent la photo. Les captures utilisent des adresses et des illustrations de démonstration.

Commande exécutée :

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'platform=iOS Simulator,id=CD1E7A76-F65E-495D-A525-F328746F152F' \
  -disableAutomaticPackageResolution -parallel-testing-enabled NO \
  -collect-test-diagnostics never \
  -only-testing:wanderTests/SavedPlaceAnnotationTests/testLongLabelsKeepIconAnchoredAndHitTargetUsableWhenToggled \
  -only-testing:wanderTests/SavedPlacePresentationTests \
  -only-testing:wanderUITests/NaverImportUITests/testDensePinsFollowPanAndZoomWithoutOpeningCard \
  -only-testing:wanderUITests/NaverImportUITests/testPhotoCardFlipsAndClosesFromBothPinSizes \
  -resultBundlePath /private/tmp/wander-shadow-outline-check1.xcresult test
```

XcodeBuildMCP demeure absent ; validation manuelle équivalente avec `xcodebuild` et `simctl`. Aucun nouveau simulateur ou runtime. Aucun nouveau test dédié aux valeurs de style.

**Console :** aucune erreur applicative relevée dans le log de test, aucun warning Swift ; avertissement de métadonnées AppIntents et diagnostics de version du runtime Xcode préexistants.
**Vérifications humaines requises :** 0. **Échecs résiduels :** 0. **Résultat :** PASS.

Revue ciblée indépendante et simplification : aucun constat actionnable sur le delta des deux fichiers, comparé aux snapshots `/private/tmp/wander-shadow-baseline/`. `git diff --check` passe. Aucun todo ajouté puisqu'aucun défaut n'a été retenu. La mise à jour de `Documentation UX.md` conserve ses wikilinks et renouvelle `updated` ; Obsidian n'a pas été ouvert.

Aucune nouvelle leçon durable à ajouter : la correction est expliquée par le code et ce plan. Aucun changement de la logique de taille ou de priorité. Les mesures de cadence du sprint précédent ne sont pas revendiquées pour ce nouveau rendu ; aucune mesure GPU ou vérification sur appareil physique n'a été réalisée. Aucun commit ni push exécuté.

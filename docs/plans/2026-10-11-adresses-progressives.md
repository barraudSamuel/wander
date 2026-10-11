---
title: Adresses progressives selon la place sur la carte
date: 2026-10-11
status: completed
completed_at: 2026-10-11T11:15:21+09:00
approved_at: 2026-10-11
---

# Résultat approuvé

Comportement annulé à la demande de Samuel le 11 octobre 2026 ; voir le
[plan de retour à toutes les icônes visibles](2026-10-11-annuler-adresses-progressives.md).
Le présent document conserve l'historique de l'implémentation et de sa validation.

Samuel a validé des icônes espacées de loin, davantage d'adresses au zoom,
et nom/type uniquement lorsqu'il y a assez de place. La sélection doit rester
stable pendant les déplacements et éviter les clignotements.

## Périmètre

- `wander/MapAnnotations.swift` : appliquer la visibilité native des adresses.
- `wander/MapWithFogView.swift` : recalculer la présentation par adresse.
- `wander/SavedPlaceAnnotation.swift` : placement en écran et taille des libellés.
- Tests d'annotations et scénario Naver dense dans les fixtures/tests UI existants.
- Ce plan et les éventuels constats de revue.
- Obsidian Wander : `Documentation UX.md`, `Documentation technique.md`,
  `Backlog features.md` dans le coffre existant.

## Implémentation et acceptation

- [x] Espacer les icônes selon le zoom avec une priorité déterministe.
- [x] Afficher progressivement les noms/types, sans recouvrir les autres adresses.
- [x] Garder une marge différente à l'apparition et à la disparition pour la stabilité.
- [x] Vérifier densité, ordre stable, collisions, bords et changements de zoom.
- [x] Compiler et valider une zone dense, les déplacements et la sélection sur
  l'iPhone 17 Pro déjà démarré ; relire les captures.
- [x] Revue, simplification et mise à jour des trois notes Obsidian.

## Risques et limites

Les favoris restent tous enregistrés. Les points masqués réapparaissent à mesure
que le zoom libère de la place ; les positions identiques peuvent rester superposées.
Ne modifier ni les marqueurs sociaux, ni les données, ni Firebase. Garder le verre
clear de 36 pt, le symbole de 20 pt, la cible de 44 pt et l'ancrage géographique.
Éviter les mises à jour inutiles des vues à chaque déplacement. Test de scénario
synthétique sans test d'accessibilité dédié, aucun nouveau simulateur.
Travail local en place, sans Git mutateur ni transfert externe. XcodeBuildMCP
absent : équivalent CLI autorisé par les consignes du projet.

## Choix d'implémentation et revue

`SavedPlaceMapLayout` traite les positions projetées à l'écran, dans un ordre
stable d'identifiants, avec priorité au favori sélectionné. L'espacement des
icônes passe progressivement de 96 à 44 pt selon le zoom. Les noms ont des seuils
déterministes répartis entre 15,4 et 16,4, avec hystérésis de 0,3. Les collisions
et la place jusqu'au bord décident ensuite de l'affichage. Une adresse conserve
son icône si son nom ne tient pas. La largeur du nom est calculée uniquement
lors de sa configuration. Les mutations de vue identiques sont ignorées.

La revue et la simplification ont corrigé deux défauts : visibilité rétablie à
tort par synchronizeCoordinates (`todos/078-done-p1-preserver-visibilite-adresses.md`)
et recalcul absent au changement de viewport (`todos/079-done-p2-recalculer-adresses-viewport.md`).
La méthode du coordinateur s'appelle désormais `updateSavedPlacePresentations`.
Les autres lectures de réutilisation et d'efficacité n'ont pas retenu de correctif.
La revue compare uniquement `/tmp/wander-density.diff` et la copie antérieure
`/tmp/wander-density-before`, afin de préserver le travail Naver précédent.
Le helper de revue ne gère pas cette base de fichiers : revue locale équivalente,
sans transfert externe. Reçu `/tmp/wander-density-review.json`.

Les notes Obsidian UX, technique et Backlog sont actualisées avec leur propriété
`updated`. Pas de nouvelle note de solution : les causes, corrections et tests
de régression expliquent directement les problèmes résolus et sont retrouvables
dans les constats ci-dessus, conformément au critère de ce-compound.

## Validation finale

PASS : compilation Debug et 50 tests distincts sur l'iPhone 17 Pro existant
`C0DADF07-7E14-4D5E-AE4B-B17844A9C454`, au terme des deux passes réussies.
Aucun avertissement Swift ; message d'outillage AppIntents préexistant uniquement.
`git diff --check` réussit. Les captures avant/après zoom ont été relues.

Commande commune :

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' -disableAutomaticPackageResolution -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -only-testing:wanderTests/SavedPlaceAnnotationTests -only-testing:wanderTests/MapSocialProximityControllerTests -only-testing:wanderUITests/NaverImportUITests test
```

- Passe 11:09:10 : 9 tests d'annotation, 34 tests sociaux natifs et 5 scénarios UI
  Naver réussis. Journal `/tmp/wander-density-final.log`.
- Passe 11:12:33 après correction du callback viewport : les 10 tests d'annotation,
  le scénario dense Naver et `MapSocialGestureUITests/testNativeMapRenderSizeStaysStableAcrossPaneChanges`
  réussissent. Même commande avec uniquement ces trois sélecteurs.
  Journal `/tmp/wander-density-viewport.log`.
- Avant correction, `testHiddenSavedPlaceStaysHiddenAfterCoordinateSynchronization`
  échouait bien sur l'assertion du masquage. Journal `/tmp/wander-density-regression.log`.
- Deux premières compilations ont requis de découper les expressions des fixtures
  et d'expliciter leurs types pour le compilateur Swift ; erreurs corrigées.

Les résultats sont dans
`/Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx/Logs/Test/`,
`Test-wander-2026.10.11_11-09-10-+0900.xcresult` et
`Test-wander-2026.10.11_11-12-33-+0900.xcresult`.

Captures dans `/tmp/wander-density-screens/` :
- `F22288E1-30E3-4289-8D7A-6B0F502423F8.png` : quartier dense de loin ;
- `B3A57599-0CE8-4FA6-B47D-1B1DDE383EA2.png` : davantage d'icônes au zoom ;
- `49D6FAD1-6746-41D0-95EC-66553ACA41AF.png` : nom/type lorsqu'il y a assez de place.

Le test dense importe 36 lieux, vérifie qu'une partie seulement apparaît de loin,
contrôle l'absence d'intersections au zoom et après déplacement, puis ouvre une fiche.
Les unités vérifient la progression, les collisions, l'hystérésis, la stabilité de
l'ordre et les bords. Le scénario isolé vérifie l'apparition et le retrait du texte.
Pas de test sur appareil physique ni de mesure de performances pour des milliers
d'adresses. La sélection évite les collisions entre favoris ; les autres marqueurs
et les libellés du fond de carte gardent leur comportement existant.

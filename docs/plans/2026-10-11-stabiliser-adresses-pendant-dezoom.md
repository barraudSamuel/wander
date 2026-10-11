---
title: "Stabiliser les libellés pendant le dézoom"
status: completed
date: 2026-10-11
approved_at: 2026-10-11
completed_at: 2026-10-11
owner: Samuel
tags: [plan, map, saved-places]
---

# Stabiliser les libellés pendant le dézoom

## Résultat et accord

Samuel signale que des lieux apparaissent puis disparaissent au cours du même
dézoom. Il a approuvé le plan dans le chat avec « je valide ».
Conserver la taille des marqueurs pendant le mouvement, puis adapter leurs
libellés une fois la caméra arrêtée. Garder les collisions et la sélection.

## Hypothèse et approche

`cameraDidChange` masque les noms dès que le zoom descend sous 13,7. Le rectangle
des annotations passe alors d'une largeur pouvant atteindre 208 pt à 44 pt,
libérant des places pendant que le dézoom continue. Vérifier ce changement
intermédiaire avec le vrai coordinateur et le moteur Mapbox avant la correction.
Reporter l'actualisation commune des libellés à la fin du mouvement. Les nouvelles
annotations doivent reprendre l'état commun sans le recalculer pendant le geste.
Réutiliser les événements de caméra existants ; pas de nouveau moteur de collision.

## Périmètre et fichiers

- `wander/MapWithFogView.swift` : moment d'actualisation des noms.
- `wander/MapEdgeZoomController.swift` : signaler le geste personnalisé au moteur,
  nécessaire pour recevoir la fin du mouvement même après une pause du doigt.
- `wanderTests/SavedPlaceAnnotationTests.swift` : régression pendant le dézoom animé.
- `wanderUITests/NaverImportUITests.swift` : scénarios existants à réutiliser, ajustement si nécessaire.
- Ce plan dans `docs/plans/`, éventuels constats dans `todos/`.
- Obsidian `Documentation UX.md`, section « Import d'une liste Naver ».
- Obsidian `Documentation technique.md`, section « Favoris Naver locaux ».

Vault : `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander`.
Mettre à jour `updated`, conserver les wikilinks et ne pas ouvrir Obsidian.
Pas de changement de données, Firebase, apparence des contrôles ou priorités sociales.

## Dépendances et risques

La correction précédente des collisions reste en place. Préserver toutes les
modifications préexistantes, notamment le fichier des tests UI. Aucun Git modifiant
le dépôt. Exécution locale, un seul incrément. Le plan précédent est terminé.
Le texte s'adaptera à la fin du mouvement plutôt que dès le passage du seuil.
Vérifier aussi l'import initial, le zoom avant, l'inertie et le zoom de bord.
Si les apparitions intermédiaires persistent malgré une taille stable, cette
hypothèse ne suffit pas : signaler le résultat et présenter le complément de plan.

## Checklist

- [x] Plan explicitement approuvé.
- [x] Reproduire le changement de taille pendant le dézoom.
- [x] Reporter l'actualisation des libellés à la fin du mouvement.
- [x] Vérifier les tests natifs et les scénarios UI sur le simulateur existant.
- [x] Simplifier et revoir le changement ciblé.
- [x] Mettre à jour Obsidian, consigner la validation et terminer le plan.

## Validation et critères d'acceptation

Utiliser uniquement l'iPhone 17 Pro déjà démarré
`C0DADF07-7E14-4D5E-AE4B-B17844A9C454`, à taille de texte standard.
Mesurer les dimensions des annotations pendant un dézoom traversant 13,7 ;
elles doivent rester stables jusqu'à la fin de la caméra, puis devenir compactes.
Les nouveaux lieux importés à l'arrêt gardent leurs noms dès le zoom 14.
Vérifier le zoom avant, les collisions, l'ouverture des fiches et les contrôles sociaux.
XcodeBuildMCP indisponible : validation équivalente avec `xcodebuild` et `simctl`.

## Validation réalisée

L'animation native de caméra seule ne reproduit pas la variation intermédiaire
dans la fixture. Le zoom de bord, lui, la reproduit : le marqueur passe de 208 à
44 pt alors que `MapEdgeZoomController` est encore actif. Le test échoue avant
correction à cette assertion, dans `/tmp/wander-zoom-labels-edge-red.log`.
La fixture utilise le vrai `MapWithFogView` hébergé par SwiftUI et un style local.
Le contrôleur de bord ne signalait pas son geste à Mapbox. Deux appels natifs
`beginGesture`/`endGesture` complètent le déplacement de l'actualisation vers
la fin de caméra ; aucune nouvelle abstraction ni dépendance.

Validation finale : 28 tests natifs et 3 scénarios UI réussis sur le simulateur
existant. Le premier run corrigé passe les 28 tests natifs, le scénario des noms
au zoom et celui de l'import avec sélection répétée. Le scénario dense échoue
sur une hypothèse de cadrage du test : aucune icône retenue par les collisions
n'est assez loin du bord pour la condition de recentrage. Le test choisit
désormais une icône visible et démarre le panoramique au centre de la carte,
pour ne pas déclencher le zoom de bord. Les assertions de non-chevauchement,
de réapparition au zoom et d'ouverture de la fiche sont conservées. Son retest
passe en 27,385 s.

Commandes exécutées :

```bash
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'platform=iOS Simulator,id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' -only-testing:wanderTests/SavedPlaceAnnotationTests -only-testing:wanderTests/MapEdgeZoomControllerTests -only-testing:wanderUITests/NaverImportUITests/testMapLabelsAppearOnZoomAndDisappearOnZoomOut -only-testing:wanderUITests/NaverImportUITests/testDenseAddressesAvoidOverlapAndReappearOnZoom -only-testing:wanderUITests/NaverImportUITests/testSingleFieldPreviewSaveAndReimportWithoutDuplicates -parallel-testing-enabled NO -collect-test-diagnostics never -disableAutomaticPackageResolution test
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'platform=iOS Simulator,id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' -only-testing:wanderUITests/NaverImportUITests/testDenseAddressesAvoidOverlapAndReappearOnZoom -parallel-testing-enabled NO -collect-test-diagnostics never -disableAutomaticPackageResolution test
```

Logs : `/tmp/wander-zoom-labels-green.log` et `/tmp/wander-zoom-labels-dense.log`.
Résultats dans
`/Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx/Logs/Test/` :
`Test-wander-2026.10.11_14-55-49-+0900.xcresult` et
`Test-wander-2026.10.11_14-58-16-+0900.xcresult`.

`git diff --check` réussit. Aucun nouvel avertissement Swift ; diagnostic
AppIntents sans dépendance toujours présent. La fixture native émet aussi une
erreur de localisation du fournisseur Mapbox sur simulateur, déjà présente avant
la correction ; elle utilise des coordonnées synthétiques et ne teste pas le GPS.

`ce-simplify-code` : trois lectures indépendantes, aucune simplification nécessaire.
`ce-code-review` : revue ciblée des quatre fichiers de code/test, aucun constat
actionnable. Reçu :
`/tmp/compound-engineering-501/ce-code-review/20261011-wander-zoom-labels/review.json`.
Les deux notes Obsidian prévues ont été actualisées avec `updated`.
`ce-compound` : pas de note séparée, la raison du correctif est conservée dans
le commentaire, le test de régression, ce plan et la documentation technique.
Aucun nouveau constat dans `todos/`, aucun Git modifiant le dépôt.

Limites : pas de validation sur iPhone physique ni avec la liste privée de Samuel.
Ce changement stabilise les dimensions pendant le geste ; les collisions réelles
peuvent toujours masquer un lieu lorsque la place disponible diminue.

---
title: Simplifier les pins après la revue Ponytail
status: completed
date: 2026-10-25
approved_at: 2026-10-25
completed_at: 2026-10-25
tags: [plan, map, refactor]
---

## Approbation et résultat attendu

Samuel a approuvé le plan présenté dans le chat par « j ápprouve ».
Supprimer les données et calculs devenus inutiles depuis le retour de la fiche native,
sans changer l'affichage, les animations, les touches ni la sélection des pins.
Réutiliser l'attente bornée existante dans le test de zoom.

## Périmètre et dépendances

Le travail porte sur les trois simplifications de la revue Ponytail des changements
non commités. Le modèle SavedPlace, la fiche native, les gardes de présentation,
le moteur d'animation, les imports et les ressources restent dans leur contrat actuel.
Pas de nouvelle abstraction, migration ou dépendance. Pas de Git mutateur, commit
ou publication. Le travail préexistant est conservé ; baseline des fichiers concernés
sous `/private/tmp/wander-ponytail-20261025-baseline`.

## Fichiers concernés

- `wander/SavedPlaceAnnotation.swift` : retirer les cinq champs de fiche, leur copie,
  les rectangles occupied*, leurs calculs et les propriétés sans lecteur ; réutiliser stopAnimation.
- `wander/MapWithFogView.swift` : limiter la reconfiguration au titre et à la catégorie,
  garder la synchronisation des coordonnées.
- `wanderTests/SavedPlaceAnnotationTests.swift` : vérifier les mêmes valeurs via
  currentVisualRect et renderedBodyRect ; remplacer l'attente sans limite par waitUntil.
- Ce plan et les constats prioritaires `todos/086-done-p2-borner-attente-animation.md`
  et `todos/087-done-p3-retirer-etat-inutile-pins.md`.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md` :
  corriger la description des rectangles et des données de pin, actualiser updated,
  préserver les wikilinks. Aucun changement produit nécessitant les autres notes.

## Implémentation

- [x] Retirer les champs et mises à jour inutiles du pin.
- [x] Retirer les rectangles redondants et autres propriétés sans lecteur.
- [x] Adapter les assertions et borner l'attente de fin de zoom.
- [x] Exécuter la simplification et la revue indépendantes sur le delta de ce travail.
- [x] Compiler et exécuter les tests natifs et parcours UI ciblés.
- [x] Mettre à jour la note technique et enregistrer les résultats exacts.

## Risques et validation

Préserver les coordonnées, les changements de titre/catégorie après réimport,
la géométrie réellement affichée pendant une animation et les assertions de visibilité.
Les tests existants couvrent ces comportements ; aucune nouvelle logique produit
ne justifie un nouveau test. L'attente bornée reprend le helper de cinq secondes.
Pas de test rouge avant refactor revendiqué : validation de non-régression après adaptation.

Validation prévue : compilation, SavedPlaceAnnotationTests, SavedPlacePresentationTests,
SavedPlaceSelectionTests et SavedPlaceEmphasisLayoutTests ; parcours UI de réimport,
ouverture/fermeture native, densité et pan/zoom à taille de texte standard.
Pas de tests d'accessibilité dédiés. Aucun appareil ou runtime à créer, démarrer ou télécharger.
Le seul simulateur allumé détecté est l'iPhone 18 Pro iOS 27,
`CD1E7A76-F65E-495D-A525-F328746F152F`. La règle du dépôt nomme l'iPhone 17 :
Samuel a explicitement autorisé cet appareil existant dans le chat : « oui 18pro ».

## Acceptation et résultats

Le travail sera terminé quand les suppressions sont effectives, la compilation et
les vérifications ciblées passent, la revue n'a aucun défaut actionnable restant,
et la note Obsidian est actualisée ou sa limitation d'accès est explicitement enregistrée.
Compilation réussie. Les 42 tests natifs et les 4 parcours UI passent sur
l'iPhone 18 Pro existant, sans échec ni test ignoré. Aucun gain de cadence revendiqué.

## Notes d'exécution

Implémentation via ce-work, avec les règles du dépôt prioritaires : checkout courant,
aucun Git mutateur, suivi dans le plan. Le delta de ce travail est exactement le diff
non indexé des trois fichiers Swift ; les changements précédents restent indexés.
Diff actuel : 10 lignes ajoutées, 57 retirées, soit 47 lignes de moins.

ce-simplify-code : revues indépendantes de réutilisation, qualité et efficacité
terminées sans constat supplémentaire ; revue des tests également sans constat. Aucun commentaire
modifié nécessitant une passe dédiée. Les tests de preuve sont conservés.

XcodeBuildMCP absent ; validation manuelle équivalente avec xcodebuild et simctl,
conformément au workflow de secours du dépôt. Compilation générique sans lancement
d'appareil réussie dans `/private/tmp/wander-ponytail-build.log`.

ce-code-review ne peut pas exprimer la comparaison au seul index existant : ses
endpoints exigent une référence Git, qui élargirait la revue au travail antérieur.
Créer une référence ou un commit serait contraire aux règles Git du dépôt.
La tentative s'arrête donc à la résolution du périmètre ; revue indépendante
manuelle équivalente Ponytail du delta exact, sans reçu CE prétendument réussi.
Revue terminée sans défaut actionnable ; rapport `/private/tmp/wander-ponytail-review.json`.

Documentation technique Obsidian mise à jour le 25 octobre 2026 : géométrie courante,
données minimales d'annotation et attente de test bornée. Propriété updated actualisée,
wikilinks inchangés, contenu relu après écriture. Obsidian n'a pas été ouvert.

### Validation disponible

Projet `wander.xcodeproj`, scheme `wander`, configuration Debug.

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -disableAutomaticPackageResolution build-for-testing
```

Résultat : `TEST BUILD SUCCEEDED`, sortie 0. App et tests compilés pour simulateur.
Aucun warning Swift dans le log. Cinq avertissements d'extraction AppIntents et
deux avertissements de CFBundleVersion des extensions (15 et 27, app 53) restent
dans les configurations préexistantes, non modifiées par ce travail.

`git diff --check` passe. Aucun symbole supprimé ne subsiste dans le code ou les tests.
Les trois versions de l'index correspondent octet pour octet aux sauvegardes de
début de tâche. Aucun Git mutateur exécuté.

Les tests ont été exécutés après l'autorisation explicite de Samuel d'utiliser
l'iPhone 18 Pro iOS 27 déjà démarré. Aucun autre simulateur démarré, créé ou
téléchargé. La capture des logs est arrêtée et l'appareil reste allumé.

### Résultats Xcode finaux

Projet : wander.xcodeproj. Scheme : wander. Simulateur : iPhone 18 Pro, iOS 27.0,
arm64, CD1E7A76-F65E-495D-A525-F328746F152F. Build : réussi. Résultat : PASS.
Quatre parcours UI vérifiés, 46 tests réussis, zéro échec et zéro test ignoré.
Confirmation par `xcresulttool get test-results summary`, result Passed.

| Surface | Résultat | Preuve |
|---|---|---|
| Géométrie, animations, coordonnées, réutilisation | PASS | 14 SavedPlaceAnnotationTests, dont l'attente de zoom bornée |
| Calcul de taille et ordre | PASS | 11 SavedPlaceEmphasisLayoutTests |
| Présentation et interruption | PASS | 12 SavedPlacePresentationTests |
| Sélection et viewport | PASS | 5 SavedPlaceSelectionTests |
| Zone dense et ouverture de deux adresses | PASS | testDenseAddressesKeepPhotosAndOpenDetails |
| Pan/zoom sans ouverture automatique | PASS | testDensePinsFollowPanAndZoomWithoutOpeningSheet |
| Fiche depuis les pins compacts et détaillés, fermeture et réouverture | PASS | testNativeSheetOpensAndClosesFromBothPinSizes |
| Réimport sans doublons et lien Naver visible | PASS | testSingleFieldPreviewSaveAndReimportWithoutDuplicates |

Preuves : `/private/tmp/wander-ponytail-tests.xcresult`, `.log` et douze captures
exportées dans `/private/tmp/wander-ponytail-captures`. Inspection visuelle de la
zone dense, fin de déplacement, fiche native et lien Naver, sans régression visible.
Les fixtures sont synthétiques ; aucune connexion Naver réelle ou publication
Firebase n'est revendiquée. Vérifications humaines requises : 0. Échecs restants : 0.

Journaux : 532 entrées E et 4 F, séparées des diagnostics Df, principalement
haptique, réseau, CoreAnimation, clavier, XCTest et initialisation de taille Mapbox.
Aucun motif de crash détecté ni assertion de test en échec. Les grandes catégories
étaient déjà documentées dans le plan de retour à la fiche native ; elles ne sont
pas présentées comme corrigées. Capture compressée, environ 3,9 Mo, dans
`/private/tmp/wander-ponytail-runtime.log.gz`, erreurs isolées dans
`/private/tmp/wander-ponytail-runtime-errors.log`.

Commande exacte :

```sh
xcodebuild -xctestrun /Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx/Build/Products/wander_wander_iphonesimulator27.1-arm64-x86_64.xctestrun \
  -destination 'platform=iOS Simulator,id=CD1E7A76-F65E-495D-A525-F328746F152F' \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  -only-testing:wanderTests/SavedPlaceAnnotationTests \
  -only-testing:wanderTests/SavedPlacePresentationTests \
  -only-testing:wanderTests/SavedPlaceSelectionTests \
  -only-testing:wanderTests/SavedPlaceEmphasisLayoutTests \
  -only-testing:wanderUITests/NaverImportUITests/testSingleFieldPreviewSaveAndReimportWithoutDuplicates \
  -only-testing:wanderUITests/NaverImportUITests/testNativeSheetOpensAndClosesFromBothPinSizes \
  -only-testing:wanderUITests/NaverImportUITests/testDenseAddressesKeepPhotosAndOpenDetails \
  -only-testing:wanderUITests/NaverImportUITests/testDensePinsFollowPanAndZoomWithoutOpeningSheet \
  -resultBundlePath /private/tmp/wander-ponytail-tests.xcresult test-without-building
```

### Revue et capitalisation

- Décision principale : réutiliser la géométrie courante plutôt que conserver
  des copies mises à jour à chaque image.
- Alternatives écartées : nouvelle abstraction de présentation, mutualisation des
  gardes entre parcours distincts, suppression de tests de comportement.
- Limite restante : validation sur données synthétiques, pas de service Naver/Firebase réel.
- Aucune nouvelle leçon durable justifiant une note supplémentaire dans docs/solutions.

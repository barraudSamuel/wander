---
title: Retour de la fiche native des adresses
status: completed
date: 2026-10-25
approved_at: 2026-10-25
completed_at: 2026-10-25
---

Samuel a approuvé le plan présenté dans le chat : « Je valide, remets la fiche native en gardant les pins actuels, leurs animations, l’ombre et le contour blanc. »

## Résultat et limites

Un appui sur une adresse ouvre la fiche iOS « Adresse enregistrée », aux hauteurs moyenne et grande. Elle reprend nom, adresse, liste, avertissements Naver, lien Naver et création d'événement préremplie. La carte photo retournable disparaît. Les pins photo conservent leur croissance selon la position et le zoom, leurs animations, leur ordre, l'ombre et le contour blanc.

Aucun changement de données, Firebase, illustrations ou algorithme de mise en avant. Aucun Git mutateur, commit ou push. Les changements préexistants sont conservés. Baseline locale de comparaison : `/private/tmp/wander-native-sheet-baseline`.

## Fichiers concernés

- `wander/ContentView.swift`, `wander/SavedPlaceDetailView.swift`, `wander/DebugSocialMapScenario.swift`.
- `wander/MapWithFogView.swift`, `wander/MapAnnotations.swift`, `wander/SavedPlaceAnnotation.swift`, `wander/SavedPlaceCalloutView.swift`, `wander/SavedPlacePresentation.swift`.
- `wanderTests/SavedPlaceAnnotationTests.swift`, `wanderTests/SavedPlacePresentationTests.swift`, `wanderTests/SavedPlaceSelectionTests.swift`, `wanderUITests/NaverImportUITests.swift`.
- Ce plan, captures sous `docs/plans/assets/2026-10-25-fiche-native-adresses/`, éventuels constats vérifiés sous `todos/` et leçon réutilisable sous `docs/solutions/` si justifiée.
- Vault `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` : `Documentation UX.md` (ouverture/fermeture des adresses), `Documentation technique.md` (sélection, rendu et création d'événement), `Backlog features.md` (remplacement de la fiche retournable), `00 - Wander.md` (état actuel). Actualiser `updated`, préserver les wikilinks.

## Implémentation

- [x] Restaurer la fiche SwiftUI et ses actions dans le parcours produit et le scénario local.
- [x] Découpler sélection et carte photo ; conserver dessin, animation de taille et suivi de la sélection par le parent.
- [x] Retirer le recentrage, le retournement et la fermeture hors viewport propres à l'ancienne carte photo.
- [x] Attendre la fermeture native avant présentation du formulaire d'événement.
- [x] Adapter les tests existants à la fiche native ; conserver les preuves de croissance, ancrage et toucher.
- [x] Simplifier, compiler, tester sur le simulateur existant et inspecter les captures.
- [x] Effectuer une revue indépendante et mettre à jour la documentation.

## Risques

Double présentation, fermeture intempestive au changement de viewport, pin sélectionné figé, réouverture impossible et formulaire présenté avant la fin de fermeture. Le rendu des pins partage actuellement le composant de la carte photo : préserver exactement son dessin pendant la suppression de la fiche.

## Validation et acceptation

Utiliser uniquement le simulateur déjà démarré iPhone 18 Pro iOS 27, `CD1E7A76-F65E-495D-A525-F328746F152F`, utilisé dans les validations précédentes. Aucun démarrage/création/téléchargement d'autre appareil. Pas de tests d'accessibilité dédiés.

Adapter les tests de comportement existants, puis vérifier sélection confirmée par le parent, disparition du lieu, réutilisation, ancrage, continuité et taille indépendante de la sélection. Parcours UI : petit/grand pin, hauteur moyenne/grande, croix/glissement, réouverture, création préremplie, catégorie inconnue et adresse longue, import/réimport, zone dense et pan/zoom sans ouverture. Inspecter le rendu sur carte et fiche ouverte, fournir une capture. Les tests et captures seront la preuve d'acceptation ; aucune mesure de cadence supplémentaire n'est requise.

## Résultats

Compilation réussie. Bilan final : **42 tests natifs et 12 parcours UI distincts réussis** sur deux runs, aucun échec résiduel. Aucun test rouge avant implémentation revendiqué : adaptation des tests existants et validation intégrée après modification.

Simplification effectuée suivant les cinq axes du skill ce-simplify-code ; aucune modification supplémentaire justifiée. Revue indépendante terminée, aucun défaut actionnable. Le périmètre Git du skill ce-code-review ne peut pas comparer la sauvegarde de fichiers locale, donc revue manuelle équivalente du delta exact, sans élargissement au travail préexistant. Résultat : `/private/tmp/wander-native-sheet-review/review.json`.

Comparaison automatique à la baseline : `SavedPlaceEmphasisLayout`, `SavedPlaceEmphasisMotion` et `SavedPlaceCategoryStickerView` inchangés. Les valeurs d'ombre et son tracé sont préservés. Les quatre notes Obsidian ont été mises à jour avec le bilan final ; copie avant modification sous `/private/tmp/wander-native-sheet-baseline/obsidian`.

XcodeBuildMCP indisponible : workflow équivalent avec xcodebuild, simctl et captures XCTest. Aucun nouveau simulateur. Aucun commit ou push.


## Validation finale

Projet `wander.xcodeproj`, scheme `wander`, Debug, simulateur iPhone 18 Pro iOS 27 déjà démarré. Build réussi. Résultat **PASS** pour le périmètre approuvé.

- `/private/tmp/wander-native-sheet-check1.xcresult` et `.log` : 42 tests natifs réussis, 11 parcours UI réussis, un échec du sélecteur de test Naver.
- Le snapshot d'échec montre `Link` avec l'identifiant `saved-place-open-naver`. Le test cherchait encore un `Button` de la carte supprimée. Correction uniquement du test vers `app.links`, mêmes exigences d'existence et de visibilité ; capture ajoutée.
- `/private/tmp/wander-native-sheet-check2.xcresult` et `.log` : réimport, lien et réouvertures réussis, sortie `TEST SUCCEEDED`.
- `git diff --check` réussi. Aucun warning du compilateur Swift ; trois avertissements préexistants d'extraction AppIntents et diagnostics de version du SDK Xcode dans le premier build.

| Surface | Résultat | Preuve |
|---|---|---|
| Pins compacts/détaillés, ombre et contour | PASS | Tests d'ancrage, sélection et mouvement ; [pin](assets/2026-10-25-fiche-native-adresses/pin-detaille.png), [compact](assets/2026-10-25-fiche-native-adresses/pin-compact.png) inspectés |
| Fiche moyenne et grande, croix et glissement, réouverture | PASS | Deux parcours dédiés ; [moyenne](assets/2026-10-25-fiche-native-adresses/fiche-native.png) et [grande](assets/2026-10-25-fiche-native-adresses/fiche-native-agrandie.png) inspectées |
| Pan/zoom, zone dense, zoom latéral | PASS | Quatre parcours UI ; [zone dense](assets/2026-10-25-fiche-native-adresses/pins-zone-dense.png) |
| Import/réimport, lien natif visible, erreur/fermeture import | PASS | Run 1 et reprise ciblée run 2 ; [lien](assets/2026-10-25-fiche-native-adresses/fiche-native-lien-naver.png) |
| Création préremplie, catégorie inconnue et nom/adresse longs | PASS | Deux parcours UI, fermeture native avant formulaire et publication locale |

Captures de données synthétiques et illustrations locales. Pas de connexion Naver réelle, publication Firebase, ni validation humaine requise pour ces scénarios locaux. L'ouverture effective d'une application Naver externe n'a pas été exercée.

Les logs unifiés `/private/tmp/wander-native-sheet-runtime-errors.log` contiennent 1 562 lignes E/F système/SDK, surtout réseau, clavier/haptique du simulateur, CoreAnimation et diagnostics d'automatisation. Parmi elles : 38 messages Mapbox de taille initiale invalide avec repli 64×64 et 19 refus de localisation des scénarios. Les captures montrent les tuiles et les tests passent ; aucun crash observé. Ces diagnostics ne sont pas présentés comme corrigés par ce changement. La capture de logs a été arrêtée ; le simulateur préexistant reste allumé.

Revue indépendante enregistrée dans [revue.json](assets/2026-10-25-fiche-native-adresses/revue.json), aucune constatation actionnable à ajouter aux todos. Pas de nouvelle leçon réutilisable justifiant un document de solution pour ce retour à la présentation native existante.

Commande du premier run :

```bash
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'platform=iOS Simulator,id=CD1E7A76-F65E-495D-A525-F328746F152F' \
  -disableAutomaticPackageResolution -parallel-testing-enabled NO -collect-test-diagnostics never \
  -only-testing:wanderTests/SavedPlaceAnnotationTests \
  -only-testing:wanderTests/SavedPlacePresentationTests \
  -only-testing:wanderTests/SavedPlaceSelectionTests \
  -only-testing:wanderTests/SavedPlaceEmphasisLayoutTests \
  -only-testing:wanderUITests/NaverImportUITests \
  -resultBundlePath /private/tmp/wander-native-sheet-check1.xcresult test
```

La reprise garde les mêmes options, avec seulement `-only-testing:wanderUITests/NaverImportUITests/testSingleFieldPreviewSaveAndReimportWithoutDuplicates` et le bundle `check2`.

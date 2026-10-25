---
title: Refaire la mise en avant des adresses depuis la vidéo
date: 2026-10-25
status: completed
completed_at: 2026-10-25T12:54:22+05:30
approved_at: 2026-10-25
---

# Refaire la mise en avant des adresses depuis la vidéo

Samuel a approuvé ce plan dans la conversation par « je valide ». Cette refonte remplace la proposition de correction par collisions. La vidéo `/Users/samuelbarraud/Downloads/8WlF_NQxpVslwGdX.mp4` est la référence comportementale ; ni les commits ni les anciennes règles ne définissent le résultat.

## Résultat et observations

- 0–1,5 s : petits cercles, même au centre.
- 1,7–2,2 s : plusieurs photos grandissent pendant le zoom.
- 3–7 s : les photos rétrécissent vers les côtés et grandissent dans une zone centrale large. Les adresses hautes peuvent rester grandes.
- 5,8 s : chevauchement de petits cercles ; 2,2 s : chevauchement de texte avec un voisin.
- Tailles intermédiaires, texte et pointe progressifs. La formule interne et les durées exactes ne sont pas déductibles du film.

## Contrat approuvé

La position dans le viewport visible et le zoom produisent une intensité continue de mise en avant. Une zone centrale conserve plusieurs grandes photos ; les bords les réduisent. La présence, la taille, l'identifiant et l'histoire des voisins ne décident pas de cette intensité. Les chevauchements sont autorisés. Les adresses centrales passent devant ; le toucher suit ce qui est effectivement dessiné. Une sélection explicite ouvre la fiche complète, au premier plan. Le mouvement continue pendant les gestes, l'inertie, le zoom et les changements de sens.

Les coefficients de zone, de zoom et de suivi temporel sont calibrés visuellement pendant ce sprint. Aucun ancien seuil n'est une exigence. La carte, les données sauvegardées, les imports, les fiches et les marqueurs sociaux restent intégrés avec la stack actuelle. Pas de migration ni dépendance ajoutée. L'exception de design des pins est déjà approuvée.

## Fichiers concernés

- `wander/SavedPlaceEmphasisLayout.swift` : nouveau moteur pur position/zoom/rang.
- `wander/MapAnnotations.swift` : projection, application et résolution du toucher ; retrait du résolveur à collisions.
- `wander/SavedPlaceAnnotation.swift`, `wander/SavedPlacePresentation.swift` : cible continue, suivi temporel et intégration sélection. `wander/SavedPlaceCalloutView.swift` : silhouette tactile de la fiche tournée, correction issue de la revue dans ce même périmètre.
- `wander/MapWithFogView.swift` : callbacks caméra et viewport ; suppression des décisions de taille externes.
- `wanderTests/SavedPlaceEmphasisLayoutTests.swift`, `wanderTests/SavedPlaceAnnotationTests.swift`, `wanderTests/SavedPlacePresentationTests.swift` : contrat continu et intégration. Validation de sélection avec `SavedPlaceSelectionTests.swift`.
- `wanderUITests/NaverImportUITests.swift` : recette dense, déplacement, zoom et sélection.
- Ce plan, preuves sous `docs/plans/assets/2026-10-25-refonte-pins/`, constats dans `todos/` et leçon vérifiée dans `docs/solutions/` si pertinente.
- Notes du coffre `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` : `Backlog features.md`, `Documentation technique.md`, `Documentation UX.md`, `00 - Wander.md`. Mettre à jour `updated` et préserver les wikilinks ; ne pas ouvrir Obsidian.

## Étapes

- [x] Observer la vidéo, distinguer faits et hypothèses, obtenir l'approbation.
- [x] Remplacer la décision d'agrandissement par le moteur indépendant des voisins.
- [x] Brancher le suivi continu, l'empilement et le toucher ; retirer les anciennes règles et adapter leurs tests.
- [x] Simplifier et vérifier le contrat avec des tests natifs.
- [x] Valider sur le simulateur déjà démarré, comparer le déplacement/zoom au film et enregistrer une vidéo.
- [x] Revue indépendante, corrections nécessaires et documentation synchronisée.

## Risques, validation et acceptation

La densité peut provoquer des recouvrements importants. Vérifier que le pin devant reçoit le toucher, que les photos centrales gardent la même taille avec ou sans voisins et que les photos périphériques restent présentes. Ne pas réintroduire un veto de collision pour les tailles. Le coût du changement d'ordre natif et du suivi par frame sera mesuré.

Tester : centre/haut/côtés, zoom éloigné/rapproché, continuité aux limites, densité indépendante de la taille, viewport décalé et recadré, ordre stable en cas d'égalité, inversion pendant l'animation, sélection/fermeture/recto-verso. Mettre à jour les anciens tests qui prescrivaient collisions, masquage et hystérésis de zoom. Les preuves vidéo utilisent les scènes synthétiques existantes et ne valident pas un flux Naver réel.

Utiliser exclusivement le simulateur déjà démarré iPhone 18 Pro iOS 27 `CD1E7A76-F65E-495D-A525-F328746F152F`, autorisé dans cette session. Pas de nouveau simulateur/runtime ni test dédié d'accessibilité. Réaliser les vérifications UI à taille de texte standard. Distinguer cadence d'encodage vidéo et intervalles de rendu mesurés.

L'historique Git n'est ni consulté comme source produit ni modifié. Préserver les changements préexistants ; snapshots de travail hors dépôt pour attribuer la revue à ce sprint. L'autorité de validation reste dans le contexte principal.

## Validation exécutée

Validation terminée. Le moteur utilise un produit de trois courbes smoothstep : zoom 12,2–13,2, distance horizontale normalisée 0,48–0,92 et verticale 0,78–0,98. Le suivi critique analytique utilise une pulsation de 24 rad/s et conserve la vitesse lors des changements de cible. Les catégories apparaissent entre les intensités 0,45 et 0,85. Ce sont des coefficients de calibration, pas la formule prétendument extraite de la vidéo.

La simplification indépendante n'a demandé qu'une correction de commentaire. La revue complète `20261025-121931-2c0b2122`, sur le delta exact du sprint, a confirmé un P2 de toucher pendant le retournement d'une fiche. Il est suivi dans [085](../../todos/085-done-p2-toucher-fiche-en-perspective.md). Les suggestions de couverture ont ajouté le toucher d'une photo derrière une marge invisible et une mesure de cadence qui traverse le nouvel intervalle de zoom.

XcodeBuildMCP est absent ; l'équivalent manuel utilise `xcodebuild` et `simctl` sur le seul simulateur existant. Les échecs intermédiaires sont conservés dans `/private/tmp/wander-refonte-native1.xcresult`, `ui1`, `check2` et `check3` (même préfixe). Les recettes précédentes imposaient des collisions ou touchaient l'ancre sous la photo ; elles ont été adaptées au contrat continu et aux pixels visibles. La fixture de viewport masque maintenant une photo entièrement sortie, puis vérifie sa réapparition à caméra constante. Les résultats ci-dessous proviennent des reprises réussies. Les runs check4 et check5 contiennent encore des échecs de recette au bord droit, résolus puis vérifiés séparément dans right-final ; ils ne sont pas présentés comme des runs entièrement verts.


## Capitalisation

`ce-compound` a évalué les apprentissages du sprint. Aucune nouvelle note de solution n'est nécessaire : le contrat position/zoom est explicite dans le moteur pur, les tests et ce plan ; le coût des fiches invisibles et la validation de géométrie rendue sont déjà documentés. Le correctif de perspective et sa preuve sont conservés dans le constat 085. Aucun changement à AGENTS.md ou CONCEPTS.md.

Documentation skipped — aucune nouvelle leçon durable absente du code, des tests et des documents existants.


## Résultats finaux

**Projet :** `wander.xcodeproj` — **Scheme :** `wander` — **Build :** réussi, zéro warning du compilateur Swift sur le périmètre.
**Simulateur :** iPhone 18 Pro, iOS 27, `CD1E7A76-F65E-495D-A525-F328746F152F`.
**Écrans inspectés :** carte, recto photo, verso d'informations ; 7 parcours UI distincts.

Les **50 tests natifs passent sans échec** dans `/private/tmp/wander-refonte-check4.xcresult` : 14 tests d'annotations, 11 du moteur pur, 20 de présentation et 5 de sélection. Le correctif du P2 est vérifié par le renderer, l'hôte et l'activation d'un vrai voisin via le store. Le test des marges transparentes et celui de viewport passent également.

| Parcours UI | Statut | Résultat de référence |
|---|---|---|
| Déplacement et zoom de 36 pins sans ouverture automatique | PASS | `wander-refonte-check2.xcresult` — `testDensePinsFollowPanAndZoomWithoutOpeningCard` |
| Photos denses et ouverture de deux adresses | PASS | `wander-refonte-check5.xcresult` — `testDenseAddressesKeepPhotosAndOpenDetails` |
| Texte apparaissant au zoom et disparaissant au dézoom | PASS | `wander-refonte-check5.xcresult` — `testMapLabelsAppearOnZoomAndDisappearOnZoomOut` |
| Recto, verso et fermeture depuis les deux tailles | PASS | `wander-refonte-check4.xcresult` — `testPhotoCardFlipsAndClosesFromBothPinSizes` |
| Fiche suivant la carte puis se fermant hors zone | PASS | `wander-refonte-check5.xcresult` — `testOpenCardFollowsMapDragAndClosesOutsideTheUsefulViewport` |
| Zoom depuis la photo au bord gauche, puis ouverture | PASS | `wander-refonte-check4.xcresult` — `testLeftEdgeZoomStartsOnSavedAddressIconAndStillAllowsTap` |
| Zoom depuis la photo au bord droit, puis ouverture | PASS | `wander-refonte-right-final.xcresult` — `testRightEdgeZoomStartsOnSavedPhotoPinAndStillAllowsTap` |

Ces bundles et leurs `.log` sont sous `/private/tmp/`. Les scénarios de toucher ont été rejoués après la correction de perspective. La vidéo de déplacement précède cette correction tactile ; la géométrie et l'animation des photos y sont identiques à la version finale.

### Commandes de validation

Options communes à toutes les commandes :

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'platform=iOS Simulator,id=CD1E7A76-F65E-495D-A525-F328746F152F' \
  -disableAutomaticPackageResolution -parallel-testing-enabled NO \
  -collect-test-diagnostics never
```

Ajouter les sélecteurs puis `-resultBundlePath <bundle> test` :

- `check4` : `-only-testing:wanderTests/SavedPlaceEmphasisLayoutTests`, `SavedPlacePresentationTests`, `SavedPlaceAnnotationTests`, `SavedPlaceSelectionTests` (même préfixe `wanderTests/`) ; puis les trois parcours UI `testPhotoCardFlipsAndClosesFromBothPinSizes`, `testLeftEdgeZoomStartsOnSavedAddressIconAndStillAllowsTap`, `testRightEdgeZoomStartsOnSavedPhotoPinAndStillAllowsTap` avec le préfixe `-only-testing:wanderUITests/NaverImportUITests/`.
- `check5` : même préfixe UI pour `testRightEdgeZoomStartsOnSavedPhotoPinAndStillAllowsTap`, `testDenseAddressesKeepPhotosAndOpenDetails`, `testMapLabelsAppearOnZoomAndDisappearOnZoomOut`, `testOpenCardFollowsMapDragAndClosesOutsideTheUsefulViewport`.
- `right-final` : seul `-only-testing:wanderUITests/NaverImportUITests/testRightEdgeZoomStartsOnSavedPhotoPinAndStillAllowsTap` ; sortie `TEST SUCCEEDED`.
- La commande exacte de chaque run est conservée en tête de son log. `check2` contient la séquence de démonstration filmée.

### Cadence et preuves visuelles

Le scénario synthétique de 36 pins traverse désormais les zooms 15,3 → 12,1 → 13,3, donc toute la rampe de croissance. Il mesure les callbacks Mapbox séparément du calcul de présentation.

| Passage | Frames | Intervalle médian | Intervalle p95 | Maximum | Calcul de présentation p95 |
|---|---:|---:|---:|---:|---:|
| 1 | 147 | 16,67 ms | 18,11 ms | 19,79 ms | 0,228 ms |
| 2 | 147 | 16,68 ms | 17,76 ms | 19,52 ms | 0,242 ms |
| 3 | 150 | 16,66 ms | 17,70 ms | 20,03 ms | 0,265 ms |

- [Vidéo du déplacement et du zoom](assets/2026-10-25-refonte-pins/deplacement-zoom.mp4) : 13,87 s, vitesse réelle, 804 × 1748, encodage 60 images/s. Aucun lissage artificiel ; cette cadence d'encodage n'est pas une mesure GPU.
- [Aperçu animé du déplacement](assets/2026-10-25-refonte-pins/deplacement-apercu.gif) : 7 s à 15 images/s, pour un aperçu léger.
- [Recto photo](assets/2026-10-25-refonte-pins/fiche-photo.png) et [verso d'informations](assets/2026-10-25-refonte-pins/fiche-informations.png) capturés dans check4 et inspectés. Le contenu long du verso défile ; son pied reste fixe.

**Console :** 6 messages Mapbox de localisation refusée (`CLErrorDomain Code=1`) dans les fixtures natives qui utilisent leurs propres coordonnées. Aucun crash ni erreur fonctionnelle résiduelle observé sur ces parcours. Xcode émet également ses diagnostics de métadonnées AppIntents sans dépendance (3 avertissements) et de version du runtime ; aucun avertissement Swift ajouté.
**Vérifications humaines requises :** 0.
**Échecs résiduels :** 0 sur le périmètre exercé.
**Résultat :** PASS.

### Revue et documentation

Le reçu complet `review.json` et son `resolution-addendum.json` restent dans `/private/tmp/compound-engineering-501/ce-code-review/20261025-121931-2c0b2122/`. Le seul P2 est corrigé, revu et vérifié : [constat 085 clôturé](../../todos/085-done-p2-toucher-fiche-en-perspective.md). Aucun constat restant sur ce delta. `git diff --check` et le contrôle des espaces des 11 fichiers Swift concernés sont propres.

Les quatre notes Obsidian du plan ont été mises à jour dans le coffre réel, avec `updated` renouvelé et les 52 wikilinks préservés. Obsidian n'a pas été ouvert. Les anciens résultats du 24 octobre y restent explicitement historiques.

Limites : scènes et illustrations synthétiques ; aucun flux Naver ou Firebase réel validé ; aucun appareil physique testé. La formule interne de l'application de référence reste inconnue. En forte densité, des photos peuvent se recouvrir : c'est le contrat approuvé, et aucun veto de collision ne réduit leur taille.

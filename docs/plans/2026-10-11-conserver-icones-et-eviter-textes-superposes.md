---
title: "Conserver les icônes et éviter les textes superposés"
status: completed
date: 2026-10-11
approved_at: 2026-10-11
completed_at: 2026-10-11
owner: Samuel
tags: [plan, map, saved-places]
---

# Conserver les icônes et éviter les textes superposés

## Résultat et approbation

Samuel signale un masquage trop agressif au dézoom et des textes toujours
superposés. Il approuve le plan révisé avec « je valide ».
Conserver les icônes quand seul le texte manque de place. Masquer le nom et le
type s'ils rencontrent une icône ou un autre texte. Ne masquer un lieu entier
que lorsque son icône rencontre un autre marqueur. Aucune atténuation.
Stabiliser les décisions pendant le dézoom sans réserver les textes masqués.

## Périmètre

- `wander/SavedPlaceAnnotation.swift` : mesure indépendante du frame imposé par
  Mapbox, rectangles des icônes/textes, visibilité des textes par favori.
- `wander/MapAnnotations.swift` : collisions distinctes des icônes et des
  textes, visibilité stable pendant le dézoom et recalcul des géométries.
- `wander/MapWithFogView.swift` : transmettre les mouvements et le seuil des
  noms au calcul de collision.
- `wanderTests/SavedPlaceAnnotationTests.swift` : reproduire les dimensions
  incohérentes et les collisions de textes ; vérifier la conservation des
  icônes, la stabilité et le retour des noms quand de la place se libère.
- `wanderUITests/NaverImportUITests.swift` : plusieurs lieux réellement
  visibles, noms et icônes séparés, ouverture d'une fiche et dézoom.
- Ce plan, constats dans `todos/` et apprentissage dans `docs/solutions/` si
  justifiés après validation.
- Obsidian `Documentation UX.md`, section « Import d'une liste Naver ».
- Obsidian `Documentation technique.md`, section « Favoris Naver locaux ».

Vault : `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander`.
Actualiser `updated` et préserver les wikilinks, sans ouvrir Obsidian.
Préserver le travail déjà présent. Aucune modification de données, Firebase,
style, dépendances ou contrôles natifs. Aucun Git modifiant le dépôt.

## Étapes et validation

1. Reproduire le défaut de mesure après placement Mapbox et les paires de
   noms longs ; ne corriger cette piste qu'une fois confirmée.
2. Mesurer le contenu indépendamment des dimensions que Mapbox lui attribue.
3. Décider d'abord des icônes, puis des noms contre les icônes et noms visibles.
   Préserver la sélection et les marqueurs sociaux. Garder les décisions
   stables pendant le dézoom, sans rectangles fantômes de textes masqués.
4. Valider les vrais rectangles dessinés dans le moteur natif, au repos et
   pendant une animation : plusieurs noms longs, plusieurs icônes conservées,
   dézoom continu, zoom avant, sélection et décalage de caméra.
5. Revue, tests ciblés, `git diff --check`, documentation et clôture du plan.

Seulement le simulateur iPhone 17 Pro existant
`C0DADF07-7E14-4D5E-AE4B-B17844A9C454`, texte standard. CLI Xcode si les outils
XcodeBuildMCP sont indisponibles. Aucun test d'accessibilité dédié.
Risque : moins de noms affichés dans les zones denses, mais davantage de
lieux identifiables par leur icône. Les icônes réellement superposées restent
masquées. Validation sur la liste exacte et l'iPhone de Samuel non disponible.

## Checklist

- [x] Plan approuvé.
- [x] Reproduction et mesure des rectangles après placement natif.
- [x] Corriger la mesure et séparer les collisions des icônes et des textes.
- [x] Valider les tests natifs et UI avec plusieurs favoris visibles.
- [x] Simplifier et revoir le changement ciblé.
- [x] Actualiser les notes et clôturer après validation.

## Diagnostic et mise en œuvre

Deux tests rouges avant toute correction, journal `/tmp/wander-icons-red.log` :
la mesure redescendait à 44 pt après un ancien placement compact alors que
les noms avaient besoin de 208 pt ; huit icônes espacées donnaient seulement
deux lieux visibles quand le masquage utilisait les rectangles complets.

`SavedPlaceAnnotationView` mesure maintenant le contenu indépendamment du
frame attribué par Mapbox. La largeur des labels est calculée à la configuration.
L'autorisation de zoom et l'occlusion individuelle des noms sont distinctes.
Le contenu est limité aux bounds de la vue pour empêcher un texte de déborder
pendant une mise à jour native différée.

Le store place d'abord les ronds de 36 pt, puis les noms contre les ronds
acceptés, les marqueurs sociaux et les autres noms. Les éléments masqués ne
réservent plus de place. Pendant un dézoom continu, leur masquage est mémorisé
jusqu'à l'arrêt ou au zoom avant, pour éviter les cascades de réapparition.
La sélection passe en premier et garantit l'icône ; son nom reste soumis aux
collisions. Les callbacks natifs de frame déclenchent un recalcul regroupé.
Le rejet des coordonnées invalides précède toujours la projection Mapbox.

Les appels caméra et le seuil global déjà présents dans `MapWithFogView.swift`
conviennent à cette séparation : aucun changement supplémentaire dans ce fichier.
Le seuil de zoom continue d'attendre la fin du mouvement ; les noms peuvent
se masquer individuellement pendant celui-ci quand ils rencontrent une icône.

## Revue et validation

- Trois revues ciblées de simplification : aucune réutilisation à remplacer ;
  suppression de l'état dérivé `showsLabels`, largeur mesurée à la configuration,
  suppression des tableaux temporaires à chaque comparaison de noms.
- Revue finale contradictoire du calcul, de la sélection et de l'histoire du
  dézoom : aucun défaut restant. `Code review: targeted manual due to unrelated
  branch work`, conformément au périmètre prescrit par ce-debug. Les travaux
  antérieurs dans le dépôt ont été préservés. Aucun constat restant dans `todos/`.
- Compilation et 68 tests distincts réussis : 7 SavedPlaceAnnotationTests,
  34 MapSocialProximityControllerTests, 24 MapEdgeZoomControllerTests et trois
  NaverImportUITests. Journal `/tmp/wander-icons-final.log`, résultat
  `Test-wander-2026.10.11_16-38-24-+0900.xcresult`.
- Commande : `xcodebuild -project wander.xcodeproj -scheme wander -configuration
  Debug -destination 'platform=iOS Simulator,id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454'
  -parallel-testing-enabled NO -collect-test-diagnostics never
  -disableAutomaticPackageResolution test`, filtrée avec `-only-testing:` sur
  les trois suites natives et les parcours UI de liste dense, seuils des noms,
  et import/réimport sans doublons. XcodeBuildMCP indisponible : CLI équivalente.
- Le test à huit lieux vérifie plusieurs textes réellement dessinés, tous les
  ronds conservés pendant un dézoom doux, l'alpha à 1, la mesure après placement
  natif, le retour des noms après libération de place et la sélection.
- Les tests compacts couvrent dézoom continu sans réapparition temporaire,
  zoom avant, marge de sortie, priorité sociale, coordonnées invalides et sortie
  du champ. La liste dense exige au moins quatre favoris, plusieurs noms et des
  icônes compactes ; elle compare les régions dessinées plutôt que les seuls
  rectangles des boutons. La caméra est déplacée avant le zoom.
- Une interruption Swift de destruction de la carte SwiftUI entre deux tests
  a été isolée : le test termine maintenant la destruction de sa fenêtre avant
  de rendre la main. Le passage final des 65 tests natifs se termine sans
  interruption. Aucun changement du renderer ou du moteur de fog.
- Les notes Obsidian UX et technique sont mises à jour, propriété `updated`
  comprise, sans ouvrir Obsidian.
- Jugement ce-compound : pas de fiche supplémentaire, car le commentaire, les
  tests et les deux notes expliquent la mesure indépendante et le placement
  en deux passes ; une fiche ne ferait que dupliquer ces sources.
- Pas de validation sur l'iPhone physique ou avec la liste exacte de Samuel.
- Dernier scénario UI dense renforcé et réussi après dézoom de bord, carte
  dégagée avant l'ouverture de la fiche : `/tmp/wander-icons-clean-ui.log`,
  `Test-wander-2026.10.11_16-41-38-+0900.xcresult`. Les captures de
  `/tmp/wander-icons-clean-captures/` ont été inspectées : neuf icônes avant,
  huit après le dézoom, plusieurs noms avant le mouvement et aucune collision
  entre les noms et les autres ronds. Aucun panneau ne masque la carte.
- `git diff --check` réussi. Aucun avertissement Swift ; le seul message du
  build concerne l'extraction AppIntents sans dépendance à ce framework.
  Aucune commande Git modifiant le dépôt exécutée.

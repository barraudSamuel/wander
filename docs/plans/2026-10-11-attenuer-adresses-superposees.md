---
title: "Atténuer les adresses superposées sans clignotement"
status: completed
date: 2026-10-11
approved_at: 2026-10-11
completed_at: 2026-10-11
owner: Samuel
tags: [plan, map, saved-places]
---

# Atténuer les adresses superposées sans clignotement

## Accord et résultat

Samuel a approuvé le plan révisé dans le chat avec « je valide ».
La vidéo du 11 octobre à 15:29 montre des icônes déjà compactes qui changent
de visibilité pendant le dézoom. Le correctif des dimensions ne traite donc
pas tout le symptôme. Remplacer le masquage en collision par une opacité réduite
des adresses secondaires, avec un ordre stable. Les marqueurs sociaux et la
sélection gardent leur priorité. Aucune modification Git, donnée ou dépendance.

## Approche et périmètre

1. Reproduire les changements de visibilité avec des annotations compactes
   et le moteur Mapbox, indépendamment des seuils de libellés.
2. Autoriser le chevauchement natif des favoris. Calculer leurs intersections
   à partir de la projection courante, avec un ordre stable par identifiant.
3. Atténuer les favoris secondaires, préserver la sélection et les marqueurs
   sociaux. Garder les dimensions stables pendant le mouvement.
4. Vérifier le dézoom continu, les zones denses et l'ouverture d'une fiche.

Fichiers concernés :
- `wander/MapAnnotations.swift` : politique d'affichage et collisions.
- `wander/SavedPlaceAnnotation.swift` : présentation si nécessaire.
- `wander/MapWithFogView.swift` : actualisation pendant et après le mouvement.
- `wanderTests/SavedPlaceAnnotationTests.swift` : régression native.
- `wanderUITests/NaverImportUITests.swift` : scénario dense et sélection.
- Ce plan, constats prioritaires dans `todos/` si nécessaire et apprentissage
  réutilisable dans `docs/solutions/` si la validation le justifie.
- Obsidian `Documentation UX.md`, section « Import d'une liste Naver ».
- Obsidian `Documentation technique.md`, section « Favoris Naver locaux ».

Vault : `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander`.
Actualiser `updated`, préserver les wikilinks et ne pas ouvrir Obsidian.
Préserver le travail préexistant dans les fichiers concernés.

## Risques et validation

Les zones denses gardent davantage d'icônes. Vérifier qu'une adresse atténuée
reste présente et sélectionnable, sans masquer les contrôles sociaux.
Vérifier le retour à pleine opacité quand les marqueurs se séparent.
Utiliser seulement l'iPhone 17 Pro déjà démarré
`C0DADF07-7E14-4D5E-AE4B-B17844A9C454`, taille de texte standard.
Tests natifs avec style local, scénario UI d'import dense, zoom et sélection,
compilation Xcode et revue ciblée. Pas de validation sur iPhone physique ni
avec la liste privée de Samuel. Ne pas annoncer une reproduction exacte de
la vidéo si seules les collisions contrôlées ont été reproduites.

## Checklist

- [x] Plan approuvé.
- [x] Reproduire et confirmer le mécanisme de masquage.
- [x] Remplacer le masquage par une atténuation stable.
- [x] Vérifier les tests et le rendu sur le simulateur existant.
- [x] Simplifier et revoir le changement.
- [x] Actualiser les deux notes Obsidian et consigner les limites.
- [x] Terminer après validation des critères d'acceptation.

## Diagnostic

Avec trois cafés compacts espacés de 60 puis 30 pt au zoom 15, le test natif
`testCompactPlacesRemainVisibleThroughoutContinuousZoomOut` observe la séquence
`[false, true, false]` sur le troisième café pendant un dézoom unique vers 13.
La taille reste de 44 pt, le style est local et aucune donnée n'est réimportée.
Le test rouge est conservé dans `/tmp/wander-opacity-reverse-red.log`.
Le moteur greedy masque le deuxième café lorsqu'il rejoint le premier, libère
temporairement le troisième, puis le masque à son tour. Le test UI antérieur
vérifiait seulement les positions à l'arrêt et encourageait ce masquage.

La nouvelle politique utilise `allowOverlap = true`, un ordre stable par
`sourceID` puis `placeID`, et une opacité de 30 % pour les favoris secondaires.
Tous les rectangles, même atténués, réservent leur place. Une marge de sortie
de 4 pt évite les oscillations d'opacité au bord d'une collision. Les marqueurs
sociaux réservent leurs rectangles et la sélection reste à pleine opacité.
Le premier run corrigé supprime les disparitions et passe les assertions
d'opacité, mais la vérification du retour au zoom 17 sort le dernier café du
viewport. Le contrôle utilise désormais le zoom 16, où les trois sont visibles
et suffisamment espacés. Il ne s'agit pas d'une nouvelle hypothèse de correction.

## Validation et revue réalisées

66 tests distincts réussis sur l'iPhone 17 Pro existant :
- 5 `SavedPlaceAnnotationTests`, dont le contrôle des frames pendant tout le
  dézoom, l'opacité constante du café secondaire, la sélection, le retour à
  pleine opacité, la marge de sortie et la priorité d'un marqueur social.
- 24 `MapEdgeZoomControllerTests` et 34 `MapSocialProximityControllerTests`.
- 3 scénarios `NaverImportUITests` : liste dense, noms au zoom et import avec
  sélection répétée sans doublons. Le scénario dense vérifie les 36 identités
  après dézoom et l'ouverture puis fermeture d'une fiche.

Commandes principales :

```bash
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'platform=iOS Simulator,id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' -only-testing:wanderTests/SavedPlaceAnnotationTests -only-testing:wanderTests/MapSocialProximityControllerTests -only-testing:wanderTests/MapEdgeZoomControllerTests -only-testing:wanderUITests/NaverImportUITests/testDenseAddressesStayPresentWhenZoomingAndOpenDetails -parallel-testing-enabled NO -collect-test-diagnostics never -disableAutomaticPackageResolution test
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'platform=iOS Simulator,id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' -only-testing:wanderUITests/NaverImportUITests/testDenseAddressesStayPresentWhenZoomingAndOpenDetails -parallel-testing-enabled NO -collect-test-diagnostics never -disableAutomaticPackageResolution test
```

Logs : `/tmp/wander-opacity-final.log` pour les 63 tests natifs réussis,
`/tmp/wander-opacity-validation.log` pour les deux scénarios UI de noms et
d'import réussis, `/tmp/wander-opacity-dense-final.log` pour le scénario dense
final réussi en 27,779 s. Les deux premiers runs UI denses échouaient après
le zoom avant : les captures montrent le quartier entier hors du viewport,
pas un masquage en collision. Le scénario dense conserve désormais son cadrage
initial, ouvre la fiche puis dézoome. Le retour au zoom et à pleine opacité
reste vérifié dans le test natif avec des coordonnées garanties à l'écran.

Résultats Xcode dans
`/Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx/Logs/Test/` :
`Test-wander-2026.10.11_15-43-15-+0900.xcresult` et
`Test-wander-2026.10.11_15-45-52-+0900.xcresult`.
Captures du run dense final examinées dans `/tmp/wander-opacity-success-captures/` :
`4F467A27-FCD9-4A2A-B0AE-391DBE404F94.png` avant dézoom et
`A8E2A8C2-04B2-45EF-A13F-C23F98990C36.png` après dézoom.
Les favoris secondaires sont atténués, les marqueurs sociaux restent lisibles
et les contrôles natifs restent au-dessus des annotations.

`ce-test-xcode` : XcodeBuildMCP indisponible, équivalent manuel avec Xcode CLI,
tests XCTest/XCUITest et captures xcresult. Compilation réussie, aucun nouvel
avertissement Swift. Diagnostic AppIntents sans dépendance et diagnostics
Mapbox de taille initiale 64x64/localisation des fixtures natives préexistants.
Pas de crash du scénario UI. Aucune vérification humaine requise pour ces fixtures.
`git diff --check` réussit.

`ce-simplify-code` : trois lectures indépendantes ciblées. Un constat d'efficacité
appliqué : regrouper les changements de géométrie/visibilité dans une seule
actualisation différée, avec capture faible. Nouvelle lecture de l'efficacité
sans constat restant. Réutilisation et qualité sans constat.
`ce-code-review` : revue manuelle ciblée, car les fichiers portent aussi du
travail antérieur. Vérification de la projection, validité, ordre, priorité,
sélection, retrait, fin de geste, durée de vie des callbacks et couverture des
tests ; aucun constat actionnable restant, donc aucun nouveau fichier `todos/`.
`ce-compound` : pas de note séparée ; le raisonnement réutilisable et la
régression temporelle sont déjà conservés dans le test, les commentaires,
ce plan et la documentation technique.

Les deux notes Obsidian prévues sont actualisées avec `updated` et leurs
wikilinks conservés. `SavedPlaceAnnotation.swift` n'a pas nécessité de changement.
Les correctifs précédents des dimensions et du geste de bord sont conservés.
Aucune mutation Git, aucune publication.

Limites : scénario synthétique reproduisant le mécanisme de la vidéo,
pas la liste privée exacte de Samuel ni un iPhone physique. Les lieux sortant
du viewport peuvent toujours quitter l'écran. Les zones très denses conservent
des textes superposés atténués ; ce plan choisit l'opacité et non un masquage.

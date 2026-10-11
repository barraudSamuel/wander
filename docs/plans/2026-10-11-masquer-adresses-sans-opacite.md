---
title: "Masquer les adresses superposées sans opacité"
status: completed
date: 2026-10-11
approved_at: 2026-10-11
completed_at: 2026-10-11
owner: Samuel
tags: [plan, map, saved-places]
---

# Masquer les adresses superposées sans opacité

## Résultat et accord

Samuel demande de supprimer l'opacité et approuve le plan révisé avec « je valide ».
Les favoris visibles restent à 100 %. Les autres sont entièrement masqués.
Conserver l'ordre stable par identifiant et les rectangles des favoris masqués
pour empêcher les cascades de réapparition pendant le dézoom. Garder la marge
de sortie de collision et la priorité des marqueurs sociaux et de la sélection.

## Périmètre et étapes

- `wander/MapAnnotations.swift` : remplacer alpha par la visibilité demandée à
  Mapbox ; préserver le masquage pendant la synchronisation des coordonnées.
- `wanderTests/SavedPlaceAnnotationTests.swift` : vérifier le masquage réel,
  l'absence de séquence masqué-visible-masqué pendant le même dézoom, la pleine
  opacité, la sélection, le zoom avant et la marge de sortie.
- `wanderUITests/NaverImportUITests.swift` : adapter le scénario dense au
  masquage sans chevauchement et à l'ouverture d'une fiche.
- Ce plan dans `docs/plans/`, constats dans `todos/` si nécessaire.
- Obsidian `Documentation UX.md`, section « Import d'une liste Naver ».
- Obsidian `Documentation technique.md`, section « Favoris Naver locaux ».

Vault : `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander`.
Actualiser `updated`, préserver les wikilinks, ne pas ouvrir Obsidian.
Pas de modification de données, Firebase, contrôles natifs ou dépendances.
Préserver le travail antérieur. Aucun Git modifiant le dépôt.

## Risques et validation

Les rectangles masqués réservent encore leur place : la carte peut montrer
moins de favoris qu'un placement greedy, en échange d'une visibilité stable.
Les favoris masqués redeviennent visibles quand suffisamment de place se libère.
Ne pas laisser la synchronisation des coordonnées réafficher un favori en collision.
Valider avec le style local et le vrai moteur Mapbox, les trois cafés reproduisant
la cascade, la liste dense et la sélection. Vérifier le zoom avant et le retour
à la visibilité des favoris. Seulement le simulateur iPhone 17 Pro existant
`C0DADF07-7E14-4D5E-AE4B-B17844A9C454`, texte standard. Compilation et tests
ciblés via Xcode CLI si XcodeBuildMCP reste indisponible, revue et `git diff --check`.
Pas de test sur iPhone physique ni avec la liste privée exacte de Samuel.

## Checklist

- [x] Plan approuvé.
- [x] Adapter le test, constater son échec avec l'opacité actuelle.
- [x] Remplacer l'atténuation par le masquage complet.
- [x] Valider les tests natifs et le scénario UI dense.
- [x] Simplifier et revoir le changement ciblé.
- [x] Actualiser les notes Obsidian et terminer le plan après validation.

## Mise en œuvre et revue

Le calcul conserve l'ordre stable et tous les rectangles de collision, mais
utilise `ViewAnnotation.visible` au lieu de l'alpha. Les écritures sont gardées
par comparaison ; les callbacks restent regroupés sur la file principale.
La synchronisation des coordonnées préserve le masquage des favoris valides.
Sélection, marge de sortie de 4 pt, priorité sociale et réapparition au zoom
avant sont couvertes par le test natif.

Le premier test dense a révélé un autre chevauchement au bord gauche : Mapbox
renvoie `(-1, -1)` pour une coordonnée hors écran. Ce point était traité comme
une projection réelle et des textes hors champ restaient visibles. Le calcul
rejette maintenant ces points et masque le marqueur entier. Le test natif
couvre aussi une coordonnée valide hors champ puis son retour.
Référence : [source officielle MapboxMap.point(for:)](https://raw.githubusercontent.com/mapbox/mapbox-maps-ios/main/Sources/MapboxMaps/Foundation/MapboxMap.swift).

Revue de simplification sur trois axes (réutilisation, qualité, efficacité),
puis revue ciblée du traitement hors champ : aucun constat restant. Revue
manuelle limitée au changement approuvé, afin de préserver les travaux déjà
présents dans le dépôt. Aucun fichier de constat nécessaire dans `todos/`.
Les connaissances sont conservées dans le commentaire, le test, ce plan et la
documentation technique ; pas de fiche supplémentaire dans `docs/solutions/`.
XcodeBuildMCP indisponible : validation équivalente via Xcode CLI.

## Validation

- Échec attendu du test avec l'ancien code : « An overlapping café must be
  fully hidden, not faded », journal `/tmp/wander-hidden-red.log`.
- Version finale : 63 tests natifs et le test UI dense réussis, journal
  `/tmp/wander-hidden-final.log`, résultat
  `Test-wander-2026.10.11_16-09-01-+0900.xcresult`.
- Les deux autres tests UI Naver réussissent aussi sur le code final :
  seuils des libellés et import/réimport sans doublons. Journal
  `/tmp/wander-hidden-other-ui.log`, résultat
  `Test-wander-2026.10.11_16-11-55-+0900.xcresult`. Total : 66 tests distincts.
- Commande commune : `xcodebuild -project wander.xcodeproj -scheme wander
  -configuration Debug -destination 'platform=iOS Simulator,id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454'
  -parallel-testing-enabled NO -collect-test-diagnostics never
  -disableAutomaticPackageResolution test`, filtrée avec `-only-testing:` sur
  SavedPlaceAnnotationTests, MapSocialProximityControllerTests,
  MapEdgeZoomControllerTests et les trois parcours UI Naver cités.
- Le scénario natif échantillonne le dézoom continu, vérifie le masquage réel,
  l'alpha à 1, l'absence de réapparition temporaire, la sélection, le zoom avant,
  les marqueurs sociaux et les coordonnées invalides ou hors champ.
- Le scénario UI vérifie une liste de 36 favoris, l'absence de chevauchement,
  l'ouverture et la fermeture d'une fiche, puis le dézoom. Les deux captures
  avant/après sont exportées dans `/tmp/wander-hidden-success-captures/` et
  inspectées : favoris visibles sans chevauchement, sans atténuation.
- Les deux notes Obsidian sont actualisées avec leur propriété `updated`.
- Aucun avertissement de compilation Swift ; les messages d'extraction
  AppIntents signalent seulement l'absence de cette dépendance.
- `git diff --check` réussi ; aucune commande Git modifiant le dépôt exécutée.
- Pas de validation sur l'iPhone physique ni sur la liste exacte de Samuel.

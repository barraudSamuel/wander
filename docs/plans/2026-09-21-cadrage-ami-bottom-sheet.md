---
title: "Cadrer l’ami à l’ouverture et après fermeture de sa fiche"
status: completed
date: 2026-09-21
approved_at: 2026-09-21
completed_at: 2026-09-21
owner: Samuel
approval: "je valide, après le plan corrigé sans suivi du redimensionnement"
tags: [plan, ios, map, friends]
---

# Cadrage de l’ami et bottom sheet

Le cadrage d’ouverture décrit ci-dessous est remplacé par le repli approuvé dans
`2026-09-21-supprimer-double-cadrage-ami.md`. La vidéo utilisateur a révélé deux
mouvements successifs. Le décalage après présentation est retiré ; le recentrage
après fermeture est conservé. Les résultats de compilation ci-dessous restent
ceux de cette première version, pas une validation visuelle.

## Résultat approuvé

À l’ouverture, le pin de l’ami est centré dans la partie de carte visible au-dessus
de la feuille. Modifier sa hauteur ne déplace pas la caméra. Après disparition
complète de la feuille, une courte animation recentre la carte disponible sur cet
ami, en conservant zoom, orientation et inclinaison.

Aucun changement de modèle, de Firebase ou de style. La taille native de MapKit
reste stable. Le recentrage ne doit pas remplacer la sélection d’un autre ami ou
événement, suivre une position devenue indisponible, ni contrarier un geste manuel.

## Fichiers concernés

- `wander/FriendProfileSheet.swift` : observation ponctuelle de la présentation native.
- `wander/ContentView.swift` : requêtes à l’ouverture et après fermeture, revalidation.
- `wander/DebugSocialMapScenario.swift` : même liaison avec données locales.
- `wander/MapWithFogView.swift` : consommation des demandes et annulation sur geste.
- `wander/MapViewportView.swift` : calcul de la zone réellement disponible si nécessaire.
- `wander/MapSocialProximityController.swift` : adaptation du focus ami si nécessaire.
- `wander/MapFriendCameraController.swift` : cadrage ponctuel et animation courte.
- `wanderTests/MapFriendCameraControllerTests.swift`, `wanderTests/MapViewportViewTests.swift`,
  `wanderTests/MapSocialProximityControllerTests.swift` et `wanderUITests/MapSocialGestureUITests.swift` :
  couverture pertinente à adapter ou ajouter, compilée sans exécution.
- `docs/plans/2026-09-21-cadrage-ami-bottom-sheet.md` : suivi et validation.
- `todos/060-ready-p2-valider-profils-bottom-sheet.md` : couverture fonctionnelle différée.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md`

## Mise en œuvre

- [x] Mesurer la limite native de la fiche une fois son ouverture terminée.
- [x] Déclencher un cadrage unique au-dessus de cette limite ; ignorer les redimensionnements.
- [x] Après `onDismiss`, recentrer rapidement sur l’ami encore disponible sans le sélectionner à nouveau.
- [x] Conserver la priorité des gestes et des nouvelles sélections.
- [x] Adapter le scénario et compiler l’application et les cibles de tests.
- [x] Simplifier, relire et mettre à jour les notes Obsidian et le suivi.

## Risques et validation

Les coordonnées du bord de feuille et de MapKit doivent partager le même repère.
Ne pas calculer une moitié d’écran fixe. Ignorer les callbacks d’une ancienne fiche.
Éviter tout recentrage continu pendant son glissement. Le recadrage de fermeture
attend la disparition effective et conserve les paramètres de caméra.

Samuel a limité la validation à la compilation : aucun test exécuté, aucun
simulateur démarré, aucune capture. Les tests de géométrie et de cycle de demande
seront compilés. Le rendu et le ressenti de l’animation restent à vérifier lors
d’une validation fonctionnelle autorisée. Les changements non commités du travail
précédent sont conservés ; aucune commande Git modificatrice.

## Résultat de compilation et revue

- Compilation finale réussie le 21 septembre 2026, après correction de la
  sélection native différée. Application, tests unitaires et tests UI compilés.
  Commande exacte :

  ```sh
  xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution -skipPackageUpdates CODE_SIGNING_ALLOWED=NO build-for-testing
  ```

- Journal : `/tmp/wander-friend-camera-final-build.log`, `TEST BUILD SUCCEEDED`.
  Aucun avertissement du compilateur Swift. Avis préexistants d’extraction
  AppIntents sans dépendance au framework. Aucun test exécuté.
- `git diff --check` réussi. Aucun changement dans `MapViewportView` ou
  `MapSocialProximityController` nécessaire.
- Simplification selon `ce-simplify-code` : réutilisation relue par un agent,
  qualité et efficacité relues directement après limite de capacité des agents.
  Aucun changement de simplification appliqué. Une suggestion de réutiliser
  `ZoomSession` est écartée : la session valide d’autres entrées et compose
  différemment interpolation et bornage aux limites de la projection. Le calcul
  commun `anchoredCenter` est déjà réutilisé ; l’équivalence complète n’est pas
  démontrée sans exécution.
- Revue de correction locale indépendante et lecture directe de l’incrément.
  Le calcul de périmètre de `ce-code-review` repose sur une base Git et ne peut
  isoler cet incrément parmi les changements précédents non commités. La revue
  équivalente utilise les copies avant modification dans
  `/tmp/wander-friend-camera-before/`, sans toucher à Git.
- Défaut relevé et corrigé : sélectionner nativement l’ami déjà focalisé, une
  fois son pin visible, ne doit pas annuler le cadrage en cours. Les nouvelles
  sélections et les gestes continuent de l’annuler.
  La seconde lecture indépendante confirme la correction, sans autre défaut
  retenu. L’absence de scénario exécuté pour cette sélection différée reste
  couverte par la validation depuis la liste dans le suivi 060.
- Les trois notes Obsidian approuvées ont été mises à jour, propriété `updated`
  incluse. Le suivi `todos/060-ready-p2-valider-profils-bottom-sheet.md` précise
  les vérifications fonctionnelles différées. Aucune nouvelle solution générale
  n’est publiée sans validation du comportement en exécution.

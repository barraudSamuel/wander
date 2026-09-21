---
title: "Mesurer la fiche et cadrer directement l’ami"
status: completed
date: 2026-09-21
approved_at: 2026-09-21
completed_at: 2026-09-21
approval: "je valide, après le plan de mesure anticipée et caméra unique"
owner: Samuel
tags: [ios, friends, map, plan]
---

# Mesure anticipée et caméra unique

## Contrat approuvé

Mesurer le contenu dans la largeur native avant l’affichage de la feuille,
fixer le palier compact à cette mesure, puis déplacer directement le pin dans
la carte découverte. Aucun centrage intermédiaire, aucun recalage après ouverture
ou redimensionnement. Conserver zoom, orientation et inclinaison. Après fermeture
complète, recentrer sur l’ami en 0,22 seconde. Ne pas revenir au centrage simple.

## Mise en œuvre

Le contenu SwiftUI partagé est mesuré via `UIHostingController.sizeThatFits`.
Un adaptateur UIKit dans la feuille native configure son palier avant affichage,
avec la largeur réelle lors du cycle `viewIsAppearing`. Le contenu mesuré et le
contenu visible ont les mêmes paramètres. UIKit reste propriétaire des marges,
du glissement et de la fermeture. La géométrie finale native fournit la cible,
pas une estimation de pourcentage d’écran. Aucun callback `viewDidAppear`.

Les accès ami, y compris les groupes et indicateurs hors champ, délèguent
leur cadrage au contrôleur de caméra ; la sélection MapKit ne centre plus seule
l’ami. Les événements et la position personnelle gardent leur comportement.
Les gestes manuels et nouvelles sélections gardent la priorité.

## Fichiers

- `wander/FriendProfileSheet.swift` : contenu partagé, mesure et préparation native.
- `wander/ContentView.swift`, `wander/DebugSocialMapScenario.swift` : liaison présentation/caméra.
- `wander/MapWithFogView.swift`, `wander/MapSocialProximityController.swift` : sélection sans centrage intermédiaire.
- `wander/MapFriendCameraController.swift` : demande unique d’ouverture et de fermeture.
- `wanderTests/MapFriendCameraControllerTests.swift`, `wanderTests/MapSocialProximityControllerTests.swift`,
  `wanderTests/FriendProfilePresentationTests.swift`, `wanderUITests/MapSocialGestureUITests.swift` : couverture compilée.
- Ce plan et `todos/060-ready-p2-valider-profils-bottom-sheet.md`.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md`

## Checklist

- [x] Mesure commune, hauteur compacte fixée avant affichage.
- [x] Géométrie native transmise une seule fois à l’ouverture.
- [x] Tous les accès ami routés sans commande MapKit intermédiaire.
- [x] Projection et animation directe, fermeture conservée.
- [x] Compilation application et tests, revue ciblée de l’incrément.
- [x] Notes Obsidian et suivi actualisés.

## Risques et validation

Le point sensible est l’ordre entre préparation de la feuille, mise en page
native et démarrage de caméra. Vérifier les sélections différées et ne pas
déclencher un deuxième mouvement quand une annotation devient visible.
Mesurer à la largeur réelle, borner au maximum natif, garder le défilement.

Samuel limite la validation à la compilation. Aucun test exécuté ni simulateur
démarré. Compiler les tests de géométrie, mesure et commandes de caméra ; ne pas
présenter leur compilation comme une vérification visuelle de l’animation.
Les fichiers déjà modifiés appartiennent au même travail approuvé, préservés
dans `/tmp/wander-prepared-profile-before/`. Aucun changement Git ni publication.

## Décisions de réalisation

- La mesure utilise les traits et la largeur de la feuille dans la première
  transaction d’apparition native. `UISheetPresentationController.animateChanges`
  résout son cadre avant retour, dans un bloc sans animation supplémentaire.
  La mesure n’est pas relancée après `viewDidAppear`, au redimensionnement ou
  lors d’une mise à jour de position. Le défilement absorbe un contenu ultérieur
  plus haut. Source API : en-tête public UIKit `UISheetPresentationController.h`
  du SDK installé.
- Les données affichées et mesurées sont le même `FriendProfileBody`. Les traits
  de texte, langue, sens de lecture et couleurs sont transmis aux deux hôtes.
  L’hôte de mesure est vidé après préparation pour ne pas conserver de contenu
  dupliqué pendant la vie de la fiche.
- Le callback de préparation est la seule source de demande d’ouverture. Les
  sélectionneurs gardent leur responsabilité de focus sans lancer de caméra
  pour les amis. Une sélection native différée ne reconfigure pas la même fiche.
- Les tests précédents ne comptaient pas les commandes intermédiaires. Le nouveau
  test de `MapSocialProximityController` surveille `setCenter` et `setRegion`
  pour pins, groupes et hors champ. Les tests natifs de préparation vérifient le
  callback avant fin de présentation, la hauteur et l’absence de répétition.
  Aucun résultat d’exécution n’est revendiqué : tests compilés seulement.
- Simplification : trois lectures indépendantes, un ajustement de réutilisation
  d’environnement et un ajustement d’efficacité appliqués. Aucun autre changement
  retenu par ces trois passes.

## Validation finale et revue

- Compilation finale réussie : `xcodebuild -project wander.xcodeproj -scheme wander
  -configuration Debug -destination 'generic/platform=iOS Simulator'
  -disableAutomaticPackageResolution -skipPackageUpdates CODE_SIGNING_ALLOWED=NO
  build-for-testing`. Résultat `TEST BUILD SUCCEEDED`, journal local
  `/tmp/wander-prepared-profile-final-build.log`.
- Application et cibles de tests compilées ; aucun test exécuté, aucun simulateur
  démarré. Aucun avertissement Swift ni erreur. Deux avis du processeur App Intents
  indiquent que l’extraction des métadonnées est ignorée en l’absence de dépendance
  `AppIntents.framework`.
- `git diff --check` réussi. Aucun changement de l’index ou de l’historique Git.
- Revue de correction indépendante limitée au diff contre la sauvegarde de cet
  incrément : aucun défaut bloquant étayé. Points examinés : préparation native,
  commande unique par ouverture, sélections différées, chemins pin/groupe/liste/
  hors champ, priorité des gestes et recentrage après fermeture.
- Le parcours complet de `ce-code-review` n’a pas été exécuté : son résolveur de
  portée repose sur des plages Git qui incluraient les incréments précédents,
  et sa revue externe n’était pas autorisée dans ce travail. La revue ciblée
  manuelle ci-dessus constitue la vérification réalisée, sans receipt complet
  revendiqué.
- Les trois notes Obsidian prévues ont été actualisées avec leur propriété
  `updated`. La validation visuelle reste explicitement ouverte dans le suivi
  `todos/060-ready-p2-valider-profils-bottom-sheet.md` ; la compilation ne prouve
  pas le rendu de la première image ni la trajectoire observée sur appareil.

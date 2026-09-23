---
title: Corriger la réserve basse des listes sous le dock
status: completed
date: 2026-09-23
approved_at: 2026-09-23
reapproved_at: 2026-09-23
completed_at: 2026-09-23
owner: Samuel Barraud
related:
  - 2026-09-23-reserver-bas-listes-carte.md
tags: [plan, ux, safe-area]
---

# Corriger la réserve basse des listes sous le dock

## Résultat

La dernière ligne de chaque liste Amis et Événements défile entièrement
au-dessus de la barre native. Pendant le défilement, les lignes passent derrière
le dock jusqu'au bas de l'écran. La carte, les poignées et les contrôles restent
utilisables pendant l'ouverture et le redimensionnement des listes.

## Contexte

La capture et la vidéo de Samuel du 23 septembre montrent encore une ligne
Amis masquée par le dock, même après défilement. Le premier correctif a compilé
sans validation visuelle. Sur l'iPhone 17, UIKit mesure correctement le dock à
799,3 points et transmet 77,7 points de réserve au panneau, mais la liste
occupe toujours la fenêtre jusqu'à 874 points. Le défaut se situe donc dans
la zone visible et défilante de la liste, après la transmission de la marge.

## Périmètre

Conserver la mesure du bord supérieur réel de la barre native et ajouter
uniquement une marge en fin de contenu défilant. Les listes occupent toute la
hauteur du panneau, y compris derrière le dock. Retirer les correctifs précédents qui ne servent
plus une fois la solution validée. Ne pas changer les actions, les services,
les modèles ou le style natif. Préserver tous les changements locaux antérieurs.
Samuel a approuvé l'utilisation de l'iPhone 17 Simulator existant.

## Fichiers concernés

- `wander/NativeMapTabView.swift` : calculer la réserve depuis la barre native.
- `wander/MapDetailSplitView.swift` : laisser les listes occuper toute la hauteur du panneau.
- `wander/FriendsPanelView.swift`, `wander/MapEventsPanelView.swift` : réserver
  l'espace de défilement final si le conteneur commun ne suffit pas.
- `wander/DebugSocialMapScenario.swift` : garder le scénario local représentatif
  si un inset doit être appliqué directement aux listes.
- `wanderUITests/MotionDockUITests.swift` : contrôler les deux listes face au dock.
- Ce plan et d'éventuels constats de revue dans `todos/`.
- Vault `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Documentation UX.md` et `Documentation technique.md`, propriété `updated` comprise.

## Implémentation

- [x] Mesurer le bord supérieur réel de la barre et constater l'échec du placement.
- [x] Retirer la coupure et le padding extérieur qui arrêtaient les lignes au-dessus du dock.
- [x] Corriger les assertions UI pour vérifier l'ouverture et la dernière ligne
      des listes Amis et Événements.
- [x] Nettoyer les mesures temporaires et les correctifs devenus inutiles.
- [x] Recompiler l'app et les cibles de tests après le retour utilisateur.
- [x] Vérifier les deux listes sur l'iPhone 17 existant, derrière le dock et en fin de défilement.
- [x] Relire le diff, mettre à jour les notes Obsidian et consigner les résultats.

## Risques et validation

La barre peut changer de position avec le clavier ou les dimensions de la
fenêtre : recalculer la réserve à chaque layout UIKit, sans constante fixe.
Contrôler que la liste ne reçoit pas un double inset et que la carte conserve
sa hauteur de rendu native. Ne pas créer, télécharger ou démarrer d'autre
simulateur. Exécuter les tests UI pertinents sur l'iPhone 17 si le scénario
local le permet ; sinon décrire précisément la vérification manuelle.

## Acceptation

La dernière ligne de chaque liste peut être affichée entièrement au-dessus
du dock sur l'iPhone 17, après défilement. Les lignes intermédiaires continuent
derrière le dock jusqu'au bas de l'écran. La compilation réussit sans nouveau
diagnostic Swift et `git diff --check` passe.

## Validation et revue

La capture utilisateur de 11 h 35 invalide la validation précédente : la fin de
liste restait accessible, mais les lignes intermédiaires étaient coupées à la
limite du dock. La correction demandée retire ce découpage et le padding
extérieur. Seul `contentMargins` garde de l'espace en fin de contenu.

### Validation finale après correction

- Trois tests UI réussis sur l'iPhone 17, iOS 26.3.1 : fin de liste Amis,
  fin de liste Événements et ouverture/fermeture depuis le bouton calendrier.
  Commande ci-dessous complétée par
  `-only-testing:wanderUITests/MotionDockUITests/testEventsButtonSitsBesideNativeTabsAndTogglesList`.
- Résultat :
  `/tmp/wander-derived-data/Logs/Test/Test-wander-2026.09.23_11-41-26-+0900.xcresult`.
  Captures contrôlées à l'ouverture et après défilement : les lignes passent
  derrière la barre, puis les dernières lignes Alex et Sortie 18 remontent
  entièrement au-dessus.
- La liste utilise maintenant toute la hauteur du panneau. Suppression du
  `.clipped()` et du padding extérieur inférieur ajoutés au correctif précédent.
  Conservation de la seule marge de fin de contenu dans les deux `List`.
- Les assertions contrôlent le panneau jusqu'au bas de la fenêtre et la
  dernière ligne réellement visible. Le test Amis cible la cellule Alex,
  y compris son statut, et non une ligne précédente ou un texte sans cadre visible.
- Compilation et `git diff --check` réussis. Notes UX et technique Obsidian
  corrigées. Aucun constat de revue restant pour cette correction.

### Validation précédente

- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug
  -destination 'platform=iOS Simulator,id=6F13855D-10B8-45AF-9205-17C8393379E3'
  -derivedDataPath /tmp/wander-derived-data -disableAutomaticPackageResolution
  -parallel-testing-enabled NO
  -only-testing:wanderUITests/MotionDockUITests/testBottomOfEventsListClearsNativeDock
  -only-testing:wanderUITests/MotionDockUITests/testBottomOfFriendsListClearsNativeDock
  test -quiet` : deux tests réussis le 23 septembre 2026 sur l'iPhone 17.
- Captures finales conservées dans le résultat
  `/tmp/wander-derived-data/Logs/Test/Test-wander-2026.09.23_11-27-00-+0900.xcresult` :
  « Sortie 18 » et « Alex » entièrement au-dessus du dock.
- `git diff --check` : aucune erreur. La compilation des tests et de l'app
  n'a produit aucun nouveau diagnostic Swift. Les essais de masquage, les
  mesures temporaires et le paramètre de débogage inutile ont été retirés.
- Revue : aucun nouveau constat priorisé. `Documentation UX.md` et
  `Documentation technique.md` du vault Wander ont été actualisées, avec leur
  propriété `updated`.

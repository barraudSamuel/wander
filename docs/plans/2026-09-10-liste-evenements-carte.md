---
title: "Liste permanente des événements au-dessus de la carte"
status: completed
date: 2026-09-10
approved_at: 2026-09-10
completed_at: 2026-09-10
owner: Samuel
tags: [plan, ios, events, navigation]
---

# Liste permanente des événements

Samuel a approuvé le plan présenté dans la conversation par « j'approuve ».

## Résultat et périmètre

Afficher par défaut les événements accessibles du compte et de ses amis, même
hors écran, par date croissante. La séparation agrandit la liste ; celle-ci
défile indépendamment. Une sélection ouvre la fiche existante et synchronise la
carte. Revenir des fiches événement ou ami retrouve la liste et sa position.
Participation, modification, annulation et itinéraire réutilisent les parcours
actuels. Les panneaux Amis/Profil préservent cet état.

Un seul incrément. La création et le périmètre d'accès aux événements restent
ceux du produit actuel. Aucune modification du schéma ou des règles Firebase.

## Fichiers concernés

- `wander/ContentView.swift` : panneau permanent et sélection depuis la liste.
- `wander/MapEventsPanelView.swift` : nouvelle liste native et conservation de son état.
- `wander/MapDetailSplitView.swift` : accessibilité de la séparation et retour.
- `wander/OutingPlanDetailCardView.swift` : retour aux événements.
- `wander/OutingPlanService.swift` : état de chargement et erreurs des observations.
- `wander/DebugSocialMapScenario.swift` : scénarios de liste et états locaux.
- `wanderUITests/MapSocialGestureUITests.swift` : nouveaux parcours et attentes adaptées.
- `wanderUITests/MotionDockUITests.swift` : attente de panneau permanent après fermeture.
- Le présent plan ; constats de revue dans `todos/` ; fiche dans `docs/solutions/`
  seulement si une leçon réutilisable est vérifiée.
- Vault `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Backlog features.md` (En cours), `Documentation UX.md` (Fiches et carte partagée,
  Sorties prévues), `Documentation technique.md` (Carte, Événements et participations,
  Validation), `00 - Wander.md` (État du projet). Actualiser `updated` et conserver
  les wikilinks. Le vault existe mais est hors des racines inscriptibles du sandbox ;
  demander l'accès par le mécanisme d'escalade si nécessaire, sans créer de copie.

## Étapes

- [x] Enregistrer l'approbation.
- [x] Ajouter la liste persistante et les états chargement/erreur/vide.
- [x] Brancher les fiches et la sélection carte, conserver hauteur et défilement.
- [x] Adapter les scénarios locaux et tests de régression.
- [x] Compiler et valider sur l'iPhone 17 déjà démarré, puis relire le diff.
- [x] Actualiser documentation et constats avec les résultats exacts.

## Risques et validation

Les gestes de liste, de séparation et de carte doivent rester indépendants.
Conserver la taille de rendu MapKit évite les régressions Metal déjà corrigées.
Une sortie annulée ou devenue inaccessible doit ramener à la liste. Le chargement
ne doit pas être présenté comme une liste vide et une erreur partielle doit rester
visible avec les événements chargés. Ne pas multiplier les observations de participants
pour afficher la liste.

Critères : liste présente au lancement ; ordre stable ; agrandir révèle davantage
de lignes ; défilement et retour préservés ; fiches accessibles depuis liste et carte ;
actions existantes fonctionnelles ; panneaux Amis/Profil préservés ; états vide,
chargement, erreur traités ; textes agrandis utilisables.

Build Debug et tests UI ciblés sur l'iPhone 17 existant, captures et revue visuelle.
Les scénarios DEBUG valident l'interface avec des données locales ; ils ne prouvent
pas l'exécution des écritures Firebase authentifiées. Aucun Git mutant.

## Validation et revue

### Relecture manuelle

- La liste utilise exactement le périmètre de `mapOutingPlans`, sans tri géographique
  ni nouvelles observations de participants. Les identifiants stabilisent le tri
  lorsque deux dates sont égales.
- La liste reste montée sous la fiche, avec masquage visuel, tactile et accessible.
  Le maintien de `MapDetailSplitView` conserve aussi la hauteur. Le centrage depuis
  une ligne utilise la demande existante, sans modifier le rendu MapKit.
- Les états de chargement/erreur sont nettoyés lors du retrait d’un propriétaire,
  de l’arrêt des observations et du changement de compte. Les jetons existants
  écartent les réponses obsolètes. La relance ne recrée que les listeners en erreur.
- Choix principal : préserver les contrôles natifs pour conserver le défilement.
  Restaurer manuellement un offset après recréation aurait ajouté une dépendance
  aux mesures de lignes et à Dynamic Type.
- Simplification : le bouton de retour utilise une option explicite, sans
  nouveau routeur ni dépendance d’interface.
- Limite : Firestore authentifié reste à vérifier, consigné
  dans `../../todos/047-ready-p2-valider-liste-evenements-compte-reel.md`.
- Leçon réutilisable : `../solutions/2026-09-10-conserver-liste-sous-fiche-carte.md`.

### Historique de validation

Premier build Debug réussi. Avertissements déjà présents dans le projet :
métadonnées AppIntents et `CFBundleVersion` des extensions `15`/`27` face à l’app
`39`. Aucun nouvel avertissement Swift. Journal `/tmp/wander-events-build.log`.

La première passe de dix tests a révélé deux attentes à adapter : la collection
native masquée reste présente dans l’arbre XCTest, et le geste de rail en paysage
visait l’ancien centre d’une carte plein écran. Les tests corrigés vérifient
l’absence d’interaction et visent la portion visible de la carte. Les huit autres
tests passent, dont actions, annulation, états de liste, conservation du défilement,
fiches d’amis et panneaux du dock. Résultat `/tmp/wander-events-tests.xcresult`.

La passe complémentaire valide sept contrôles sur huit, dont les deux corrections,
la liste et les actions en très grande police, le paysage, le rail et la stabilité
du rendu MapKit. Le test des raccourcis devait aussi accepter que réduit et tiers
atteignent la même borne minimale sur un petit espace : il vérifie maintenant
une réduction depuis la taille agrandie, puis la conservation de la borne et du
retour. Sa reprise isolée réussit dans `/tmp/wander-events-resize-test.xcresult`.

La revue des captures a identifié un chevauchement des SF Symbols décoratifs avec
le texte à la taille d’accessibilité maximale. Ils sont désormais masqués à ces
tailles pour réserver la largeur au texte. La capture portrait après correction
confirme des lignes lisibles, avec davantage de place pour la date. La première
reprise du test d’accessibilité dépasse le délai de rotation de cinq secondes.
Les diagnostics montrent seulement le SIGTERM de fin de test après l’échec, sans
crash préalable. Le contrôle est relancé seul, sans reconstruction.


### Résultat final

Les quinze tests UI distincts ci-dessous ont tous réussi. Après le blocage global
persistant de la rotation sur les deux parcours, l’iPhone 17 existant a été arrêté
puis redémarré, sans effacement ni création de simulateur. Les deux parcours de
paysage passent alors avec le même binaire, dans
`/tmp/wander-events-rotation-restored.xcresult` et son journal
`/tmp/wander-events-rotation-restored.log`. Les captures finales de très grande
police sont dans `/tmp/wander-events-verified-captures/` et ont été relues.

Validation : `xcodebuild -project wander.xcodeproj -scheme wander -configuration
Debug -destination 'platform=iOS Simulator,id=6F13855D-10B8-45AF-9205-17C8393379E3'
-disableAutomaticPackageResolution -parallel-testing-enabled NO`, avec les
sélections `-only-testing` détaillées par les journaux et les méthodes ci-dessous.
Les reprises de rotation utilisent `test-without-building` sur le binaire validé.

- `MapSocialGestureUITests/testCompactGuestActionsAndMapRemainAvailableWithLargeText`
- `MapSocialGestureUITests/testDockPanelsPreserveResizedMapDetail`
- `MapSocialGestureUITests/testEventListCanRespondAndCancelWithoutMapTap`
- `MapSocialGestureUITests/testEventListEmptyLoadingAndErrorStates`
- `MapSocialGestureUITests/testEventListIsDefaultAndSorted`
- `MapSocialGestureUITests/testEventListResizeScrollAndReturnPreservePosition`
- `MapSocialGestureUITests/testEventListWithLargeTextAndLandscape`
- `MapSocialGestureUITests/testEventPaneDragResizesMapAndKeepsSelection`
- `MapSocialGestureUITests/testMixedGroupOpensFriendAboveMap`
- `MapSocialGestureUITests/testNativeMapRenderSizeStaysStableAcrossPaneChanges`
- `MapSocialGestureUITests/testPermanentPanelAndMapFillWindowBehindMotionDock`
- `MapSocialGestureUITests/testResizeButtonCyclesSizesAndReturnPreservesPanel`
- `MotionDockUITests/testKeyboardAndDraftSurvivePanelSwitch`
- `MotionDockUITests/testOutsideTapOnlyClosesPanelAndPreservesCamera`
- `MotionDockUITests/testUsesNativeTabBarAndSupportsPressThenSlide`

Les quatre notes Obsidian ont été mises à jour directement dans le vault avec
leur propriété `updated`, sans ouvrir Obsidian. Les contrôles finaux de structure
et de références au plan passent. `git diff --check` passe. Aucun nouveau warning
Swift ; les avertissements de versions d’extensions et AppIntents préexistants
restent consignés ci-dessus. La validation Firebase authentifiée
est suivie dans le constat 047.

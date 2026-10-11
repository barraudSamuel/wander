---
title: "Position des actions de la carte"
status: completed
date: 2026-10-11
approved_at: 2026-10-11
completed_at: 2026-10-11
owner: Samuel
tags: [plan, map, ux]
---

# Position des actions de la carte

## Ajustement approuvé le 11 octobre

Samuel a approuvé le retour du + à sa hauteur initiale, aligné avec le calendrier.
Les deux actions restent à droite ; l'espacement initial du viseur en plein écran
est rétabli et sa remontée avec le split est conservée. Cet ajustement remplace
la réserve verticale ajoutée sous le +. Vérifier le chevauchement éventuel avec ⓘ
sans déplacer d'autre contrôle hors de ce périmètre.

- [x] Supprimer le décalage vertical de 36 points du +.
- [x] Rétablir l'espacement du viseur en plein écran.
- [x] Vérifier l'alignement avec le calendrier et le split sur le simulateur existant.
- [x] Corriger la note UX et consigner la validation de cet ajustement.

Les validations ci-dessous décrivent la première version ; les résultats de
l'ajustement seront ajoutés séparément.

### Validation de l'ajustement

Compilation Debug et test ciblé
`MapSocialGestureUITests/testMapActionsStayRightAndRecenterFollowsResizedMap`
réussis sur le même iPhone 17 Pro, avec une nouvelle assertion vérifiant
l'alignement vertical du + et du calendrier. Le test couvre aussi le déplacement
du viseur, le + fixe pendant le split, l'agrandissement, la fermeture et la création.
Commande exacte et journal : `/tmp/wander-actions-baseline-height.log`.
Résultat : `/tmp/wander-actions-baseline-height.xcresult`.
Capture plein écran vérifiée :
`/tmp/wander-actions-baseline-height-captures/ADB15134-1FCB-404F-8B9E-A7303750DB5B.png`.

Le contrôle visuel confirme un chevauchement partiel du + sur ⓘ en plein écran.
Ce point est consigné dans `todos/081-pending-p2-attribution-sous-plus.md` ; aucun
autre contrôle n'a été déplacé. L'ajustement demandé est terminé, mais le critère
initial d'absence de chevauchement de l'attribution n'est plus satisfait.

Simplification du petit ajustement de placement : aucune abstraction ou retouche
supplémentaire. Revue locale des deux constantes de placement et de l'assertion :
pas d'autre anomalie. `git diff --check` réussi. Note Obsidian mise à jour à
`2026-10-11T17:32:50+09:00`. Aucune nouvelle validation sur appareil physique.

## Résultat et périmètre

Plan approuvé dans le chat par « je valide ». Placer le + et le viseur à
16 points du bord droit sûr. Garder le + en bas de l'écran et faire suivre
au viseur le bas de la carte visible pendant l'ouverture, le redimensionnement
et la fermeture de la liste des événements. Conserver les contrôles natifs et
l'accès à l'attribution Mapbox. Aucun changement de données ou de caméra.

## Fichiers concernés

- `wander/NativeMapTabView.swift` : marge du + et transmission de l'action de recentrage.
- `wander/MapDetailSplitView.swift` : viseur ancré dans la carte visible.
- `wanderUITests/MapSocialGestureUITests.swift` : régression de placement.
- Ce plan : suivi et résultats.
- `todos/080-done-p2-viseur-profil-carte-reduite.md` : constat visuel corrigé.
- Obsidian `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md` : sections création et recentrage, propriété `updated`.

## Dépendances et approche

Réutiliser les actions du dock et la géométrie animée du split. Le viseur doit
être un overlay de la carte, pas du contrôleur plein écran. Réutiliser le même
bouton natif pour les deux actions. Réserver l'espace de l'attribution sous les
boutons à droite. Pas de nouvelle dépendance, de modification Git ou de refonte.

## Mise en œuvre

- [x] Ajouter une vérification ciblée du placement dans le scénario existant.
- [x] Corriger les deux ancrages et conserver les callbacks existants.
- [x] Conserver assez de hauteur de carte pour éviter le chevauchement du viseur et du profil lorsque la liste est agrandie.
- [x] Simplifier et relire le diff limité à ce travail.
- [x] Compiler et valider sur l'iPhone 17 Pro déjà lancé.
- [x] Mettre à jour la documentation UX Obsidian.

## Risques et critères d'acceptation

- Le viseur reste dans la carte et suit le glissement du séparateur.
- Le + reste en bas ; les deux actions sont alignées à droite.
- Les actions, la poignée et l'attribution restent utilisables sans chevauchement.
- Vérifier la carte complète, le split, son agrandissement et sa fermeture.
- Préserver les modifications préexistantes de ContentView, DebugSocialMapScenario,
  OutingPlanComposerView, SavedPlace, SavedPlaceDetailView, SavedPlaceTests,
  NaverImportUITests et le plan événement depuis adresse.

## Validation

Simulateur existant : iPhone 17 Pro, iOS 26.3,
`C0DADF07-7E14-4D5E-AE4B-B17844A9C454`. Aucun autre simulateur créé ou démarré.

- Échec initial confirmé : marge visible du + de 61 points. Résultat
  `/tmp/wander-actions-red.xcresult` et journal `/tmp/wander-actions-red.log`.
- Compilation Debug et 20 tests ciblés réussis, 0 échec : 9 tests
  `MapUserCameraControllerTests`, 7 tests `MapViewportViewTests`, 4 tests UI.
- Tests UI : `testMapActionsStayRightAndRecenterFollowsResizedMap`,
  `testEventListHandleResizesThenFoldsBackToFullMap`,
  `testEventsButtonOpensListBelowMapWithoutChangingNativeSize` et
  `testEventsButtonStaysCenteredAcrossRepeatedListToggles`.
- Commande : `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug
  -destination 'id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454'
  -disableAutomaticPackageResolution -parallel-testing-enabled NO
  -maximum-concurrent-test-simulator-destinations 1`, avec `-only-testing:` pour
  les classes et méthodes ci-dessus, `test` et
  `-resultBundlePath /tmp/wander-actions-final.xcresult`.
- Journal complet et commande exacte : `/tmp/wander-actions-final.log`.
- Captures vérifiées : carte complète
  `/tmp/wander-actions-final-captures/C133317A-D489-4D10-8411-5331C112382A.png`,
  split redimensionné
  `/tmp/wander-actions-final-captures/166E992A-DB55-41C7-8015-7377437F1856.png`,
  liste agrandie
  `/tmp/wander-actions-final-captures/F484BB55-7064-45F2-A5A3-69C6C3F829DC.png`.
- `git diff --check` réussi. Aucun nouvel avertissement Swift ; l'avertissement
  préexistant AppIntents « Metadata extraction skipped » reste présent.
- Note Obsidian mise à jour avec accès autorisé, sections création/recentrage,
  `updated: 2026-10-11T17:24:38+09:00`, wikilinks conservés, sans ouvrir Obsidian.
- `ce-test-xcode` sans connecteur XcodeBuildMCP disponible : validation équivalente
  effectuée avec xcodebuild et simctl. Aucun test dédié d'accessibilité.
- Limites : pas de test sur iPhone physique, ni de test dédié du clavier ou du paysage.

## Revue

Décision principale : ancrer le viseur dans le split pour éviter une synchronisation
manuelle de coordonnées entre SwiftUI et UIKit. Une remontée fixe à l'ouverture
aurait échoué pendant le glissement du séparateur.

Les trois lectures de simplification n'ont proposé aucun changement.
Revue ce-code-review lite sur les trois fichiers de code/test du correctif,
avec les critères AGENTS.md : aucune anomalie restante. Le chevauchement profil/viseur
observé sur la première capture est corrigé et consigné dans le todo 080.
Reçu : `/tmp/wander-actions-review/report.md`.

Pas de nouvelle note de solution pour cet ajustement courant de placement.
Aucune commande Git de mutation exécutée, aucun commit créé.

---
title: Actions événement par balayage natif
status: completed
date: 2026-09-11
approved_at: 2026-09-11
completed_at: 2026-09-11
owner: Samuel
---

# Résultat approuvé

Samuel approuve « faisons ça » après la proposition de gestes iOS natifs.
Toucher une ligne sélectionne et centre l’événement sans ouvrir de fiche ni
révéler d’actions. Glisser à gauche révèle Participer / Refuser pour un invité,
ou Modifier pour l’organisateur. Ces actions existent aussi par appui long,
avec Itinéraire. Une réponse referme les actions selon le comportement natif.
Les boutons superposés à la carte sont retirés. La liste conserve son défilement.

## Périmètre

- `wander/MapEventsPanelView.swift` : réutiliser les `swipeActions`, partager les
  actions autorisées avec le menu contextuel ; libellé court Refuser.
- `wander/ContentView.swift`, `wander/DebugSocialMapScenario.swift` : retirer les
  boutons de carte. Préserver la sélection, les filtres et le centrage existants.
- `wander/MapEventActionsView.swift` : supprimer le composant devenu inutilisé.
- `wanderUITests/MapSocialGestureUITests.swift` : remplacer les attentes de boutons
  flottants par les gestes natifs et vérifier les cibles indépendantes du centrage.
- `wanderTests/MapEventListPresentationTests.swift` : réutiliser les tests existants.
- Ce plan, résultats de revue dans `todos/` si nécessaire.
- Vault Wander : `Backlog features.md`, `Documentation UX.md`,
  `Documentation technique.md`. Mettre à jour les sections actions événement et
  validation ainsi que `updated`, en conservant les wikilinks.

## Étapes

- [x] Accord sur la recommandation finale et son périmètre déjà présenté.
- [x] Retirer les superpositions et partager les actions natives.
- [x] Adapter les tests et effectuer les trois revues de simplification.
- [x] Compiler et tester les parcours sur l’iPhone 17 déjà démarré.
- [x] Actualiser les trois notes et consigner les résultats exacts.

## Risques et validation

Répondre par balayage à une ligne différente de celle centrée doit agir sur la
ligne balayée. Ni le balayage ni l’appui long ne doivent recentrer la carte.
Le clic ne doit afficher ni boutons ni fiche. Le swipe complet ne valide pas
de réponse ; les états de chargement/indisponibilité/envoi retirent les réponses.
Vérifier les deux décisions, la fermeture native, le menu d’appui long, l’édition
organisateur, le défilement et le recentrage répété. Build Debug, tests unitaires
de présentation et tests UI ciblés, avec capture standard.
La rotation paysage déjà en échec reste suivie dans 051 ; cette modification
n’élargit pas le périmètre au conteneur de rotation. Pas de nouveaux tests dédiés
d’accessibilité, de runtime, de schéma ou de service Firebase. Aucun Git mutant.
Les changements préexistants de cette conversation sont conservés, sauf les
boutons de carte explicitement remplacés ici. L’ancien plan décrit l’itération
précédente ; ce plan constitue le comportement courant.

## Résultats

`eventActions(for:)` définit les boutons une seule fois pour le swipe et le menu
contextuel. Il réutilise les contrôles d’éligibilité existants et conserve
l’identifiant de la ligne. Les superpositions sont retirées de la production et
du scénario ; le composant flottant est supprimé. Les filtres restent accessibles.

Trois revues de simplification terminées : aucun changement de réutilisation ou
performance nécessaire. Les propositions de reformulation du texte de test et
de regroupement d’assertions historiques n’ont pas été retenues, sans bénéfice
pour le comportement de cette modification. Aucun garde de réponse n’est retiré.

Les tests UI existants ont été adaptés au nouveau contrat, avec un parcours
supplémentaire pour le menu contextuel. La validation s’effectue après modification,
sans passage rouge préalable, pour vérifier ensemble les gestes natifs et le
rendu réel. Les tests de présentation existants restent inchangés.

Les trois notes Obsidian sont mises à jour, avec `updated: 2026-09-11` et les
résultats exacts. La rotation reste un suivi distinct déjà documenté dans 051 ;
les échanges Firebase authentifiés et les emoji du simulateur restent suivis
dans 047/048. Aucun service Firebase n’a été modifié.

### Validation du 2026-09-11

Compilation Debug et 11 tests de `MapEventListPresentationTests` réussis.
Sept parcours de `MapSocialGestureUITests` réussis, zéro échec :

- `testEventListSelectionRecentersAfterMapPan`
- `testEventListCanRespondAndCancelWithoutMapTap`
- `testEventContextMenuRespondsWithoutChangingMapSelection`
- `testGuestSwipeActionsRespondAtEverySize`
- `testUnavailableAndUpdatingParticipationKeepsDirectionsAccessible`
- `testCompactListUnknownOrUpdatingResponseCannotBeSwiped`
- `testListScrollAfterSelectionKeepsActionsHidden`

Commande commune :

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'platform=iOS Simulator,id=6F13855D-10B8-45AF-9205-17C8393379E3' \
  -derivedDataPath /tmp/wander-social-cluster-derived-data \
  -disableAutomaticPackageResolution -parallel-testing-enabled NO \
  -resultBundlePath /tmp/wander-native-event-actions.xcresult \
  -only-testing:wanderTests/MapEventListPresentationTests \
  -only-testing:wanderUITests/MapSocialGestureUITests/testEventListSelectionRecentersAfterMapPan \
  -only-testing:wanderUITests/MapSocialGestureUITests/testEventListCanRespondAndCancelWithoutMapTap \
  -only-testing:wanderUITests/MapSocialGestureUITests/testEventContextMenuRespondsWithoutChangingMapSelection \
  -only-testing:wanderUITests/MapSocialGestureUITests/testGuestSwipeActionsRespondAtEverySize \
  -only-testing:wanderUITests/MapSocialGestureUITests/testUnavailableAndUpdatingParticipationKeepsDirectionsAccessible \
  -only-testing:wanderUITests/MapSocialGestureUITests/testCompactListUnknownOrUpdatingResponseCannotBeSwiped \
  -only-testing:wanderUITests/MapSocialGestureUITests/testListScrollAfterSelectionKeepsActionsHidden test
```

Journal : `/tmp/wander-native-event-actions.log`. Captures exportées dans
`/tmp/wander-native-event-actions-screens/` et inspectées : actions natives dans
la ligne, carte conservée, aucune fiche narrative ni boutons flottants.
Capture : `7A957FAE-F5F2-4A86-A306-F2E014C8C85D.png`.

La revue a identifié un manque de couverture explicite du swipe complet (052).
Le test des trois hauteurs utilise maintenant un drag de 95 % à 5 % de la
largeur ; il vérifie la réponse inchangée avant toucher du bouton. Rejoué seul
avec la même commande commune, uniquement ce sélecteur et le résultat
`/tmp/wander-native-event-full-swipe.xcresult` : un test réussi, zéro échec.
Journal : `/tmp/wander-native-event-full-swipe.log`. Constat 052 terminé.
Les six autres parcours et les tests unitaires restent inchangés.

`ce-test-xcode` indisponible dans cette session : validation équivalente par
`xcodebuild` sur le simulateur autorisé. Aucun test dédié d’accessibilité ajouté.
`git diff --check` réussi. Aucun Git mutant exécuté.

### Revue finale

Six revues locales (correction, Swift/iOS, conventions du projet, tests,
maintenabilité et contre-vérification) conservées dans
`/tmp/ce-code-review-native-event-actions-20260911/`. Le seul constat porte sur
la couverture du swipe complet, corrigée et validée dans
`todos/052-done-p2-verifier-swipe-complet-evenement.md`.
Aucun défaut de production retenu. La vérification externe n’a pas été relancée.
Les critères du parcours portrait approuvé sont satisfaits ; les limites
préexistantes restent suivies séparément.

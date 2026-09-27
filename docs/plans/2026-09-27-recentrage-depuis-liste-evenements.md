---
title: Recentrage depuis la liste des événements
status: completed
date: 2026-09-27
completed_at: 2026-09-27
owner: Samuel
---

# Recentrage depuis la liste des événements

Samuel a explicitement validé le plan dans la conversation.

## Résultat et périmètre

Toucher le corps d'une carte événement recentre la carte géographique sur
son lieu avec animation. La liste reste ouverte, à la même hauteur et à la
même position de défilement. Un nouvel appui sur le même événement permet
de le recentrer après déplacement de la carte. Les boutons Modifier,
Participer, Refuser et Itinéraire restent indépendants.

## Approche et fichiers

- `wander/MapEventsPanelView.swift` : action native sur le contenu de la carte,
  distincte des boutons du pied de carte.
- `wander/ContentView.swift` : sélectionner l'événement et transmettre la
  demande de recentrage existante, sans demande de défilement de la liste.
- `wander/MapWithFogView.swift` et `wander/MapSocialProximityController.swift` :
  distinguer le callback natif d'une sélection demandée par le code afin de
  ne pas déclencher en retour le défilement réservé aux appuis sur les repères.
- `wander/DebugSocialMapScenario.swift` : brancher le même recentrage dans le
  scénario local utilisé par les tests UI.
- `wanderTests/MapSocialProximityControllerTests.swift` : vérifier qu'une
  sélection silencieuse ne neutralise pas le recentrage demandé par l'utilisateur.
- `wanderUITests/MapSocialGestureUITests.swift` : couvrir le recentrage et
  sa répétition, préserver les assertions sur la stabilité du panneau et
  les actions existantes.
- Ce plan de suivi et `todos/` si la revue révèle un finding.
- Coffre `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Documentation UX.md`, Sorties prévues ; `Documentation technique.md`,
  Événements et participations ; `Backlog features.md`, Valider les cartes
  événements autonomes. Actualiser `updated` et préserver les wikilinks.

## Étapes

- [x] Approbation du plan.
- [x] Relier l'appui à la demande de recentrage existante.
- [x] Adapter les tests fonctionnels et relire le changement.
- [x] Compiler ; aucun iPhone 17 démarré, parcours non exécutés.
- [x] Mettre à jour les trois notes et consigner la validation.

## Risques et validation

Éviter un conflit entre appui, défilement et boutons de réponse. Vérifier
l'existence de l'événement au déclenchement. Ne pas appeler le parcours
de sélection d'un repère qui remonte la liste jusqu'à l'événement.
Préserver les descriptions accessibles avec un contrôle natif.
Compiler l'app et les tests. Vérifier recentrage, nouvel appui après déplacement,
maintien du panneau et indépendance des boutons sur l'iPhone 17 déjà démarré
si disponible. Aucun démarrage, création ou téléchargement de simulateur,
aucun test d'accessibilité dédié. Documenter toute validation indisponible.

## Critères d'acceptation

Action native reliée au lieu de l'événement, demande répétable, aucun changement
de hauteur ou de défilement imposé, boutons indépendants, compilation réussie,
revue et notes à jour. Tests compilés et limites signalées si aucun simulateur
n'est actif. Aucun changement Git ; préserver les modifications préexistantes.

## Résultat et revue

Le contenu principal utilise un `Button` natif `.plain` avec zone rectangulaire
et libellé « Afficher … sur la carte ». Les boutons du pied sont ses frères,
jamais imbriqués. Le callback `showOutingOnMap` ne touche ni `bottomList` ni
`eventScrollRequest` et vérifie encore l'existence de l'événement.
Le binding de recentrage existant est consommé puis remis à nil par la carte,
ce qui autorise une nouvelle demande pour le même événement.

La revue a relevé qu'une sélection MapKit en attente peut aussi provenir d'un
appui sur un membre de groupe. Le correctif introduit une intention silencieuse
explicite, réservée aux sélections externes ; un recentrage utilisateur conserve
le callback qui cible la ligne. Finding corrigé :
`todos/069-done-p2-preserver-selection-evenement-groupe.md`.
Le test du contrôleur vérifie qu'un recentrage utilisateur remplace l'intention
silencieuse, même pour une demande déjà en attente.

`ce-code-review` : revue ciblée sur les copies prises avant ce travail,
finding initial corrigé puis nouvelle revue `status: complete`, `Ready to merge`,
aucun finding restant. Reçu : `/tmp/wander-list-center-review/final-review.json`.
La passe de simplification n'a pas retenu de modification supplémentaire.
Les scénarios existants de groupe et de boutons indépendants sont conservés.

## Validation exacte

- `xcrun simctl list devices booted -j` : aucun simulateur démarré.
- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build-for-testing` : code 0, `TEST BUILD SUCCEEDED`, avant puis après le correctif de revue.
- Journal final : `/tmp/wander-list-center-final-build.log`.
- Aucun diagnostic Swift. Deux avertissements d'extraction AppIntents
  préexistants lors du dernier passage. Le premier passage signalait aussi
  les écarts de versions des extensions déjà observés avant ce travail.
- `git diff --check` réussi.
- Test UI adapté : `testCardBodyRecentersAfterMapPanAndRepeatedTap`.
- Test contrôleur ajouté : `testSilentEventSelectionDoesNotSilenceLaterUserCentering`.
- Tests compilés seulement, ni exécution rouge/verte ni rendu revendiqués.
  Aucun simulateur démarré, aucun test d'accessibilité dédié.
- Trois notes Obsidian mises à jour, frontmatter `updated` actualisé et
  wikilinks comparés avant/après. Obsidian n'a pas été ouvert.

Le point le plus délicat était la boucle de sélection native qui pouvait
faire défiler la liste en retour. Un booléen lié uniquement à l'événement
dans `ContentView` ou une temporisation auraient confondu un nouvel appui
utilisateur avec une sélection tardive ; l'intention accompagne la demande
du contrôleur existant. La principale limite restante est la vérification
tactile et visuelle sur simulateur ou appareil. Aucun commit ni publication.

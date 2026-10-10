---
title: "Menu de création sur la carte"
status: blocked
date: 2026-10-10
owner: Samuel
tags: [plan, map, ux]
---

# Menu de création sur la carte

Plan présenté en conversation et explicitement approuvé par Samuel le 10 octobre 2026.

## Résultat et périmètre

Ajouter un bouton + natif en bas à droite de la carte, sous le crosshair,
avec 12 points d’écart dans une colonne commune. Il ouvre une feuille
sans titre ni bouton de fermeture, avec « Créer un événement », « Importer des adresses » et
« Créer un groupe d’amis ». Le premier choix ouvre le formulaire existant.
Les deux autres restent désactivés avec la mention « Bientôt », comme approuvé.
Pas de nouveau modèle de données, de parcours d’import ou de groupes.

Le centre du + est aligné sur celui des événements. Leurs contraintes communes
suivent le clavier et restent indépendantes de la hauteur de la liste.

## Fichiers concernés

- `wander/ContentView.swift` : bouton, présentation et transition vers le formulaire.
- `wander/MotionDockView.swift` : transmettre les actions de création et de recentrage.
- `wander/NativeMapTabView.swift` : aligner le centre du + sur celui du bouton événements.
- `wander/CreationMenuView.swift` : liste native des choix et fermeture.
- Ce plan : suivi et preuves de validation.
- Notes Obsidian sous `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/` :
  `Backlog features.md` et `Documentation UX.md`, avec leur propriété `updated`.
- `todos/` uniquement si la revue révèle un problème non résolu.

## Mise en œuvre

Gabarit et animation d’appui identiques au crosshair explicitement approuvés
par Samuel le 10 octobre 2026.

- [x] Uniformiser le cadre des deux icônes et conserver le retour d’appui natif du +.
- [x] Garder une protection contre les ouvertures multiples sans désactiver le + à l’appui.
- [x] Compiler, revoir les changements et actualiser la documentation.

Alignement horizontal du + et du bouton événements explicitement approuvé
par Samuel le 10 octobre 2026. Le crosshair reste 12 points au-dessus du +.

- [x] Ancrer les contrôles à droite dans le même conteneur que les événements.
- [x] Compiler, vérifier les contraintes et les régressions de navigation/clavier.
- [x] Actualiser le plan, le finding 076 et les notes Obsidian UX/backlog.

Suppression du titre et de la croix explicitement approuvée par Samuel
le 10 octobre 2026. La feuille conserve sa poignée et sa fermeture par glissement.

- [x] Retirer le titre, la croix et la barre de navigation du menu.
- [x] Compiler et actualiser les notes de fermeture.

Placement révisé explicitement approuvé par Samuel le 10 octobre 2026.

- [x] Déplacer le + sous le crosshair et actualiser les notes de placement.
- [x] Compiler le placement révisé et inspecter les marges des contrôles.

- [x] Ajouter le bouton et la feuille native.
- [x] Ouvrir le formulaire après la fermeture du menu.
- [x] Simplifier et revoir les changements.
- [ ] Compiler et vérifier les interactions sur le simulateur déjà lancé.
- [x] Mettre à jour les deux notes Obsidian.

## Risques et validation

Prévenir les présentations simultanées. Conserver les contrôles de carte,
le calendrier et le recentrage utilisables sans chevauchement.
Vérifier ouverture, fermeture, réouverture, choix d’événement et annulation.
Inspecter les deux options désactivées et leur mention « Bientôt ».
Utiliser uniquement le simulateur iPhone 17 déjà démarré, à taille de texte standard.

Changement local et réversible d’interface : pas de nouveau test dédié.
Les tests existants `MotionDockUITests` et les vérifications interactives
servent de validation. Aucun test d’accessibilité dédié.

## Revue

- Décision principale : fermer la feuille de choix avant le formulaire existant.
- Alternative écartée : créer les parcours import/groupes, hors périmètre approuvé.
- Le formulaire existant exige une coordonnée. Le menu annonce « À ma position
  actuelle » et transmet celle-ci. Sans position, il désactive ce choix et
  explique l’appui long existant sur la carte pour choisir un lieu.
- Simplification `ce-simplify-code` : trois lectures indépendantes, aucune
  simplification retenue. Le marqueur de brouillon est nettoyé si un profil
  interrompt l’ouverture du formulaire.
- Revue `ce-code-review` lite : `/tmp/wander-menu-review/review.json`.
  Pas de défaut de code restant identifié. Validation interactive incomplète.
- Compilation Debug réussie sur `C0DADF07-7E14-4D5E-AE4B-B17844A9C454`,
  iPhone 17 Pro déjà démarré, iOS 26.3. Journal :
  `/tmp/wander-creation-build.log`. Aucun avertissement Swift ; Xcode signale
  seulement l’extraction de métadonnées AppIntents ignorée, faute de dépendance.
- Installation et lancement réussis. L’app ouvre l’écran de connexion Apple.
  Le scénario `DebugSocialMapScenarioView` utilise une vue distincte de
  `ContentView` et ne prouve pas le fonctionnement de ce menu.
- XcodeBuildMCP absent : validation équivalente avec `xcodebuild`, `simctl`
  et observation de Device Hub par l’outil de contrôle d’interface.
- Les deux notes Obsidian sont mises à jour avec `updated` et leurs liens conservés.
  Obsidian n’a pas été ouvert.
- Aucun nouvel apprentissage réutilisable à ajouter dans `docs/solutions/`.
- Deux tests UI existants réussissent, 0 échec :
  `MotionDockUITests/testEventsButtonReplacesNavigationBar` et
  `MotionDockUITests/testEventsButtonStaysCenteredAcrossRepeatedListToggles`.
  Commande : `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' -disableAutomaticPackageResolution -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -only-testing:wanderUITests/MotionDockUITests/testEventsButtonReplacesNavigationBar -only-testing:wanderUITests/MotionDockUITests/testEventsButtonStaysCenteredAcrossRepeatedListToggles test`.
  Journal : `/tmp/wander-creation-tests.log`. Ces tests protègent la navigation
  existante, mais ne couvrent pas le nouveau menu.
- Statut `blocked` uniquement pour la validation interactive nécessitant une
  session Apple connectée ; implémentation, compilation, revue et documentation
  terminées. Suivi : `todos/076-ready-p2-valider-menu-creation-carte.md`.
- Placement précédent, remplacé par l’ancrage commun aux événements : colonne
  native à droite, crosshair puis +, espacement
  de 12 points. Le + reprend l’ancien emplacement du crosshair et les marges
  existantes ; le crosshair remonte au-dessus. Revue statique : actions,
  libellés et désactivation conservés, styles natifs mutualisés sur la colonne.
- Nouvelle compilation Debug réussie après déplacement :
  `/tmp/wander-creation-placement-build.log`, même destination et options que
  la compilation précédente. `git diff --check` réussi. Pas de nouveau test
  pour ce changement de disposition ; la vérification interactive reste
  consignée dans le finding 076. Les deux notes Obsidian décrivent le nouvel emplacement.
- Cette compilation signale aussi des versions d’extensions non alignées
  (`CFBundleVersion` 15 et 27, app 53), en plus des avis AppIntents.
  Aucun réglage de version n’a été modifié pour ce déplacement.
- En-tête retiré après approbation : `NavigationStack`, titre, barre de navigation,
  croix et environnement de fermeture inutilisé supprimés. La liste reste
  directement dans la feuille native ; la poignée et le glissement de fermeture
  sont conservés. Le texte en cas de position indisponible explique ce geste.
- Compilation Debug réussie après suppression de l’en-tête, même commande et
  destination : `/tmp/wander-creation-header-build.log`. Avis AppIntents seulement.
  `git diff --check` réussi. Revue statique : actions et fermeture différée vers
  le formulaire conservées. Pas de nouveau test pour cette suppression d’en-tête.
  Notes Obsidian et finding 076 actualisés ; validation interactive toujours en attente.
- Alignement approuvé : les deux boutons natifs sont hébergés par
  `NativeMapTabController`. Le centre vertical du + est contraint à celui des
  événements ; le crosshair partage son centre horizontal et reste 12 points
  au-dessus. Une marge droite de 56 points réserve l’accès à l’attribution Mapbox.
  Leurs dimensions restent celles des contrôles SwiftUI natifs.
- `MapDockActions` transmet les callbacks depuis `ContentView` via `MotionDockView`.
  L’activation de la création conserve ses restrictions de présentation ; le
  recentrage reste actif comme avant. Le scénario local sans ces actions masque
  les deux contrôles. Il ne permet donc pas de vérifier le nouvel alignement visuellement.
- Simplification : trois lectures indépendantes. Mutualisation des boutons
  conservée. Proposition de cache des vues non retenue : deux petits contrôles,
  aucun coût mesuré, et leur mise à jour garde les callbacks courants sans état
  supplémentaire. Revue lite : `/tmp/wander-alignment-review/review.json`.
- Aucun test ajouté pour ce changement de disposition ; vérification statique
  des contraintes et tests UI existants de navigation et de clavier.
- Deux tests passent sur le simulateur existant, 0 échec :
  `MotionDockUITests/testEventsButtonStaysCenteredAcrossRepeatedListToggles` et
  `MotionDockUITests/testFriendInvitationsLiveInProfileAndDraftSurvivesClosing`.
  Journal : `/tmp/wander-creation-alignment-tests.log`, résultat :
  `Test-wander-2026.10.10_11-47-40-+0900.xcresult` dans les Logs/Test du DerivedData
  existant. Commande identique au test ciblé précédent avec ces deux sélecteurs.
  La séparation finale de l’activation du recentrage et de la création a été
  compilée après ce test ; le scénario testé n’active pas ces callbacks.
- Compilation finale réussie : `/tmp/wander-creation-alignment-final-build.log`.
  Installation et lancement réussis sur le même simulateur. Avis AppIntents
  et versions des extensions 15/27 contre 53 déjà signalés précédemment.
  `git diff --check` réussi. Observation finale de Device Hub : écran de connexion
  Apple toujours affiché ; le statut reste `blocked` pour la validation visuelle
  du menu et de l’alignement, suivie dans le finding 076.
- Gabarit et appui : les images + et scope disposent du même cadre de 24 × 24
  points dans le composant natif partagé. Style glass, forme circulaire et
  controlSize large communs. L’ouverture du menu ne désactive plus le + ;
  un garde-fou dans son action ignore les appuis lorsque le menu est déjà ouvert.
  Les restrictions liées au formulaire, au profil et aux opérations de compte
  sont conservées. Aucun délai ni animation personnalisée ajouté.
- Compilation Debug réussie après ces ajustements :
  `/tmp/wander-creation-press-build.log`, même destination et options que les
  compilations précédentes. Avis AppIntents seulement. `git diff --check` réussi.
  Revue statique des deux chemins d’activation et de la géométrie commune effectuée.
  Aucun nouveau test pour cet ajustement local d’interface ; comparaison visuelle
  de taille et d’appui toujours à réaliser sur une session connectée, finding 076.
  Notes UX et backlog Obsidian mises à jour avec leur propriété `updated`.

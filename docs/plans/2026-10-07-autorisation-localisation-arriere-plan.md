---
title: "Refléter l’autorisation réelle de localisation en arrière-plan"
status: in_progress
date: 2026-10-07
approved_at: 2026-10-07
owner: Samuel
tags: [plan, location]
---

# Autorisation de localisation en arrière-plan

## Résultat et approbation

Samuel a approuvé dans le chat le plan proposé le 7 octobre 2026.
L’option « Continuer en arrière-plan » conserve l’intention de l’utilisateur,
mais ne doit plus laisser croire que l’autorisation iOS « Toujours » est
accordée lorsqu’elle manque. Le statut et le raccourci Réglages rendent la
configuration incomplète explicite.

## Constat

`setBackgroundTrackingEnabled` persiste le choix avant la réponse système.
La demande Always est présente pour WhenInUse, mais la demande initiale
WhenInUse n’est pas suivie d’Always. Le profil ne propose Réglages qu’en cas
de refus ou restriction. Aucune reproduction sur l’iPhone de Samuel n’a été
effectuée ; ces chemins sont confirmés par lecture du code.

Apple limite la demande de surclassement. Un refus conservant WhenInUse ne
déclenche pas de changement d’autorisation, et Allow Once empêche le
surclassement. Source :
https://developer.apple.com/documentation/corelocation/cllocationmanager/requestalwaysauthorization()

## Périmètre

- Séparer le choix utilisateur et l’autorisation réelle dans l’affichage.
- Proposer Réglages pour un suivi demandé sans Always.
- Poursuivre une demande initiale explicitement engagée, sans relancer de
  demande lors d’un simple démarrage ou retour des Réglages.
- Rafraîchir l’autorisation au retour au premier plan.
- Conserver les capacités existantes WhenInUse et les conditions du partage.
- Pas de modification Firebase, de nouvel onboarding ni de collecte supplémentaire.

## Fichiers concernés

- `wander/LocationTracker.swift` : parcours et état d’autorisation.
- `wander/ProfilePanelView.swift` : état natif et accès aux Réglages.
- `wander/ContentView.swift` : rafraîchissement au retour au premier plan si nécessaire.
- `wanderTests/LocationTrackerTests.swift` : couverture ciblée du parcours.
- Ce plan, un constat de validation dans `todos/` et une leçon dans `docs/solutions/` si pertinente.
- Coffre `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  - `Backlog features.md` : état de la correction et validations restantes.
  - `Documentation technique.md` : section Exploration et localisation.
  - `Documentation UX.md` : sections Réglages et Permissions et confidentialité.
  - Mettre à jour `updated`, préserver les wikilinks. Ne pas ouvrir Obsidian.

## Mise en œuvre

- [x] Approbation explicite reçue avant toute écriture.
- [x] Implémenter le parcours de permission et son annulation.
- [x] Afficher l’autorisation réelle et le raccourci Réglages.
- [x] Vérifier par lecture la synchronisation au retour au premier plan.
- [x] Ajouter et exécuter les sept tests de logique dans un paquet iOS isolé.
- [x] Simplifier et revoir le diff de cette correction uniquement.
- [x] Mettre à jour la documentation et consigner les limites de validation.
- [x] Compiler l’application complète et exécuter les tests intégrés.
- [ ] Valider le rendu et le parcours système dans l’application et sur appareil.

## Risques et validation

- iOS décide de l’affichage des dialogues ; ne jamais considérer la demande
  comme une autorisation obtenue, ni attendre uniquement un callback de refus.
- Ne pas retirer le suivi WhenInUse déjà possible en arrière-plan.
- Tester première demande, acceptation, refus, annulation, retour des Réglages,
  révocation et préférence restaurée sans sollicitation automatique.
- Compiler et exécuter les tests pertinents sur l’iPhone 17 déjà démarré
  uniquement. Ne créer ni démarrer un autre simulateur.
- Confirmer le dialogue et les réglages système sur appareil réel ; les tests
  de logique ne remplacent pas cette vérification.
- Pas de tests d’accessibilité dédiés. Préserver les contrôles natifs.
- Le coffre Obsidian est hors des racines d’écriture autorisées par défaut :
  demander l’escalade ciblée pour les trois notes approuvées, sinon consigner
  les sections restant à mettre à jour ici et dans le constat.

## État initial et contraintes

Travail dans le checkout existant. Les commandes Git mutatrices sont interdites
par les accords de Samuel ; aucune branche ni aucun commit ne sera créé.
Modifications préexistantes exclues : projet Xcode (version 50), assets des
boutons événements, `MapEventsPanelView.swift`, `MapSocialGestureUITests.swift`,
plans du 28 septembre sur les boutons et icônes événements.

## Critères d’acceptation

- Un suivi demandé avec WhenInUse affiche explicitement Always manquant.
- L’accès aux Réglages est disponible sans désactiver/réactiver le bouton.
- Une transition de permission actualise l’interface et la condition du partage.
- Une demande initiale est poursuivie une fois et peut être annulée.
- Les tests ciblés passent ; toute limite appareil/simulateur est documentée.

## Validation effectuée

### Première compilation complète : bloquée par H3, puis débloquée

Commande exécutée dans le dépôt :

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'platform=iOS Simulator,id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' -parallel-testing-enabled NO -disableAutomaticPackageResolution -resultBundlePath /private/tmp/wander-location-permissions-tests.xcresult -only-testing:wanderTests/LocationTrackerTests test
```

Résultat : `TEST FAILED`, avant compilation de la correction, avec
`The package product 'H3-product' cannot be used as a dependency of this target
because it uses unsafe build flags.` Le manifeste résolu de H3Swift contient
`.unsafeFlags(["-w"])`. Aucun changement de dépendance ni de projet effectué
par cette intervention. Journal : `/private/tmp/wander-location-permissions-tests.log`.

### Vérifications ciblées : réussies

- `xcrun swiftc -frontend -parse wander/LocationTracker.swift wander/ProfilePanelView.swift wander/ContentView.swift wanderTests/LocationTrackerTests.swift` : succès.
- `git diff --check` : succès.
- Sept tests XCTest de `BackgroundAuthorizationRequest`, extraite textuellement
  du fichier de production dans `/private/tmp/wander-location-authorization-efa0auex`.
  Le fichier de tests y est copié sans modification. Seule l’enveloppe de type
  est réduite pour isoler cette logique de H3 et Firebase.
- Exécution finale iOS :

```sh
cd /private/tmp/wander-location-authorization-efa0auex
xcodebuild -scheme WanderLocationAuthorizationChecks-Package -destination 'platform=iOS Simulator,id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' -parallel-testing-enabled NO -resultBundlePath /private/tmp/wander-location-isolated-ios-final.xcresult test
```

Résultat : `TEST SUCCEEDED`, 7 tests, 0 échec. Journal :
`/private/tmp/wander-location-isolated-ios-final.log`. Aucun avertissement Swift ;
Xcode indique seulement que l’extraction des métadonnées AppIntents est ignorée
dans ce paquet sans dépendance AppIntents. Une première tentative macOS de ce
paquet a échoué car WhenInUse n’est pas disponible sur macOS ; le test final
utilise le SDK iOS réel et l’iPhone 17 Pro iOS 26.3 déjà démarré.

Ces preuves ne sont pas une compilation de Wander ni une validation UI.
Aucun test de régression existant ne couvrait cette autorisation ; aucun échec
fonctionnel rouge avant modification n’est revendiqué. Le diagnostic initial
repose sur la lecture du code et la documentation Apple.

### Revue et documentation

- `ce-work` exécuté dans le checkout courant sans commande Git mutatrice,
  conformément aux accords de Samuel qui priment sur la création de branche
  et les commits suggérés par le skill.
- `ce-simplify-code` : deux duplications remplacées par les helpers existants.
  Revue réutilisation par un lecteur ; qualité et efficacité examinées localement
  après refus de lancement d’un nouvel agent pour limite de threads.
- `ce-test-xcode` : XcodeBuildMCP absent ; équivalent CLI employé selon AGENTS.md.
- `ce-code-review` : protocole multi-agent complet indisponible après limite de
  threads ; revue équivalente locale avec les deux contextes de lecture
  disponibles, l’un parcours/permissions/cycle de vie et l’autre UI/plan.
  Aucun défaut concret introduit relevé. Pas de reçu complet de revue CE ni de
  revue cross-model revendiqués. Les tests couvrent la logique de demande,
  pas le branchement réel du delegate, la vue ou les Réglages.
- `ce-compound` évalué : pas de leçon supplémentaire écrite, car la validation
  intégrée est bloquée et le raisonnement utile est déjà dans le plan, les
  commentaires, les tests et les notes techniques.
- Notes Obsidian mises à jour dans le coffre existant : Backlog features,
  Documentation technique, Documentation UX ; propriété `updated` actualisée.
- Validation restante consignée dans
  [071](../../todos/071-ready-p2-valider-autorisation-arriere-plan.md).

### Validation intégrée après correction de H3

Le [plan H3 distinct approuvé](2026-10-07-corriger-dependance-h3.md) a remplacé
la dépendance distante par une copie locale de la même révision. La compilation
Debug de l'application complète réussit. Les sept tests de
`wanderTests/LocationTrackerTests` passent désormais dans le projet Wander,
sans extraction dans un paquet temporaire.

Commande finale :

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'platform=iOS Simulator,id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' -parallel-testing-enabled NO -disableAutomaticPackageResolution -resultBundlePath /private/tmp/wander-h3-fix/final-tests.xcresult -only-testing:wanderTests/LocationTrackerTests -only-testing:wanderUITests/MotionDockUITests/testEventsButtonStaysCenteredAcrossRepeatedListToggles test
```

Résultat : huit tests exécutés et réussis, zéro échec ou test ignoré, sur
l'iPhone 17 Pro existant, iOS 26.3.1. Le test UI supplémentaire vérifie
l'ouverture de la carte et de la liste d'événements avec des données locales ;
il ne valide pas la feuille des permissions ni les dialogues système.
Journal : `/private/tmp/wander-h3-fix/final-tests.log`.

Le plan revient à `in_progress`, sans `completed_at`. Le blocage de compilation
est levé ; le rendu des permissions, les retours des Réglages et le parcours
sur appareil réel restent suivis dans le constat 071.

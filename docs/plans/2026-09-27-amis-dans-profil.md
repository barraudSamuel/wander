---
title: "Intégrer les amis au profil personnel"
status: completed
date: 2026-09-27
completed_at: 2026-09-28T09:11:29+09:00
owner: Samuel
---

# Intégrer les amis au profil personnel

## Outcome

Le profil personnel réunit les demandes reçues, les amis, les demandes envoyées,
le code ami et l'ajout par code dans un seul défilement. Le bouton Amis et son
panneau sous la carte disparaissent. Explorer et Événements restent disponibles.

## Scope et décisions

- Réutiliser les sections et actions existantes dans le formulaire du profil.
- Ouvrir la fiche d'un ami depuis cette liste avec les règles de carte actuelles.
- Rediriger les notifications de demandes vers le profil et rendre les demandes visibles.
- Retirer le mode amis du panneau partagé, conserver le panneau événements.
- Aucun changement de persistance, de schéma Firebase ou de règles métier.
- Dépendances : présentation native des profils et navigation UIKit existantes.

## Fichiers concernés

- `wander/ProfilePanelView.swift`, `wander/FriendsPanelView.swift`.
- `wander/ContentView.swift`, `wander/MotionDockView.swift`, `wander/NativeMapTabView.swift`, `wander/MapDetailSplitView.swift`.
- `wander/DebugSocialMapScenario.swift`.
- `wanderUITests/MotionDockUITests.swift`, `wanderUITests/MapSocialGestureUITests.swift`.
- Ce plan ; actualisation des constats existants
  `todos/061-ready-p2-valider-invitations-profil.md` et
  `todos/062-ready-p2-valider-amis-sous-carte.md` pour les essais de compte réel.
- Leçon : `docs/solutions/2026-09-27-presenter-alertes-sections-profil.md`.
- Vault `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  - `Backlog features.md` : fonctionnalité et validation.
  - `Documentation technique.md` : responsabilités des vues, navigation, notifications.
  - `Documentation UX.md` : accès aux amis, liste et demandes dans le profil.
  - `00 - Wander.md` : état du projet et nouvelle navigation.
  Mettre à jour `updated` et préserver les wikilinks. Si l'écriture est impossible,
  consigner précisément les sections restantes, sans créer de copie du vault.

## Checklist

- [x] Intégrer les sections amis au formulaire sans imbriquer deux listes.
- [x] Conserver les actions, confirmations et erreurs, et l'ouverture des fiches amis.
- [x] Supprimer l'entrée Amis et le panneau correspondant ; adapter les notifications.
- [x] Adapter le scénario local et les tests UI existants.
- [x] Simplifier et relire le changement.
- [x] Compiler et vérifier les parcours ciblés sur l'iPhone 17 déjà démarré.
- [x] Mettre à jour les quatre notes Obsidian et consigner la validation exacte.

## Risques

- Concurrence des alertes de suppression et d'ajout d'ami.
- Défilement imbriqué ou dernières lignes inaccessibles dans le profil.
- Remplacement de la feuille personnelle par une fiche ami et maintien de la carte.
- Régression du panneau événements ou de ses marges après retrait de l'onglet.

## Validation et critères d'acceptation

- Compilation Debug de l'app et des tests, sans nouveau diagnostic Swift.
- Tests UI ciblés : absence d'Amis dans le dock, liste dans le profil, demandes,
  retrait confirmé/annulé, invitation par code et brouillon conservé, ouverture
  d'un ami, réglages et retour aux événements.
- Vérifier l'état vide, le bas d'une longue liste et le chemin de notification.
- Utiliser uniquement l'iPhone 17 déjà démarré ; aucun test d'accessibilité dédié.
- Vérifier le diff et consigner les contrôles réellement exécutés.

## Autorisation et exécution

- Plan présenté dans la conversation puis approuvé par Samuel : « je valide ».
- Compétences `ce-plan` puis `ce-work`, exécution native dans le checkout courant.
- Les règles Git du propriétaire priment sur les automatismes de branche et de
  commit des compétences. Aucune commande Git mutante ni publication.
- Préexistant exclu : `docs/plans/2026-09-27-arrondi-encart-reglages.md`, déjà indexé.
- Preuve : adapter les tests de navigation existants, puis compilation et essais UI.
  Pas de cycle rouge préalable : les scénarios doivent être adaptés avec le contrat
  de navigation qui change ; les assertions porteront sur les parcours observables.

## Résultats

- Première compilation app/tests réussie, sans diagnostic Swift. Avertissements
  préexistants AppIntents et versions d’extensions.
- La première exécution a révélé deux adaptations nécessaires : porter l’alerte
  de retrait sur le Form, et préserver l’identifiant de la liste événements après
  suppression de son conteneur à deux listes. Corrections appliquées.
- Simplification par trois revues indépendantes : aucune remarque réutilisation
  ou efficacité ; suppression de la sélection d’onglet à un seul cas, de la
  contrainte de largeur redondante et du helper de test à tableau singleton.
- Revue `ce-code-review` sans constat de code résiduel ; correction de la course notification/données :
  la requête de défilement garde l’identifiant de l’amitié et suit son arrivée.
  `ProfileFriendsForm` partage le formulaire et ce chemin avec le scénario UI.
- Les quatre notes Obsidian sont finalisées avec le bilan des 23 tests réussis
  et leur propriété `updated` du 28 septembre. Les wikilinks sont conservés.
- Les tests locaux n’utilisent pas de compte Firebase réel et ne prouvent pas
  la livraison APNs ni les écritures d’amitié distantes.

- Reçu de revue : `/tmp/compound-engineering-501/ce-code-review/20260927-175911-94f39f90`.
  Huit angles examinés ; aucune publication ni modification du Git.
- Capture réutilisable validée mécaniquement :
  `docs/solutions/2026-09-27-presenter-alertes-sections-profil.md`
  (`ce-compound`, mode non interactif léger ; aucun nouveau terme dans `CONCEPTS.md`).
- Le contrôle de retour profil/événements a révélé un déplacement de la liste
  lors de son masquage à hauteur nulle. Conservation de sa hauteur native
  interne validée par le test ciblé de retour depuis un ami ; le cadre visible
  reste masqué. L’alignement supérieur évite de recentrer son contenu pendant
  l’animation du panneau. Les deux tests de notification passent également.
- Les anciennes assertions de rotation dans les parcours adaptés sont retirées :
  le projet déclare uniquement le portrait sur iPhone.

- Le diagnostic du helper de défilement a mesuré des déplacements de près de
  280 points pour des gestes de 60 à 93 points : l’inertie faisait dépasser la
  carte recherchée dans le panneau compact. L’ajustement final utilise un geste
  lent avec maintien avant relâchement. La sonde temporaire a été supprimée.

## Validation finale du 28 septembre

- Compilation et **23 tests UI réussis, 0 échec**, dans une seule passe finale.
- `MotionDockUITests` : les 16 cas de navigation, profil, demandes, notifications,
  liste vide/longue, invitation, retrait et réglages.
- `MapSocialGestureUITests` : les 7 cas indiqués dans la commande ci-dessous,
  dont conservation du défilement et de la taille native de carte, suspension
  des observations, avatar et redimensionnement du panneau événements.
- Destination unique : iPhone 17 déjà démarré, iOS 26.3.1, build 23D8133.
  Aucun simulateur créé ou démarré. Aucun test d’accessibilité dédié.
- Aucun diagnostic Swift. Les avertissements de métadonnées AppIntents sont
  préexistants et ne concernent pas ce changement.
- Capture finale inspectée :
  `/tmp/wander-profile-final-evidence/4E8CF8D4-B087-4E49-95CF-CA089750C9E1.png`.
  Résumé, demandes et amis se suivent dans le formulaire natif.
- `git diff --check` sans erreur. Aucun commit, push ou changement de branche.
- Limites maintenues dans les constats P2 existants 061 et 062 : opérations
  sociales Firebase, erreurs réseau et réception APNs avec un compte réel.

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'platform=iOS Simulator,id=6F13855D-10B8-45AF-9205-17C8393379E3' \
  -parallel-testing-enabled NO -disableAutomaticPackageResolution \
  -only-testing:wanderUITests/MotionDockUITests \
  -only-testing:wanderUITests/MapSocialGestureUITests/testDetailedListReturnsAtSameHeightAndScrollAfterFriendProfile \
  -only-testing:wanderUITests/MapSocialGestureUITests/testOwnAvatarSelectionOpensSeparateSheetAndReturnsToProfile \
  -only-testing:wanderUITests/MapSocialGestureUITests/testDockPanelsRemainAvailableAfterClosingFriendSheet \
  -only-testing:wanderUITests/MapSocialGestureUITests/testFullMapRestoresAfterEventsAndDockPanels \
  -only-testing:wanderUITests/MapSocialGestureUITests/testEventListScrollSurvivesFriendAndDockPanels \
  -only-testing:wanderUITests/MapSocialGestureUITests/testEventListRequestsRostersOnScrollAndSuspendsOutsideExplorer \
  -only-testing:wanderUITests/MapSocialGestureUITests/testEventListHandleResizesThenFoldsBackToFullMap \
  test
```

Journal : `/tmp/wander-profile-final-validation.log`.
Résultat Xcode : `/Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx/Logs/Test/Test-wander-2026.09.28_08-57-55-+0900.xcresult`.

## Revue finale

La décision principale est de partager un formulaire natif unique pour le profil,
avec ses sections sociales, tout en conservant la géométrie de la liste événements
lorsqu’un profil la masque. Imbriquer une seconde liste ou remplacer son contenu
à chaque ouverture aurait ajouté des défilements ou perdu son état.

La revue a corrigé la course entre ouverture par notification et arrivée des
amitiés, puis la validation a corrigé le déplacement du contenu masqué. La revue
ciblée de cette dernière correction n’a pas relevé de défaut confirmé ; son point
sur l’animation est traité par l’alignement supérieur et les tests de redimensionnement.
La principale incertitude restante concerne les échanges de comptes réels,
sans changement du service ni du schéma dans ce travail.

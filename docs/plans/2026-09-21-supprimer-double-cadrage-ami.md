---
title: "Supprimer le double mouvement à l’ouverture d’un profil ami"
status: completed
date: 2026-09-21
approved_at: 2026-09-21
completed_at: 2026-09-21
approval: "je valide, après proposition du mouvement unique avec repli au centrage simple"
owner: Samuel
tags: [plan, ios, map, friends]
---

# Supprimer le double cadrage ami

## Résultat et décision

Samuel observe dans `ScreenRecording_09-21-2026 11-30-24_1.MP4` un premier
centrage puis un décalage. Il demande une arrivée directe au bon emplacement,
ou l’abandon du décalage si ce placement n’est pas fiable assez tôt.

Le clic centre déjà la carte via `MapSocialProximityController.activate` ou la
demande depuis la liste. Le callback `FriendProfilePresentationReader.viewDidAppear`
ajoute ensuite une seconde commande via `friendCameraRequest`. La hauteur compacte
part de 440 points puis dépend de la mesure du contenu et du placement natif.
Ce chemin ne donne pas la destination finale au clic. Il faudrait anticiper la
mise en page ou changer la présentation pour la garantir avant le premier mouvement.

Le repli explicitement approuvé est retenu : conserver le centrage simple initial,
supprimer la correction après présentation. Aucun suivi du redimensionnement.
Conserver le recentrage de 0,22 seconde après disparition complète, avec les
gardes de position, sélection et gestes. Le pin peut donc être sous la feuille
ouverte ; le cadrage au-dessus de celle-ci est abandonné dans ce correctif.

## Périmètre

- `wander/FriendProfileSheet.swift` : supprimer le lecteur UIKit et son callback.
- `wander/ContentView.swift`, `wander/DebugSocialMapScenario.swift` : aucune demande
  de cadrage après ouverture ; conserver la demande de fermeture.
- `wander/MapWithFogView.swift`, `wander/MapFriendCameraController.swift` : limiter
  le contrôleur de correction au recentrage après fermeture.
- `wanderTests/MapFriendCameraControllerTests.swift` : géométrie de fermeture,
  projection et consommation des demandes.
- `wanderUITests/MapSocialGestureUITests.swift` : retirer l’attente de décalage
  abandonné, garder agrandissement et recentrage après fermeture.
- Ce plan, `docs/plans/2026-09-21-cadrage-ami-bottom-sheet.md` et le suivi
  `todos/060-ready-p2-valider-profils-bottom-sheet.md`.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md`

Pas de changement de présentation, de données, de Firebase ni de cadrage événement.
Les centrages d’ouverture existants restent propriétaires de ce mouvement.

## Étapes et critères d’acceptation

- [x] Retirer le déclencheur tardif et les paramètres de décalage devenus inutiles.
- [x] Garder le centrage initial et le recentrage après fermeture.
- [x] Adapter les tests au repli validé sans exécuter de tests.
- [x] Compiler application et cibles de tests, relire uniquement cet incrément.
- [x] Actualiser les trois notes Obsidian et le suivi.

## Validation et risques

Validation limitée à la compilation, comme demandé. Aucun simulateur démarré,
aucun test exécuté. La vidéo utilisateur établit le symptôme, sans reproduction
locale. La compilation ne prouvera pas la trajectoire visuelle corrigée.
Les tests précédents attendaient le point final décalé et ne comptaient pas les
mouvements intermédiaires. Cette attente est retirée pour le repli explicite.
Un pin désormais couvert par la feuille n’est pas une référence fiable pour
XCTest pendant la présentation. Aucun test de trajectoire à faux résultat positif
n’est ajouté : l’absence du deuxième mouvement reste à confirmer avec le scénario
vidéo, lorsque la validation interactive sera autorisée.

Les fichiers portent déjà les changements non commités des étapes précédentes.
Copies avant correctif : `/tmp/wander-single-friend-focus-before/`.
Revue manuelle ciblée selon `ce-debug/references/post-fix-handoff.md` ; pas de
simplification sur les fichiers portant ces modifications préexistantes.
Aucune commande Git modificatrice, aucun commit, aucune publication.

## Résultats

- Compilation finale réussie, application et cibles de tests :

  ```sh
  xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution -skipPackageUpdates CODE_SIGNING_ALLOWED=NO build-for-testing
  ```

  Journal `/tmp/wander-single-friend-focus-final-build.log`,
  `TEST BUILD SUCCEEDED`. Aucun avertissement Swift après remplacement de
  `UIWindow(frame:)` dans le test par la construction via `UIWindowScene`,
  déjà employée dans les autres tests. Les seuls avis restants concernent
  l’extraction AppIntents sans dépendance au framework.
- `git diff --check` réussi. Les seules créations de `MapFriendCameraRequest`
  en production et dans le scénario sont maintenant dans `friendProfileDidDismiss`.
  Aucun `onPresented`, lecteur UIKit ou paramètre `sheetTopInWindow` restant.
- Revue manuelle du diff par rapport aux copies avant correctif : aucun défaut
  supplémentaire retenu. Les gardes d’annulation, de nouvelle sélection et de
  position indisponible sont conservées. Les centrages initiaux des pins, des
  lignes de groupe et de la liste ne sont pas modifiés. Dans la liste, le chemin
  sans centrage est réservé aux amis sans position affichable.
- Simplification dédiée omise pour chevauchement avec les modifications
  préexistantes, conformément au workflow `ce-debug`. Aucun changement Git.
- Trois notes Obsidian mises à jour, propriété `updated` comprise. Le plan
  précédent indique que son cadrage d’ouverture est remplacé. Le suivi 060
  conserve la vérification du scénario vidéo et de la fermeture.
- Aucun test exécuté ni simulateur démarré. Le correctif est compilé et relu,
  mais sa trajectoire n’est pas validée sur appareil. Le repli abandonne le
  placement du pin au-dessus de la feuille.

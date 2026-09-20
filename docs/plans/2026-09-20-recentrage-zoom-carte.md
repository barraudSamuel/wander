---
title: Rétablir le zoom au recentrage
status: completed
date: 2026-09-20
completed_at: 2026-09-20T12:43:20+09:00
owner: Samuel
---

# Rétablir le zoom au recentrage

## Résultat et périmètre

Chaque appui sur le bouton de recentrage restaure le cadrage initial de
800 mètres sur chaque axe autour de la position, ajusté par MapKit au format
visible. Le suivi de position reste actif, y compris après des appuis répétés.
Approbation explicite de Samuel : « je valide », le 20 septembre 2026.

## Dépendances et exclusions

Réutiliser `setFocusedRegion` et la dernière position disponible.
Ne pas changer les permissions, les gestes, les boutons ou le cadrage des amis.
Conserver la demande en attente quand aucune position n’est disponible.
Les skills Compound Engineering sont indisponibles ; workflow suivi manuellement.

## Fichiers concernés

- `wander/MapWithFogView.swift` : traitement du recentrage utilisateur.
- `docs/plans/2026-09-20-recentrage-zoom-carte.md` : suivi.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md` : comportement du recentrage.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md` : implémentation et validation restante.

## Mise en œuvre

- [x] Rétablir le cadrage initial à chaque demande, tout en conservant le suivi.
- [x] Mettre à jour les deux notes Obsidian et leur propriété updated.
- [x] Compiler en Debug pour iOS Simulator.
- [ ] Vérifier zoom proche, zoom éloigné et appuis répétés sur l’iPhone 17 déjà démarré.
- [x] Relire le diff et consigner les limites de validation.

## Risques et critères d’acceptation

Éviter deux animations de caméra concurrentes. Le zoom doit revenir au même
cadrage après chaque appui. La position doit rester suivie. Aucun simulateur
supplémentaire ne sera démarré et aucun test dédié d’accessibilité ne sera lancé.

## Validation et revue

- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' build` : **BUILD SUCCEEDED** le 20 septembre 2026.
- Journal : `/tmp/wander-recenter-zoom-build.log`.
- Avertissements existants : extraction AppIntents sans dépendance et versions
  des extensions 15/27 différentes de l’application 42. Le second point est
  déjà suivi dans `todos/054-ready-p2-aligner-build-extensions.md`.
- `git diff --check` : réussi. Diff relu, aucune anomalie identifiée.
- Décision : activer le suivi sans animation avant d’appliquer le cadrage animé,
  pour ne pas lancer deux animations concurrentes.
- Alternative écartée : se limiter à `.follow`, qui ne rétablit pas le zoom.
- API consultée : https://developer.apple.com/documentation/mapkit/mkmapview/setusertrackingmode(_:animated:)
- Les deux notes Obsidian et leur propriété updated ont été actualisées.
- `xcrun simctl list devices booted` : aucun appareil démarré. Aucun démarrage effectué.
- Incertitude restante : comportement réel de MapKit pendant le suivi et
  l’animation. Suivi dans `todos/056-done-p3-valider-zoom-recentrage.md`.
- Le plan reste `in_progress` jusqu’à la validation fonctionnelle requise.
- Pas de nouvelle leçon vérifiée à consigner dans `docs/solutions/`.

## Correctif approuvé le 20 septembre 2026

Samuel signale un dézoom suivi d’un rezoom au second appui. Il approuve
explicitement le correctif dans la conversation. Les validations précédentes
ne prouvaient pas le comportement interactif.

- [x] Ne réactiver le suivi que si nécessaire.
- [x] Ignorer un cadrage déjà atteint et les relances pendant son animation.
- [x] Consommer chaque demande SwiftUI une seule fois.
- [x] Compiler, relire, actualiser les notes UX/backlog et le finding 056.
- [ ] Vérifier les appuis répétés et le suivi sur l’iPhone 17 déjà démarré.

Les fichiers concernés restent ceux du plan, avec mise à jour du suivi existant
`todos/056-done-p3-valider-zoom-recentrage.md`.

### Validation du correctif

- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' build` : **BUILD SUCCEEDED**.
- Journal : `/tmp/wander-recenter-repeat-build.log`.
- Avertissement de cette compilation : extraction AppIntents ignorée faute
  de dépendance, déjà observé. Aucun avertissement Swift dans le fichier modifié.
- `git diff --check` : réussi. Revue manuelle du diff effectuée.
- Le suivi actif n’est plus réappliqué. La région cible est ajustée par MapKit
  avant comparaison, avec une tolérance de 1 % sur le zoom et de 5 mètres sur
  le centre pour éviter les animations dues aux arrondis ou au bruit GPS.
- Une demande ne peut plus être retraitée avant la remise à zéro du binding.
  Les appuis pendant l’animation sont ignorés. La fin du changement de région
  ou un geste manuel libère le recentrage suivant.
- Les commandes des amis et événements ainsi que les services de localisation
  sont inchangés. Les deux notes Obsidian ont été actualisées.
- `xcrun simctl list devices booted` : aucun simulateur démarré. Aucun appareil
  n’a été démarré. Aucun test interactif exécuté ; le symptôme rapporté n’a pas
  été reproduit ni son absence confirmée ici.
- Le plan reste `in_progress` et le finding 056 reste ouvert jusqu’à cette
  validation. Pas de leçon de résolution à publier avant confirmation visuelle.

## Révision approuvée : propriétaire unique du suivi et du zoom

Samuel a confirmé que le symptôme persiste, puis approuvé la nouvelle approche
avec « j’approuve ». Les deux implémentations précédentes sont invalidées par
ses tests et ne constituent pas une résolution.

- `wander/MapWithFogView.swift` : contrôleur du recentrage et du suivi, réception
  des positions, arrêt sur geste ou cadrage social, suppression de `.follow`.
- `wanderTests/MapUserCameraControllerTests.swift` : régression des appuis répétés,
  suivi sans changement de zoom, interruption et reprise.
- `docs/plans/2026-09-20-recentrage-zoom-carte.md` et
  `todos/056-done-p3-valider-zoom-recentrage.md` : validation.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md`.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md`.

### Mise en œuvre de cette révision

- [x] Une commande de cadrage par demande ; aucun passage au suivi natif.
- [x] Déplacements suivis en changeant seulement le centre, jamais le zoom.
- [x] Interruption sur geste et cadrage ami/événement ; reprise par le bouton.
- [x] Six tests de régression écrits et compilés ; revue du diff réalisée.
- Tests MapKit compilés mais non exécutés : Samuel a choisi la validation manuelle sur son iPhone.
- [x] Actualisation des trois notes Obsidian et de leur propriété updated.
- [x] Validation du correctif par Samuel sur son iPhone, retour « c good mtn ».

Le risque principal est la reprise du suivi après manipulation manuelle. Le
contrôleur doit aussi traiter la dernière position reçue pendant une animation
et ne jamais reprendre un suivi interrompu par l’utilisateur.

### État de validation de la révision finale

- Un contrôleur `MapUserCameraController` gère les commandes utilisateur, avec
  `setRegion` au recentrage et `setCenter` aux positions suivantes. Aucun
  `setUserTrackingMode(.follow, ...)` ne reste dans ce parcours.
- La région de 800 mètres est partagée avec le cadrage initial et social.
- Le traitement des positions suit les demandes de cadrage social dans
  `updateUIView`, afin de ne pas lancer un suivi avant de le désactiver.
- Les gardes contre les demandes SwiftUI répétées restent en place. La dernière
  position reçue pendant une animation est traitée une fois l’animation terminée.
- Six tests avec une vraie `MKMapView` couvrent les appuis successifs, le cadrage
  déjà atteint, les positions en attente, l’arrêt du suivi, la reprise après
  zoom proche/éloigné, et les coordonnées invalides ou variations GPS minimes.
- Samuel a explicitement refusé le démarrage du simulateur : « Non, je testerai
  sur mon iPhone ». Aucun simulateur n’a été démarré et aucun test exécuté.
- Les trois notes Obsidian sont mises à jour avec `updated` et liens conservés.
- Revue et simplification manuelles réalisées, skills Compound Engineering
  indisponibles. `git diff --check` réussi.
- Incertitude restante : rendu réel et interruption/reprise dans les parcours
  de l’application. Le plan reste `in_progress` jusqu’au retour de Samuel.
- Pas de note de résolution dans `docs/solutions/` avant validation en exécution.
- Compilation finale : `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' build-for-testing` : **TEST BUILD SUCCEEDED**.
- Journal : `/tmp/wander-user-camera-final-build.log`. Extraction AppIntents
  ignorée faute de dépendance, avertissement déjà présent. Aucune erreur ni
  nouvel avertissement Swift dans l’application ou les tests.

## Clôture

Le 20 septembre 2026, après avoir choisi de tester sur son iPhone, Samuel
confirme « c good mtn ». Ce retour valide la résolution du dézoom/rezoom signalé
et clôt le correctif. Les sections précédentes conservent l’historique des
tentatives et de leurs validations alors en attente.

La compilation de l’application et des six tests avait réussi. Les tests
MapKit n’ont pas été exécutés. Le retour utilisateur ne détaille pas chacun des
scénarios secondaires ; leur exécution individuelle n’est pas revendiquée.
Le test sur simulateur a été remplacé par le test sur iPhone choisi par Samuel.
Les cases non cochées dans les sections historiques ne sont pas des validations
annoncées comme réussies.

Apprentissage consigné dans
`docs/solutions/2026-09-20-eviter-concurrence-suivi-zoom-mapkit.md`.

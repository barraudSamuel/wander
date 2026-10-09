---
title: "Supprimer entièrement la heatmap"
status: completed
date: 2026-10-09
approved_at: 2026-10-09
completed_at: 2026-10-09
owner: Samuel
tags: [plan, map, exploration, swiftdata]
---

# Supprimer entièrement la heatmap

## Outcome

Retirer l'affichage, les réglages, les calculs et le stockage actif de la
fréquentation. Le brouillard, les cellules découvertes, leur synchronisation
Firebase et la progression doivent continuer à fonctionner après mise à jour.

Plan présenté dans la conversation, puis explicitement approuvé par Samuel
avec « je valide » le 9 octobre 2026. Un seul incrément couvre ce retrait.

## Scope

- Retirer tous les chemins actifs propres à la heatmap dans l'app et son
  scénario local de test.
- Retirer `duration` et `visitCount` du modèle SwiftData courant. Conserver
  `id`, `resolution`, `firstSeenAt` et `lastSeenAt`.
- Garder les anciens schémas exclusivement pour migrer les bases existantes.
- Adapter les tests et la documentation concernée.
- Le dépôt ne contient aucune Cloud Function, collection ou règle spécifique
  à la heatmap. `FriendSyncService` synchronise des IDs H3 et `sharedAt` ;
  aucune suppression de données cloud ni aucun déploiement Firebase ne sont
  nécessaires au périmètre observé. La production n'a pas été inspectée.
- Ne pas modifier le brouillard, les contrôles sociaux ou les permissions.
- Aucune opération Git mutante, aucun commit ni déploiement. Le numéro de
  build 52 déjà modifié dans `project.pbxproj` appartient à Samuel.

## Proposed approach

Supprimer les composants et leurs appelants, puis simplifier le remplacement
du seul overlay de brouillard restant. Conserver Core Location `didVisit` et
`previousAcceptedLocation`, qui servent encore à découvrir des cellules.

Figer le schéma V2 historique avant de retirer ses deux champs du modèle
actuel, puis migrer vers V3. Le nouveau schéma doit avoir une identité distincte
de V1 malgré le retour aux mêmes champs, sans ajouter de donnée factice.
Valider sur des bases disque V1 et V2, avec des valeurs de fréquentation
non nulles en V2, et sur une base neuve. Les définitions historiques ne sont
pas un chemin actif de collecte ou d'affichage.

La migration suit le mécanisme `VersionedSchema` / `SchemaMigrationPlan`
décrit par [Apple](https://developer.apple.com/videos/play/wwdc2023/10195/).

## Affected files

- `wander/HeatMapOverlay.swift` : suppression.
- `wander/ContentView.swift` : retrait des états et bindings.
- `wander/ProfilePanelView.swift` : retrait du réglage et de sa section.
- `wander/DebugSocialMapScenario.swift` : retrait du réglage et des paramètres.
- `wander/MapWithFogView.swift` : retrait du renderer, de l'état et des mises à
  jour de heatmap, simplification du remplacement de brouillard.
- `wander/LocationTracker.swift` : retrait de la collecte et des publications.
- `wander/DiscoveredCellStore.swift` : retrait des mises à jour de fréquentation.
- `wander/DiscoveredCell.swift` : modèle courant sans compteurs ni durées.
- `wander/WanderMigrationPlan.swift` : schémas historiques figés et migration.
- `wanderTests/WanderMigrationPlanTests.swift` : nouveau test de migration.
- `wanderUITests/MotionDockUITests.swift` : parcours des réglages restants.
- `wanderUITests/MapSocialGestureUITests.swift` : profil sans heatmap.
- `docs/plans/2026-10-09-supprimer-heatmap.md` : suivi et validation.
- `todos/003-ready-p2-sync-exploration-metadata.md` : classement comme obsolète.
- `docs/solutions/2026-08-09-restaurer-exploration-firebase-vers-swiftdata.md` :
  actualiser les instructions de restauration.
- Notes du vault Obsidian
  `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  - `Backlog features.md` : retrait de la synchronisation de fréquentation,
    enregistrement de la suppression.
  - `Documentation technique.md` : pipeline, modèle, migration, profil,
    isolation des comptes et limites de restauration.
  - `Documentation UX.md` : contrôles du profil et direction visuelle.
  - `00 - Wander.md` : état du projet et lien documentaire.
  Mettre à jour `updated` et conserver les wikilinks. Le vault est hors des
  racines d'écriture initiales ; demander l'accès technique nécessaire pour
  ces mises à jour approuvées, ou consigner précisément la limitation.
- `todos/` : constat priorisé si la revue ou une validation laisse un problème.
- `docs/solutions/` : note seulement si une leçon réutilisable est vérifiée.

## Implementation

- [x] Présenter le plan et obtenir l'approbation explicite.
- [x] Retirer l'interface et le rendu de heatmap.
- [x] Retirer les calculs, buffers et écritures de fréquentation.
- [x] Migrer le stockage sans perdre les cellules et dates d'exploration.
- [x] Adapter les tests et vérifier le résultat intégré.
- [x] Simplifier et réaliser une revue indépendante.
- [x] Actualiser les documents et notes Obsidian approuvés.

## Risks

- Collision d'identité entre V1 et V3 ou modification accidentelle du schéma
  V2 : les migrations disque doivent prouver l'ouverture et la conservation
  de toutes les données d'exploration.
- Retrait du helper d'ordre d'overlays : le brouillard doit rester visible et
  se mettre à jour, sans perturber les annotations et interactions sociales.
- Les compteurs et durées historiques disparaissent volontairement ; les
  données d'exploration ne doivent pas disparaître.

## Validation and acceptance criteria

- [x] Aucune référence active à la heatmap ou à sa collecte dans les sources ;
  seules les définitions historiques de migration peuvent garder ses champs.
- [x] Tests disque V1 vers V3 et V2 vers V3 : IDs, résolutions, dates et nombre
  de cellules conservés, puis réouverture réussie.
- [x] Installation neuve, upsert et restauration de cellules fonctionnels.
- [x] Build Debug et cibles de tests sans nouveau diagnostic Swift.
- [x] Tests UI ciblés du profil et des réglages restants réussis.
- [x] Brouillard et carte vérifiés sur l'iPhone 17 déjà démarré ; conservation
  des entrées et branchements de progression vérifiée dans le code,
  sans créer ni démarrer d'autre simulateur. Aucun test d'accessibilité dédié.
- [x] Revue indépendante, vérification du diff et suivi des limites réelles.
- [x] Documentation active et quatre notes Obsidian mises à jour, ou accès
  bloqué documenté sans créer de vault de substitution.

## Review notes

- Décision sensible : retirer les métadonnées tout en conservant les schémas
  nécessaires à l'ouverture des anciennes bases.
- Alternative rejetée : masquer seulement le réglage laisserait les calculs
  et écritures de fréquentation actifs.
- La simplification `ce-simplify-code` a exécuté trois passes indépendantes
  de réutilisation, qualité et efficacité. Aucun changement supplémentaire
  justifié ; aucune protection de migration retirée.
- La revue indépendante `ce-code-review` couvre comportement, migration,
  tests, standards, Swift/iOS, maintenabilité et scénarios adverses. Aucun
  constat actionnable. Reçu :
  `/private/tmp/wander-heatmap-review-20261009/review.json`.
  Aucune revue externe exécutée. Les limites des parcours réels et de la
  transition dynamique du brouillard restent décrites ci-dessous.
- `git diff --check` réussit. Le diff préexistant de `project.pbxproj` reste
  exactement le passage de 51 à 52 dans les deux configurations de l'app.
  Aucun commit ni autre commande Git mutante exécutés.

## Validation exécutée

Xcode 27, iPhone 17 Pro iOS 26.3 déjà démarré,
`C0DADF07-7E14-4D5E-AE4B-B17844A9C454`. Aucun simulateur créé ou démarré.
XcodeBuildMCP étant indisponible, validation équivalente avec `xcodebuild`,
`simctl` et `xcresulttool`, sans installation d'outillage.

La compilation des cibles app et tests a réussi. Les avertissements préexistants
AppIntents et de versions des extensions 15/27 face à l'app 52 restent présents.
Le suivi de ces versions existe déjà dans
`todos/054-ready-p2-aligner-build-extensions.md`. Aucun nouveau diagnostic Swift.

Premier lancement intégré, résultat non retenu comme succès global :

```bash
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'platform=iOS Simulator,id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' \
  -parallel-testing-enabled NO -disableAutomaticPackageResolution \
  -collect-test-diagnostics never \
  -resultBundlePath /private/tmp/wander-heatmap-removal.xcresult \
  -only-testing:wanderTests/WanderMigrationPlanTests \
  -only-testing:wanderTests/LocationTrackerTests \
  -only-testing:wanderUITests/MotionDockUITests/testSettingsRemainAvailableAlongsideFriends \
  -only-testing:wanderUITests/MapSocialGestureUITests/testOwnSettingsOpensSeparateSheetAndReturnsToProfile \
  -only-testing:wanderUITests/MapSocialGestureUITests/testNativePanClosesGroupAndMovesMap \
  -only-testing:wanderUITests/MapSocialGestureUITests/testNativePinchAndDoubleTapZoom test
```

Les quatre tests UI, les sept tests de localisation et les migrations V1/V2
passent. Le nouveau test de store synchrone plante à sa destruction dans
`swift_task_deinitOnExecutorImpl` puis `DiscoveredCellStore.__deallocating_deinit`.
Le runner redémarre : ce lancement sort bien avec le code 65 et `TEST FAILED`.
Journal : `/private/tmp/wander-heatmap-removal.log`.

Seul changement correctif : déclarer le test de store `async throws`, ce qui
donne un contexte de tâche Swift à sa destruction. Aucune rétention artificielle
du store, aucun test ignoré ni changement supplémentaire de production.
Le mécanisme interne du runtime n'a pas été diagnostiqué au-delà de cette
comparaison contrôlée ; ce résultat ne clôt pas le constat distinct 073.

Relance après correction, code de sortie 0, dix tests réellement exécutés :

```bash
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'platform=iOS Simulator,id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' \
  -parallel-testing-enabled NO -disableAutomaticPackageResolution \
  -collect-test-diagnostics never \
  -resultBundlePath /private/tmp/wander-heatmap-migrations-async.xcresult \
  -only-testing:wanderTests/WanderMigrationPlanTests \
  -only-testing:wanderTests/LocationTrackerTests test
```

- Trois tests de stockage passent sans redémarrage du runner : V1, V2 versionnée
  et non versionnée, installation neuve, upserts, fusion distante idempotente,
  dates de secours et réouverture.
- Le test V2 compare l'empreinte du modèle figé à celle lue dans les seules
  métadonnées du store installé avant changement. Aucun contenu de cellule
  personnelle n'a été affiché.
- Sept tests de localisation passent sans modification.
- Journal : `/private/tmp/wander-heatmap-migrations-async.log`.

Le test `testOwnSettingsOpensSeparateSheetAndReturnsToProfile` a ensuite été
recompilé et relancé avec deux captures attachées. Code de sortie 0, un test
exécuté et réussi, journal `/private/tmp/wander-heatmap-visual.log`, résultat
`/private/tmp/wander-heatmap-visual.xcresult`.

Captures exportées et inspectées :

- `/private/tmp/wander-heatmap-visual-captures/0466E6AC-CF9E-4690-ABF9-4B1135F69735.png`
  montre la carte, ses annotations et le brouillard.
- `/private/tmp/wander-heatmap-visual-captures/C1483E54-DC23-4C14-8B6E-BD0349C20D8A.png`
  montre les réglages sans commande de fréquentation ni section vide.

Les quatorze tests ciblés distincts ont donc un résultat passant, sur la même
implémentation de production. Le seul test relancé pour les captures compte
une fois. La conservation des identifiants alimentant la progression est testée
au niveau du store ; les branchements de `refreshCityProgress` et de la carte
sont inchangés et ont été relus. Aucun parcours GPS réel ni nouvel échange
Firebase de production n'a été exécuté. Les captures valident le brouillard
initial ; la transition après découverte d'une nouvelle cellule ou changement
de limite de ville n'a pas été exercée en UI et a été vérifiée par relecture.

La recherche finale dans l'app, les extensions, Functions, règles/index et tests
Firebase ne trouve plus de chemin actif de heatmap. Les seules références Swift
restantes sont le schéma V2 historique et les tests du retrait/de la migration.

Les quatre notes Obsidian approuvées ont été mises à jour avec l'accès accordé,
`updated: 2026-10-09T12:38:51+09:00`. Les wikilinks existants restent valides ;
seul le lien devenu inutile vers le besoin abandonné est retiré du paragraphe
technique. Aucun vault de substitution ni ouverture d'Obsidian.

Le retrait n'appelle pas une nouvelle note de solution : le schéma distinct,
l'empreinte historique et le contexte asynchrone sont explicités dans le code,
les tests et ce plan. La note de restauration existante a été actualisée.

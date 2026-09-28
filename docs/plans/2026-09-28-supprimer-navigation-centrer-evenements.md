---
title: "Supprimer la barre Explorer et centrer les événements"
status: completed
date: 2026-09-28
approved_at: 2026-09-28
completed_at: 2026-09-28
owner: Samuel
tags: [plan, map, navigation]
---

# Supprimer la barre Explorer et centrer les événements

## Résultat attendu

La carte ne présente plus de barre Explorer. Le bouton événements existant de
44 points reste seul, centré horizontalement en bas de la zone sûre. Il ouvre
et ferme la liste, en conservant ses états et interactions actuels.
Samuel a explicitement approuvé le plan présenté dans la conversation.

## Périmètre et approche

Retirer le contrôleur d'onglets, son conteneur, sa mise à l'échelle et le callback
Explorer. Conserver le hosting plein écran de la carte, le bouton SwiftUI actuel,
ses identifiants et la transmission du contexte SwiftData. Ancrer le bouton à la
zone sûre et au clavier. Calculer la réserve basse depuis le bouton seul, avec
8 points au-dessus, pour préserver la dernière ligne des événements.

Pas de changement des événements, du profil, de Firebase ou des assets.
Pas de commande Git modificatrice, conformément aux instructions de Samuel.
Les modifications restent dans le checkout actuel ; aucune publication prévue.

## Fichiers concernés

- `wander/NativeMapTabView.swift` : retrait des onglets, placement et marges.
- `wander/MotionDockView.swift` : retrait du callback Explorer.
- `wander/ContentView.swift` : retrait de l'action Explorer devenue inutile.
- `wander/DebugSocialMapScenario.swift` : même composition dans le scénario local.
- `wanderUITests/MotionDockUITests.swift` : absence de barre, centrage et stabilité.
- `wanderUITests/MapSocialGestureUITests.swift` : fermeture et géométrie sans Explorer.
- Ce plan : suivi et preuves de validation.
- `docs/solutions/2026-09-28-verifier-binaires-xcode-et-tests-executes.md` :
  apprentissage apparu pendant la validation, sur les binaires conservés par Xcode.
- `todos/` : seulement un éventuel constat de revue ou validation non résolu.
- Notes dans `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/` :
  - `Documentation UX.md` : architecture de navigation et fiches/carte partagée.
  - `Documentation technique.md` : contrôleur carte/bouton et réserve basse.
  - `Backlog features.md` : suivi de la simplification et validation.
  - `00 - Wander.md` : résumé de navigation et état du projet.
  - Actualiser `updated` dans chaque note et préserver les wikilinks.

## Mise en œuvre

- [x] Retirer la barre et centrer le bouton avec ses marges.
- [x] Nettoyer les callbacks de production et du scénario local.
- [x] Adapter les tests existants aux contrôles et parcours restants.
- [x] Simplifier et relire les changements.
- [x] Compiler puis vérifier les parcours ciblés sur l'iPhone 17 déjà démarré.
- [x] Mettre à jour les quatre notes Obsidian et consigner les résultats.

## Risques

- Le bouton dépendait de la géométrie de la barre : borner son bas par la zone
  sûre et le clavier, sans changer le cadre du hosting de la carte.
- Les marges de liste utilisaient les onglets : conserver une réserve qui permet
  à la dernière ligne de défiler au-dessus du bouton.
- Certains tests ferment la liste via Explorer : utiliser le calendrier.

## Validation et critères d'acceptation

- Compilation de l'app et des tests sans nouveau diagnostic Swift.
- Absence d'Explorer et du UITabBar ; calendrier centré, hittable et de 44 points.
- Ouvertures/fermetures répétées, retour de profil, saisie avec clavier et marges
  de liste cohérents, carte toujours interactive.
- Tests UI fonctionnels en taille de texte standard uniquement, sur l'iPhone 17
  déjà démarré. Aucun autre simulateur ne sera créé ou démarré.
- Adapter les tests existants puis vérifier l'ensemble intégré. Pas de passage
  rouge préalable : il s'agit d'un retrait de contrôle et d'un ajustement visuel,
  les scénarios existants servent de vérification après modification.
- Si le vault reste inaccessible en écriture, consigner les notes et sections
  en attente ici et le signaler, sans créer de vault de remplacement.

## Revue et preuves

- Exécution native dans le checkout courant ; aucun moteur externe ni commande
  Git modificatrice. État initial propre sur `main`.
- `ce-simplify-code` : trois lectures indépendantes, réutilisation, qualité et
  efficacité. Aucun correctif nécessaire. La borne obligatoire de zone sûre
  reste explicite ; renommage des types historiques et suppression de l'asset
  inutilisé écartés pour éviter d'élargir cette modification.
- `ce-test-xcode` chargé ; XcodeBuildMCP absent des outils. Workflow équivalent
  exécuté avec `xcodebuild` et `simctl`, conformément aux consignes du dépôt.
- `build-for-testing` réussi le 28 septembre sur l'iPhone 17 déjà démarré,
  UUID `6F13855D-10B8-45AF-9205-17C8393379E3`. Journal :
  `/tmp/wander-centered-events-build.log`.
- Aucun diagnostic Swift. Avertissements préexistants AppIntents et versions
  d'extensions 15/27 contre 49 pour l'app, déjà suivis dans le constat 054.
- `ce-code-review` terminé, lectures correctness et adversarial indépendantes :
  aucun constat actionnable. Reçu :
  `/tmp/compound-engineering-501/ce-code-review/20260928-100303-0f7611e9/review.json`.
- Première exécution UI : cinq tests conservés passent, mais le binaire de tests
  datait de 08:58 et les nouvelles méthodes étaient ignorées. Résultat insuffisant
  pour valider ce changement. Un essai avec une seule nouvelle méthode exécutait
  zéro test malgré un code de sortie 0.
- Actualiser les dates des sources n'a pas suffi. Compilation directe de la cible
  abandonnée après un conflit de dossier `nanopb/build`, sans changement du projet.
  Le cache généré `wanderUITests.build/Objects-normal/arm64` a été déplacé vers
  `/tmp/wander-centered-events-test-objects-before`.
- Reconstruction vérifiée dans `/tmp/wander-centered-events-rebuilt-tests.log` :
  les deux sources UI sont effectivement recompilées, binaire produit à 10:08,
  `TEST BUILD SUCCEEDED`. Résultats définitifs consignés ci-dessous.
- Le code de disposition ne nécessite pas de note de solution. Le piège de
  validation Xcode découvert pendant le travail est documenté séparément via
  `ce-compound`, mode non interactif léger. Aucun terme de vocabulaire spécifique
  ne justifie de modifier `CONCEPTS.md` ; aucun défaut de découvrabilité, puisque
  les consignes pointent déjà vers `docs/solutions/`.
- Les nouvelles assertions ont ensuite trouvé l'ancienne barre : les objets
  Swift étaient à jour mais les exécutables de l'app dataient encore de 08:58.
  Exécution interrompue ; journal conservé dans
  `/tmp/wander-centered-events-stale-app-tests.log`.
- Les deux exécutables générés ont été mis de côté dans
  `/tmp/wander-centered-events-app-binaries-before`, puis reconstruits à 10:12.
  Les étapes `Ld` sont présentes dans `/tmp/wander-centered-events-linked-build.log`.
  L'origine interne de l'incohérence du cache n'est pas établie.
- Nouvelle app installée sur le même simulateur ; capture inspectée
  `/tmp/wander-centered-events-current.png` : calendrier centré, barre absente.

## Validation définitive

- Compilation de l'app effectivement liée et des tests réussie, puis installation
  et capture contrôlée. Aucun nouveau diagnostic Swift.
- Première série sur l'app reconstruite : 10 succès sur 11. L'échec vient du
  helper d'ouverture d'un groupe compact avant de sélectionner un ami. Même
  échec observé avec l'ancienne app ; cause non établie, suivi P2 séparé
  [070](../../todos/070-ready-p2-diagnostiquer-ouverture-groupe-apres-profils.md).
- Le test de conservation du défilement ouvre maintenant Amina via la ligne du
  profil, parcours déjà utilisé dans un test voisin. Ses assertions de défilement,
  hauteur, observations et taille MapKit sont conservées. Aucun changement du
  helper de groupe ou de ses tests dédiés, aucun correctif produit supplémentaire.
- Recompilation des deux fichiers UI attestée dans le journal, puis ce test
  rejoué avec succès, 1 test, 0 échec, 73,671 secondes. Les 11 cas ciblés ont
  donc un dernier résultat passant ; la série initiale échouée reste conservée.
- Journaux : `/tmp/wander-centered-events-verified-tests.log` pour la série de
  11 cas ; `/tmp/wander-centered-events-scroll-retest.log` pour le rejeu.
- Résultat de la série :
  `/Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx/Logs/Test/Test-wander-2026.09.28_10-13-34-+0900.xcresult`.
- Revue de l'adaptation du test, correctness et adversarial : aucun constat
  actionnable, reçu
  `/tmp/compound-engineering-501/ce-code-review/20260928-100303-0f7611e9/review-followup.json`.
- Capture de fin de liste inspectée :
  `/tmp/wander-centered-events-evidence/0E53C3CC-2D24-49A6-9544-9878D34C5765.png`.
  Le dernier événement est entièrement au-dessus du bouton centré.
- Les quatre notes Obsidian ont été mises à jour après vérification de leurs
  empreintes sources. Propriété `updated` actualisée, wikilinks conservés.
  Aucun lancement d'Obsidian.
- `git diff --check` passe. Aucun commit, changement de branche ou push.
- Aucun autre simulateur créé/démarré, aucun test d'accessibilité dédié.
- Limite conservée : le clavier est exercé dans le profil et le retour vérifie
  le cadre du bouton ; le bouton sous la feuille modale n'est pas contrôlé
  directement pendant la saisie. Les bornes Auto Layout ont été relues.

Commande de compilation : `xcodebuild -project wander.xcodeproj -scheme wander
-configuration Debug -destination 'platform=iOS Simulator,id=6F13855D-10B8-45AF-9205-17C8393379E3'
-parallel-testing-enabled NO -disableAutomaticPackageResolution build-for-testing`.
La série utilise les mêmes options avec `test-without-building` et les filtres
ci-dessous. Le rejeu utilise `test` avec le seul filtre de conservation du défilement.

```text
wanderUITests/MotionDockUITests/testEventsButtonReplacesNavigationBar
wanderUITests/MotionDockUITests/testEventsButtonStaysCenteredAcrossRepeatedListToggles
wanderUITests/MotionDockUITests/testBottomOfEventsListClearsEventsButton
wanderUITests/MotionDockUITests/testEventsButtonRemainsCenteredAndReachableAfterClosingProfile
wanderUITests/MotionDockUITests/testFriendInvitationsLiveInProfileAndDraftSurvivesClosing
wanderUITests/MotionDockUITests/testImageButtonEdgesOpenTheirSheets
wanderUITests/MotionDockUITests/testEventsButtonReturnsFromPanelsAndOpensAfterFriendSheetCloses
wanderUITests/MapSocialGestureUITests/testFullMapRestoresAfterEventsAndProfile
wanderUITests/MapSocialGestureUITests/testNativeMapRenderSizeStaysStableAcrossPaneChanges
wanderUITests/MapSocialGestureUITests/testEventListScrollSurvivesFriendAndOwnProfile
wanderUITests/MapSocialGestureUITests/testEventListHandleResizesThenFoldsBackToFullMap
```

Capture `ce-compound` terminée, piste knowledge, catégorie ios-testing.
Vérifications mécaniques des références et du frontmatter sans erreur.
Vocabulaire inspecté, aucun terme spécifique à ajouter, `CONCEPTS.md` inchangé.
Pas de rafraîchissement documentaire plus large à prévoir.

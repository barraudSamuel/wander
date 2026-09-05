---
title: "Architecture carte sociale — sprint 01"
status: in_progress
date: 2026-09-05
approved_at: 2026-09-05
started_at: 2026-09-05
owner: Samuel
related:
  - ../../todos/020-ready-p2-refactor-codebase.md
  - ../solutions/2026-09-02-regrouper-marqueurs-par-proximite.md
  - ../solutions/2026-09-02-rendre-interactions-mapkit-immediates.md
tags: [plan, architecture, mapkit, tests]
---

# Architecture carte sociale — sprint 01

## Outcome

Faciliter l'ajout de fonctionnalités en donnant à la carte sociale la propriété de son cycle sources → groupes → sélection → restauration.
Les règles de regroupement doivent pouvoir évoluer et être testées sans modifier les écrans ni le dessin des marqueurs.
Samuel a explicitement approuvé ce sprint dans la conversation le 5 septembre 2026.

## Scope and non-goals

- Réunir les règles de proximité, l'historique des paires, l'identité des groupes et la sélection dans deux fichiers cohérents : état et adaptation MapKit.
- Réduire la coordination portée par `MapWithFogView.Coordinator` ; conserver les gestes passifs, la sélection native et les présentations actuelles.
- Ajouter une cible `wanderTests` et couvrir les transitions complètes avec de vrais objets MapKit pour l'intégration.
- Conserver 20 m à l'entrée, 25 m au maintien, l'anti-chaîne et l'indépendance au zoom.
- Aucun changement produit, migration Firestore, refonte de synchronisation, modification du brouillard, de la heat map ou des calculs d'indicateurs.
- Aucun autre sprint n'est autorisé. Aucun Git modifiant l'état du dépôt, commit ou publication.

## Dependencies and approach

La base observée est le commit `e2c4909`, avec un arbre initial propre sur `main`.
Les restrictions Git du propriétaire priment sur les automatismes de branches et de commits des skills ; le travail reste dans le checkout autorisé.
`MapSocialProximityState` possède les sources identifiées, la composition déterministe, l'hystérésis, l'identité et le membre sélectionné, sans dépendance à SwiftUI ou Firebase.
`MapSocialProximityController` possède les annotations natives, l'ouverture et la restauration, et applique les résultats de l'état à MapKit.
Les entrées et callbacks du contrôleur décrivent des comportements ; les dictionnaires internes et gardes de réentrance ne sont pas exposés au Coordinator.
Le projet ne possède pas de tests Swift existants : la référence initiale est le code et les scénarios documentés, puis les tests caractérisent ces comportements durant l'extraction.

## Affected files

- `wander/MapWithFogView.swift` — délégation du cycle social au contrôleur.
- `wander/MapSocialProximityState.swift` — nouveau module de règles et d'état.
- `wander/MapSocialProximityController.swift` — nouvelle adaptation MapKit.
- `wander/MapSocialProximityGroupAnnotation.swift` — conservation des représentants natifs.
- `wander/MapSocialClusterAnnotationView.swift` — séparation de l'identité et de la présentation si nécessaire.
- `wanderTests/MapSocialProximityStateTests.swift` — séquences de règles.
- `wanderTests/MapSocialProximityControllerTests.swift` — intégration annotations/sélection/restauration.
- `.gitignore` — exception ciblée pour inclure le schéma app/tests, actuellement ignoré ; nécessaire à la reproductibilité de la cible approuvée.
- `wander.xcodeproj/project.pbxproj` et `wander.xcodeproj/xcshareddata/xcschemes/wander.xcscheme` — cible de tests.
- Ce plan et `todos/020-ready-p2-refactor-codebase.md` — suivi du premier incrément uniquement.
- `todos/` — éventuels constats de revue, classés par priorité.
- `docs/solutions/2026-09-02-regrouper-marqueurs-par-proximite.md` — responsabilités actualisées après vérification, preuves historiques conservées.
- `todos/025-ready-p2-valider-gestes-carte-sociale-apres-extraction.md` — écart de validation interactive relevé par la revue.
- Obsidian : `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md` — section En cours / refonte progressive.
- Obsidian : `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md` — Architecture logique, Carte, Validation et outils, Fichiers repères.

## Implementation checklist

- [x] Approbation explicite du sprint reçue ; plan enregistré en statut approved.
- [x] Isoler les règles et l'état des groupes avec leurs scénarios de caractérisation.
- [x] Ajouter la cible de tests Xcode.
- [x] Intégrer le contrôleur MapKit et supprimer la coordination redondante.
- [x] Ajouter les tests d'intégration de sélection et de restauration.
- [x] Simplifier puis effectuer une revue indépendante et traiter les constats.
- [x] Exécuter les tests, le build et l’analyse sur le simulateur existant.
- [ ] Terminer les vérifications interactives de l’app authentifiée sur ce simulateur.
- [ ] Mettre à jour les notes Obsidian, vérifier leur rendu et documenter les résultats exacts.

## Risks

- MapKit peut appeler son delegate pendant les ajouts/retraits ou plus tard : préserver l'identité des objets et les gardes de restauration.
- Un membre sélectionné peut disparaître ou changer de coordonnées : réconcilier la sélection avec les sources courantes.
- Une interaction directe et le callback natif peuvent correspondre au même tap : conserver la déduplication et le chemin VoiceOver.
- Une simple extraction du calcul de distance ne satisferait pas le sprint : le contrôleur doit aussi absorber le cycle de sélection/restauration.

## Validation and acceptance criteria

- [x] Tests : 19 → 24 → 26 m, paire initiale à 21 m, positions 0/15/30 m, ordre des entrées, voisin nouvellement arrivé, sources invalides et vides.
- [x] Tests : conservation des identités, sélection puis restauration, changement/retrait d'une source sélectionnée, ouverture pendant réconciliation, absence de recalcul au zoom.
- [x] Tests d'intégration utilisant `MKMapView` et les annotations de groupe réelles ; marqueurs individuels de fixture, vérification du pont de gestes de production encore ouverte ci-dessous.
- [x] `xcodebuild` Debug et tests sur l'iPhone 17 déjà démarré ; aucune création ou ouverture d'autre simulateur.
- [x] Aucun nouveau diagnostic Swift ; diagnostics préexistants identifiés séparément.
- [ ] Vérification visuelle et interactive des taps, double taps, sélection/désélection et VoiceOver si la session du simulateur le permet ; toute limite reste explicitement ouverte.
- [x] `git diff --check` et revue du périmètre réussis.
- [ ] Deux notes Obsidian actualisées, propriété `updated` et wikilinks préservés, sections affectées vérifiées en mode lecture ; toute impossibilité d'accès est documentée sans copie de remplacement.
- [x] Les règles sont modifiables dans l'état sans changer les vues ; l'ancien Coordinator ne conserve pas une seconde source de vérité pour les groupes.

## Review and validation notes

Le schéma partagé était ignoré par `.gitignore` : une exception ciblée le rend livrable avec les tests, sans commande Git mutante.
Le simulateur existant réellement démarré est iPhone 17 Pro, iOS 26.3, `C0DADF07-7E14-4D5E-AE4B-B17844A9C454` ; il est utilisé sans créer de nouveau simulateur.
XcodeBuildMCP est absent ; la validation équivalente utilise `xcodebuild` et `simctl` locaux conformément aux commandes du dépôt.
Les résultats observés sont détaillés ci-dessous ; la validation interactive reste ouverte.
Le sprint ne sera marqué completed qu'après satisfaction des critères d'acceptation ; les limites de validation resteront visibles.


### Résultat de l'implémentation

- `MapWithFogView.swift` passe de 4 096 à 3 216 lignes (880 lignes nettes retirées).
- État de proximité : 281 lignes ; contrôleur MapKit : 368 lignes. Le Coordinator
  ne conserve plus les paires, groupes, focus, sélection en attente et gardes
  de restauration/région du cycle social.
- Les distances de paires sont recalculées lors des changements de sources,
  puis réutilisées lors des transitions de focus. Aucun gain de temps n'est
  revendiqué sans mesure.
- Les tests ont révélé la sélection d'un singleton visible sans nouveau `didAdd` :
  la sélection se poursuit immédiatement si sa vue existe.
- La première exécution des sept tests natifs a planté à la libération du
  contrôleur, dans `swift_task_deinitOnExecutorImpl` puis
  `TaskLocal::StopLookupScope`. Le `nonisolated deinit` explicite évite cette
  destruction isolée synthétisée ; `tearDown` conserve les effets sur MainActor.
  Les sept scénarios identiques passent ensuite. Correspondance externe :
  [swiftlang/swift#88036](https://github.com/swiftlang/swift/issues/88036).

### Commandes et résultats observés

Toutes les commandes utilisent `wander.xcodeproj`, le schéma partagé `wander`,
Debug et l'identifiant du simulateur existant ci-dessus, avec
`-parallel-testing-enabled NO -disableAutomaticPackageResolution`.

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' \
  -parallel-testing-enabled NO -disableAutomaticPackageResolution \
  -resultBundlePath /private/tmp/wander-proximity-reviewed-tests.xcresult test analyze
```

- PASS : 18 tests de règles, 7 tests d'intégration, 25/25 au total ;
  `TEST SUCCEEDED`, puis `ANALYZE SUCCEEDED`.
- Journal : `/private/tmp/wander-proximity-reviewed-tests.log`.
- Résultats : `/private/tmp/wander-proximity-reviewed-tests.xcresult`.
- Un avertissement Swift sur `UIWindowScene.coordinateSpace` dans la fixture
  a été corrigé par `effectiveGeometry.coordinateSpace`, puis la commande
  suivante a recompilé la cible finale sans relancer l'app (connexion demandée
  au propriétaire). Les assertions et la production n'ont pas changé.

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' \
  -parallel-testing-enabled NO -disableAutomaticPackageResolution build-for-testing
```

- PASS : `TEST BUILD SUCCEEDED`, aucun diagnostic Swift ; journal
  `/private/tmp/wander-proximity-final-build.log`.
- Diagnostics restants : versions d'extensions préexistantes 15 et 27 contre 34
  pour l'app ; extraction de métadonnées ignorée sans dépendance App Intents.
- `git diff --check` réussi ; aucune commande Git mutante exécutée.

### Revue

`ce-simplify-code` : réutilisation, qualité et efficacité examinées ; état de
restauration redondant supprimé, calculs évitables retirés, identités de fixture
extraites de l'enum sans parser une clé textuelle.

`ce-code-review` : trois agents indépendants ont couvert correction,
adversarial, tests, Swift/iOS, maintenabilité, standards, performance,
fiabilité et apprentissages. Les sept derniers axes partagent un même agent,
sans compter leurs conclusions comme sept confirmations indépendantes.
Aucun défaut actionnable restant dans le code. Les écarts de validation sont
consignés dans le todo 025.

Revue externe Cursor/Grok non démarrée : le contrôle automatique a refusé
l'export du code privé, non couvert par l'approbation du sprint. La revue
adversariale a utilisé un agent interne à la tâche, sans contournement.
Artefacts de revue : `/private/tmp/wander-architecture-review-1788577194`.

### Xcode Test Results

**Project:** wander.xcodeproj
**Scheme:** wander
**Simulator:** iPhone 17 Pro, iOS 26.3, déjà démarré
**Build:** Success
**Screens tested:** 1 écran de lancement ; 7 scénarios MapKit en fixture

| Screen or flow | Status | Evidence / notes |
|---|---|---|
| Règles géographiques | PASS | 18 XCTest, seuils, historique, anti-chaîne et identités |
| Cycle MapKit | PASS | 7 XCTest, vrais objets et callbacks, actions d'accessibilité exposées |
| Lancement normal | PASS | Écran de connexion Apple visible ; `/private/tmp/wander-proximity-auth-required.png` |
| Taps, double taps, panoramique, interruption du recentrage | SKIP | Carte inaccessible avant connexion Apple ; aucune simulation du résultat |
| Parcours VoiceOver complet | SKIP | Contrôle des propriétés en test, mais activation dans l'écran complet non exercée |

**Console errors:** aucun crash résiduel dans l'exécution finale des tests ;
messages MapKit de simulateur (`default.csv`, couche Metal initiale de taille
nulle), diagnostics d'initialisation Firebase et mesure de lancement CA observés.
Le démarrage manuel a été observé visuellement ; aucun flux social authentifié
ni ses erreurs réseau n'ont pu être contrôlés.
**Human verifications:** 1 demande de connexion Apple, réponse en attente.
**Failures:** 0 échec résiduel des tests ; crash initial corrigé et retesté.
**Result:** PARTIAL

Le sprint reste `in_progress` et n'a pas de `completed_at`. Pour le clore,
connecter l'app sur le simulateur existant puis exécuter les critères du todo 025.
Aucun sprint suivant n'est lancé ni implicitement approuvé.


### Documentation et Obsidian

- `Backlog features.md` : entrée de refactor mise à jour avec le sprint 01,
  ses résultats et la validation encore attendue ; chantier global laissé ouvert.
- `Documentation technique.md` : diagramme, section Carte, stratégie de tests
  et fichiers repères actualisés. Les deux propriétés `updated` valent
  `2026-09-05T12:07:35+09:00`.
- Contrôle des wikilinks : aucune cible de note manquante. Frontmatter et
  délimiteurs Markdown contrôlés ; un diagramme Mermaid conservé.
- Mode lecture Obsidian confirmé par le contrôle « Mode actuel : Aperçu ».
  Propriétés, diagramme d'architecture, section Carte et section Validation
  observés sans erreur de rendu. Captures :
  `/private/tmp/wander-obsidian-architecture-reading.png`,
  `/private/tmp/wander-obsidian-carte-reading.png`,
  `/private/tmp/wander-obsidian-validation-reading.png`.
- Limite de contrôle visuel : après navigation vers le backlog, le titre natif
  de la fenêtre change mais la capture et l'arbre de contenu restent figés
  sur la note technique. Le rendu du backlog et des nouveaux fichiers repères
  n'est donc pas certifié. Ces deux sections restent à vérifier en mode lecture ;
  aucune copie de coffre de remplacement n'a été créée.
- `ce-compound` : la note de solution existante est actualisée, avec
  `last_updated`, propriété du cycle social et séparation des preuves
  historiques et actuelles. Les validateurs de frontmatter et de liens passent.
  `CONCEPTS.md` a été consulté et reste inchangé : aucun nouveau terme de domaine
  n'est nécessaire pour cette extraction interne. La découverte de
  `docs/solutions/` est déjà couverte par les consignes du dépôt.
- Code review receipt : `status: complete`, aucun défaut actionnable ;
  `/private/tmp/wander-architecture-review-1788577194/review.json`.
  Le verdict de clôture reste « Not ready » à cause des validations manuelles
  ouvertes, sans défaut résiduel établi dans le code.

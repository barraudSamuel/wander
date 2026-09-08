---
title: "Architecture carte sociale — sprint 01"
status: in_progress
date: 2026-09-05
approved_at: 2026-09-05
correction_approved_at: 2026-09-07
correction_started_at: 2026-09-07
row_touch_correction_approved_at: 2026-09-08
row_touch_correction_started_at: 2026-09-08
simulator_gesture_validation_status: completed
simulator_gesture_validation_completed_at: 2026-09-08
simulator_gesture_validation_approved_at: 2026-09-08
started_at: 2026-09-05
owner: Samuel
related:
  - ../../todos/020-ready-p2-refactor-codebase.md
  - ../solutions/2026-09-02-regrouper-marqueurs-par-proximite.md
  - ../solutions/2026-09-02-rendre-interactions-mapkit-immediates.md
tags: [plan, architecture, mapkit, tests]
---

# Architecture carte sociale — sprint 01

## Reproduction tactile sur simulateur approuvée le 8 septembre 2026

Samuel signale que la dernière version est plus buggée et demande que Codex
reproduise lui-même les actions, avec accès temporaire sans authentification
sur simulateur. Il approuve explicitement le plan élargi par « j'approuve ».
Les 37 tests précédents ne valident pas ses gestes ni le correctif de délai.

Résultat attendu : reproduction visible du défaut puis correction vérifiée par
les mêmes gestes. L'exécution utilise l'iPhone 17 iOS 26.3 déjà démarré
`6F13855D-10B8-45AF-9205-17C8393379E3`, sans installer de runtime. Le scénario
`DebugSocialMapScenario` est compilé uniquement en Debug sur simulateur et
activé par `-debug-social-map`. Il utilise la vraie carte, ses groupes, la fiche
et le formulaire d'événement avec sa confirmation d'annulation, avec des
utilisateurs/événements fictifs et des opérations en mémoire. Son conteneur
SwiftData est également en mémoire. Le lancement normal conserve
l'authentification et Firebase par défaut.

Fichiers autorisés : `wander/wanderApp.swift`, `wander/WanderAppDelegate.swift`,
nouveau `wander/DebugSocialMapScenario.swift`, `wander/LocationTracker.swift`,
`wander/OutingPlanComposerView.swift`, `wander/MapWithFogView.swift`,
`wander/MapSocialProximityController.swift`,
`wander/MapSocialClusterAnnotationView.swift`,
`wanderTests/MapSocialProximityControllerTests.swift`, nouveaux tests dans
`wanderUITests/`, `wander.xcodeproj/project.pbxproj`,
`wander.xcodeproj/xcshareddata/xcschemes/wander.xcscheme`, ce plan,
`todos/025-ready-p2-valider-gestes-carte-sociale-apres-extraction.md`,
`docs/solutions/2026-09-02-regrouper-marqueurs-par-proximite.md` et les notes
Obsidian `Backlog features.md`, `Documentation technique.md`,
`Documentation UX.md` du coffre Wander existant.

- [x] Plan élargi explicitement approuvé avant implémentation.
- [x] Créer le scénario local sans initialiser auth, synchronisation, push ou stockage persistant.
- [x] Ajouter la cible UI et piloter le vrai écran du simulateur.
- [x] Capturer le défaut actuel et mesurer l'intervalle entre touches rapprochées.
- [x] Corriger uniquement la cause établie, en comparant notamment le dernier changement de recognizer.
- [x] Rejouer l'ouverture/fermeture immédiate, les deux lignes d'événement, leur annulation dans les deux ordres et un groupe mixte.
- [x] Terminer la suite finale incluant les groupes d'utilisateurs, le panoramique, le pincement et le double tap.
- [x] Compiler en Release et vérifier l'absence du scénario et de son argument dans le binaire.
- [x] Terminer l'exécution finale des 37 tests existants et des 6 tests UI.
- [x] Vérifier le lancement normal et son authentification.
- [x] Installer la version finale sur l'iPhone physique.
- [x] Effectuer les revues de réutilisation, qualité et efficacité, puis la revue indépendante finale.
- [x] Actualiser les trois notes Obsidian et vérifier leur rendu en lecture.

### Cause reproduite et correctif vérifié sur les taps rapprochés

La trace avant correction établit que `touchesEnded` reçoit bien le deuxième
tap, 63 ms puis 113 ms après l'ouverture. La fermeture synchrone provoque
`collapse`, puis `didDeselect` et un nouveau `didSelect` du même groupe, qui le
rouvre. Le défaut observé est donc une réouverture native après la fermeture,
pas une absence de réception de ce deuxième toucher. Preuve :
`/private/tmp/wander-rapid-native-reselection-before.log`.

La fermeture est désormais placée sur la file principale avec
`DispatchQueue.main.async`, sans délai fixe. `socialPressGeneration` et
`presentationRevision` invalident la fermeture différée si un nouvel appui,
une sélection de ligne, une action accessible ou le démontage de la carte
survient avant son exécution. L'observateur reste `.possible` après un tap
valide, comme dans la version précédente ; ce changement seul ne corrigeait
pas le défaut. Toutes les traces temporaires ont été retirées du code.

### Validation acquise de cette reprise

- Onze cycles d'ouverture puis fermeture de groupes d'événements réussissent,
  avec 37 à 336 ms entre les touches réellement reçues. Log :
  `/private/tmp/wander-scenario-deferred-console.log`.
- Onze cycles de groupe mixte réussissent, avec 537 à 643 ms entre touches.
  Log : `/private/tmp/wander-scenario-mixed-console.log`.
- La sélection d'Amina puis la fermeture par le fond réussissent lors du
  pilotage manuel du simulateur.
- Les trois premiers tests UI passent : annulation complète dans chacun des
  deux ordres, via le vrai formulaire et sa confirmation, et fermeture par le
  fond. Rapport : `/private/tmp/wander-scenario-ui-tests.xcresult`.
- La compilation Release passe. La recherche de chaînes dans le binaire ne
  retrouve ni le scénario ni son argument de lancement. Log :
  `/private/tmp/wander-scenario-release-build.log`.
- La revue de réutilisation ne relève aucun défaut. Les revues qualité et
  efficacité ont conduit à stabiliser les dates des amis fictifs et à calculer
  leurs présentations une seule fois. Les coordonnées de tap des tests UI
  sont conservées : les assertions sur le titre et le marqueur vérifient que
  le bon élément a été touché. Ces tests couvrent la typographie par défaut.
- La revue indépendante finale ne relève aucun défaut matériel supplémentaire.

Les avertissements préexistants concernent les versions des extensions
`15`/`27`, différentes de celle de l'app `35`, et l'extraction des métadonnées
AppIntents. Ils ne sont pas présentés comme de nouveaux diagnostics du correctif.

### Validation finale de la reprise

Les 37 tests existants et cinq tests UI passent dans
`/private/tmp/wander-scenario-final-tests.xcresult`. Ce premier lancement se
termine avec le code 65 : le sixième test ciblait un élément `Map` absent de
l'arbre XCTest, avant tout pincement. La correction de ce sélecteur a permis
d'observer un vrai pincement, accompagné de rotation. Une assertion fondée sur
la seule ordonnée du groupe ne mesurait pas ce zoom. La version finale compare
la distance entre deux ancrages géographiques et attend sa mise à jour pendant
l'animation MapKit. Elle vérifie le pincement et le double tap avec succès,
code 0, à 10:41:40 : `/private/tmp/wander-scenario-zoom-final.xcresult`.
Commandes de validation exécutées :

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'id=6F13855D-10B8-45AF-9205-17C8393379E3' \
  -derivedDataPath /Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx \
  -disableAutomaticPackageResolution -skipPackageUpdates -parallel-testing-enabled NO \
  -only-testing:wanderTests/MapSocialProximityControllerTests \
  -only-testing:wanderTests/MapSocialProximityStateTests -only-testing:wanderUITests \
  -resultBundlePath /private/tmp/wander-scenario-final-tests.xcresult test

xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'id=6F13855D-10B8-45AF-9205-17C8393379E3' \
  -derivedDataPath /Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx \
  -disableAutomaticPackageResolution -skipPackageUpdates -parallel-testing-enabled NO \
  -only-testing:wanderUITests/MapSocialGestureUITests/testNativePinchAndDoubleTapZoom \
  -resultBundlePath /private/tmp/wander-scenario-zoom-final.xcresult test
```

Les deux essais intermédiaires du test sont conservés dans
`/private/tmp/wander-scenario-zoom-tests.xcresult` et
`/private/tmp/wander-scenario-zoom-verified.xcresult`. Le code produit n'a pas
changé pendant ces ajustements du test. Les 43 tests distincts sont ainsi
validés sur deux exécutions, sans prétendre que le premier rapport est vert.

Les gestes UI couvrent les deux ordres d'annulation complète, l'ouverture et
la fermeture, les groupes mixtes et de personnes, un panoramique avec groupe
ouvert, le pincement et le double tap. Les tests UI ignorent explicitement les
builds Release et les appareils physiques, qui ne contiennent pas le scénario.
Trois nouveaux cycles par pointeur réussissent ensuite dans la version finale
sans traces. Vidéo : `/private/tmp/wander-gestes-corriges-extrait.mp4` ; capture :
`/private/tmp/wander-final-rapid-closed.jpeg`.

Le lancement Debug sans argument affiche « Continue with Apple » : capture
`/private/tmp/wander-normal-auth-final.jpeg`. La compilation normale pour
l'iPhone physique réussit, code 0 : `/private/tmp/wander-scenario-iphone-build.log`.
L'app est installée sur l'iPhone de Samuel puis lancée sans débogueur à 10:43:58.
Le bypass n'est pas compilé sur cet appareil. Aucun parcours tactile sur cet
iPhone ni aucune écriture Firebase n'est déclaré validé par les essais locaux.

Les trois notes Obsidian sont actualisées au `2026-09-08T10:42:29+09:00`.
Frontmatters YAML, wikilinks et blocs Markdown passent les contrôles. Les
paragraphes modifiés, propriétés et listes sont vérifiés en mode Aperçu.
Captures : `/private/tmp/wander-simulator-backlog.jpeg`,
`/private/tmp/wander-simulator-technique.jpeg`,
`/private/tmp/wander-simulator-technique-validation.jpeg`,
`/private/tmp/wander-simulator-ux.jpeg`,
`/private/tmp/wander-simulator-ux-validation.jpeg`.
Les diagrammes et tableaux préexistants ne changent pas. Le sous-objectif de
reproduction/correction sur simulateur est terminé. Le sprint global reste
`in_progress` et le todo 025 `ready` pour VoiceOver, les grands groupes et la
validation du parcours de production avec Firebase.

Risques : l'attente d'inactivité des tests UI peut masquer les taps rapprochés ;
mesurer les touches réellement reçues, compléter par pilotage visuel sans pause
entre clics et ne pas déduire la réussite d'un test qui attend deux secondes.
Le scénario local ne valide ni les écritures Firebase ni les observateurs et la
réconciliation de `ContentView`. Les mutations utilisent le vrai formulaire et
sa confirmation, pas une commande qui retire directement un marqueur.
Le lancement normal et les opérations de service réelles gardent leurs valeurs
par défaut. Les modifications fantôme préexistantes restent préservées.

Exécution native dans le checkout partagé, sans aucune commande Git mutable.
`ce-work`/`ce-debug` pour le déroulé ; validation équivalente manuelle à
`ce-test-xcode` avec xcodebuild/simctl et contrôle du simulateur, car les outils
XcodeBuildMCP ne sont pas exposés. Le statut global du sprint reste en cours.


## Historique de la première reprise tactile du 8 septembre 2026

Les constats ci-dessous précèdent la reproduction sur simulateur documentée
plus haut. Samuel a ensuite signalé que la version était plus buggée.
L'hypothèse d'un deuxième toucher non reçu est invalidée par la trace native ;
les 37 tests de 09:58:54 ne validaient pas ce défaut. Les restrictions et les
étapes encore en attente dans cet historique décrivent cette première reprise,
avant l'autorisation du scénario sur simulateur.

### Retour de validation à 09:31

Samuel indique que l'ouverture est « quasiment bonne », mais signale un défaut
en ouvrant le groupe puis en touchant immédiatement le fond. La vidéo
`ScreenRecording_09-08-2026 09-31-06_1.MP4`, longue de 6 secondes, montre des
ouvertures et fermetures rapprochées de la liste de deux événements, sans
sélection de ligne ni suppression. Ce retour poursuit le critère de fermeture
volontaire déjà inclus dans cette reprise ; il ne valide pas la suppression.

La revue de la vue ne trouve pas de completion d'animation capable de changer
`isExpanded`. Les callbacks natifs tardifs du même groupe restent une hypothèse
à tracer ; leur génération est capturée à la réception du callback, pas au tap.
La précision suivante de Samuel réoriente le diagnostic : la carte reste
utilisable, mais le tap de fond immédiatement après ouverture semble ignoré ;
attendre environ deux secondes puis retoucher permet de fermer. À ce stade,
cela avait orienté le diagnostic vers la réception du second toucher. La
reproduction ultérieure sur simulateur a établi sa réception et la réouverture.

Dans la version observée à cette étape, `PassiveMapTapObserver` se termine en `.failed` après chaque
tap valide. Selon la machine d'états UIKit, cet état terminal peut durer jusqu'à
la fin de la séquence native, alors que notre callback d'ouverture a déjà été
émis. Le correctif ciblé consiste à maintenir l'observateur passif en `.possible`
après un tap valide, pour recevoir le suivant sans attendre `reset`. Les
déplacements, gestes à plusieurs doigts et annulations restent des échecs.
La durée de deux secondes et l'arbitrage privé MapKit ne sont pas établis par
les traces disponibles. Référence :
[machine d'états UIKit](https://developer.apple.com/documentation/uikit/about-the-gesture-recognizer-state-machine).

Cette étape reste dans la fermeture volontaire et les fichiers du plan approuvé.
Ajouter les tests du recognizer dans la cible existante, vérifier leur échec
avant correction puis leur réussite si l'iPhone permet l'exécution, compiler
l'app et rejouer l'ouverture suivie immédiatement d'un tap de fond. Aucun
simulateur ne sera lancé. Le risque à vérifier concerne le double tap natif,
le panoramique et les touches à plusieurs doigts. Les tests directs des callbacks
de touches ne remplacent pas le toucher physique ni l'arbitrage complet MapKit.

Incident de diagnostic : les premières traces LLDB utilisaient une commande
Python `script print`. Le processus `lldb-rpc-server` s'est bloqué dans
`ScriptInterpreterPythonImpl::SetStdHandle` → `NativeFile::Flush` → `flockfile`,
alors que son thread de lecture attendait dans `fgets`. Samuel a alors signalé
que l'app ne répondait plus aux touches. Cette suspension provenait de la trace,
pas d'une preuve du défaut initial. Pile locale :
`/private/tmp/wander-lldb-hang.sample`. Le seul processus LLDB concerné a été
arrêté, puis Wander relancé sur l'iPhone. Les cinq points de trace ont été
supprimés explicitement. La reprise utilise uniquement deux backtraces natives,
sans script Python, sur l'ouverture et la fermeture du groupe.

Les deux dernières traces ont également été retirées du navigateur de points
d'arrêt Xcode après une perte de connexion au débogueur. Samuel confirme que
l'app reste utilisable ; le défaut résiduel est le tap immédiat ignoré.

#### Validation de l'observateur de touches

`PassiveMapTapObserver` reste maintenant `.possible` après un tap valide.
L'observateur devient interne au module pour tester ses callbacks ; aucun API
public, objet de configuration ou état supplémentaire n'est ajouté. Les chemins
d'échec et les callbacks de sélection/désélection restent inchangés.

Les trois nouveaux tests de callbacks ont été exécutés sur l'iPhone physique
avant modification : 3 réussites, code 0. Rapport :
`/private/tmp/wander-rapid-tap-red.xcresult`, log :
`/private/tmp/wander-rapid-tap-red.log`. Malgré le nom de l'artefact, ce résultat
est une base verte, pas une reproduction rouge du défaut. Les appels directs
avec un `UITouch` de test ne reproduisent pas le maintien d'état par UIKit.
La revue a donc fait renommer le test en
`testPassiveTapObserverReportsConsecutiveTouchCallbacks` et retirer ses
assertions d'état qui ne distinguaient pas les deux comportements.

Les passes de réutilisation et d'efficacité ne relèvent aucun défaut. La passe
qualité a clarifié la limite du test. Sa suggestion d'extraire une machine
d'états dédiée n'est pas retenue : cela ajouterait une abstraction sans couvrir
l'arbitrage UIKit manquant. L'accès interne reste limité au module et à sa cible
de tests. `Code review: targeted manual due to unrelated branch work` : revue
du seul diff de cette fermeture, sans défaut matériel supplémentaire identifié.

La validation après modification réussit sur l'iPhone connecté : les 19 tests
d'intégration et de callbacks et les 18 tests de proximité passent, soit 37/37,
code 0, le 8 septembre à 09:58:54. Rapport :
`/private/tmp/wander-rapid-tap-final.xcresult`.
Le toucher physique immédiat, le double tap, le panoramique et le pincement
restent à confirmer dans l'app ; aucune réussite runtime n'est anticipée.

La compilation iPhone de la version modifiée et des tests termine avant le
précontrôle de lancement. Celui-ci a attendu le déverrouillage de l'iPhone,
puis les tests ont terminé avec succès. Commande exécutée :

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'platform=iOS,name=iPhone de Samuel' -destination-timeout 30 \
  -derivedDataPath /Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx \
  -disableAutomaticPackageResolution -skipPackageUpdates \
  -parallel-testing-enabled NO \
  -only-testing:wanderTests/MapSocialProximityControllerTests \
  -only-testing:wanderTests/MapSocialProximityStateTests \
  -resultBundlePath /private/tmp/wander-rapid-tap-final.xcresult test \
  > /private/tmp/wander-rapid-tap-final.log 2>&1
```

Les trois notes Obsidian sont actualisées au `2026-09-08T10:00:14+09:00`, avec
frontmatters, wikilinks et blocs Markdown valides. Leurs paragraphes affectés
sont vérifiés en mode lecture, ainsi que le nouveau critère de fermeture UX.
Captures : `/private/tmp/wander-rapid-tap-backlog.jpeg`,
`/private/tmp/wander-rapid-tap-technique.jpeg`, `/private/tmp/wander-rapid-tap-ux.jpeg`
et `/private/tmp/wander-rapid-tap-ux-validation.jpeg`. `git diff --check` passe.

Après les tests, la version modifiée est relancée sans débogueur ni point
d'arrêt avec `devicectl`, identifiant vérifié dans le build :
`com.iterar.wander.wander`. Le lancement réussit, code 0 ; reçu local :
`/private/tmp/wander-rapid-tap-launch-correct.json`. Le parcours physique de
fermeture immédiate est soumis à Samuel et reste en attente de son résultat.

Samuel a répondu « corrige » au plan ciblé présenté après la vidéo
`ScreenRecording_09-08-2026 08-56-48_1.MP4`. Celle-ci montre la fiche du deuxième
événement, Café, qui apparaît puis disparaît à trois reprises avant toute
édition ou suppression. Aucun crash du processus n'est visible. Le correctif
du 7 septembre ne résout donc pas le cas signalé.

### Périmètre et démarche approuvés

Tracer la sélection/désélection et les callbacks de caméra pour distinguer le
tap d'une ligne d'une fermeture volontaire. Corriger leur coordination, puis
ajouter les régressions pour deux événements aux mêmes coordonnées et leur
retrait dans les deux ordres. Préserver le tap de fond, le panoramique, le zoom,
VoiceOver, les seuils de proximité et les modifications préexistantes.

La deuxième ligne recouvre les bounds natifs du marqueur compact, ce qui rend
plausible un double traitement du même tap. Le chemin actuel de désélection
native peut effacer le focus dès que la sélection en attente est consommée.
L'ordre exact des callbacks sur l'iPhone reste à observer avant de le déclarer
cause vérifiée. Aucun délai arbitraire ne doit remplacer une règle de sélection.

Fichiers autorisés :

- `wander/MapSocialClusterAnnotationView.swift` : interactions des lignes.
- `wander/MapSocialProximityController.swift` : sélection et callbacks natifs.
- `wander/MapWithFogView.swift` : coordination des gestes et de la fiche.
- `wanderTests/MapSocialProximityControllerTests.swift` : régressions natives.
- Ce plan, `todos/025-ready-p2-valider-gestes-carte-sociale-apres-extraction.md`
  et `docs/solutions/2026-09-02-regrouper-marqueurs-par-proximite.md`.
- Obsidian `Backlog features.md`, `Documentation technique.md` et
  `Documentation UX.md` : état du correctif, carte, validation et parcours.

### Checklist et validation

- [x] Plan ciblé proposé puis approuvé explicitement le 8 septembre.
- [x] Tracer le chemin qui ferme la fiche, ou consigner la limite runtime exacte.
- [x] Corriger la coordination sans modifier les données ni l'apparence.
- [x] Couvrir chaque ligne à coordonnées identiques, le retrait de chaque événement,
  la fermeture volontaire et une désélection native tardive.
- [x] Simplifier et effectuer la revue indépendante du diff de cette reprise.
- [x] Compiler l'app et les tests, puis contrôler `git diff --check`.
- [ ] Vérifier le comportement sur l'iPhone de Samuel.
- [x] Actualiser les documents et vérifier les notes Obsidian en mode lecture.

Aucun simulateur ne sera démarré conformément au choix précédent de Samuel.
La compilation seule ne valide pas les touches réelles ; la vérification
sur l'iPhone connecté reste distincte. Les traces ne doivent contenir aucun
identifiant métier ou position. Aucun Git mutateur, commit ou déploiement Firebase.

### Résultat local du 8 septembre

Le correctif ajoute un recognizer de tap à chaque `MapSocialClusterRowControl`.
`shouldBeRequiredToFailBy` impose aux taps des vues ancêtres d'attendre l'échec
du tap de la ligne. Son action déclenche la sélection après reconnaissance,
et `cancelsTouchesInView` empêche le même toucher de déclencher aussi
`touchUpInside`. Le target/action du contrôle et les actions d'accessibilité
du groupe sont conservés. Aucune nouvelle logique de restauration de focus,
temporisation ou modification de delegate MapKit n'est introduite ; les
callbacks du contrôleur et du Coordinator du 7 septembre restent inchangés.

La priorité utilise les API publiques décrites par Apple dans
[Preferring one gesture over another](https://developer.apple.com/documentation/uikit/preferring-one-gesture-over-another)
et [Attaching gesture recognizers to UIKit controls](https://developer.apple.com/documentation/uikit/attaching-gesture-recognizers-to-uikit-controls).
Les panoramiques et autres gestes qui ne sont pas des taps ne reçoivent pas
cette dépendance. Leur comportement physique et VoiceOver restent à vérifier.

Deux tests supplémentaires ouvrent la vraie vue de groupe et activent chacun
des contrôles de ligne pour deux événements exactement superposés, puis retirent
la source sélectionnée. Ils vérifient le singleton restant, l'absence de sélection
obsolète, la notification unique et la priorité du recognizer de ligne face à un
tap ancêtre, sans imposer cette priorité à un panoramique. La suite comprend
16 tests du contrôleur et 18 tests de proximité. Ces tests utilisent des objets
MapKit réels mais n'injectent pas de touches physiques. Ils sont compilés,
non exécutés ; aucune preuve rouge/verte n'est revendiquée.

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx \
  -disableAutomaticPackageResolution -skipPackageUpdates -quiet build-for-testing \
  > /private/tmp/wander-row-touch-build.log 2>&1
```

Compilation : code 0. Deux avertissements préexistants concernent les versions
15 et 27 des extensions contre 35 de l'app ; aucun nouveau diagnostic Swift.
`git diff --check` passe. Les trois passes `ce-simplify-code`, réutilisation,
qualité et efficacité, ne relèvent aucun changement utile à appliquer.

`Code review: skipped (ce-code-review unavailable)` : l'invocation du protocole
se termine avec `status: failed`, car le collecteur terminal bloquant requis
est indisponible. Une revue statique indépendante équivalente a examiné le
diff de cette reprise sans trouver de défaut matériel. Reçu :
`/private/tmp/wander-row-touch-review-lxcxjen9/ce-code-review-receipt.json`.
Rapport manuel : `/private/tmp/wander-row-touch-review-lxcxjen9/manual-review.json`.

Deux points de trace LLDB automatiques, `didDeselect` et `collapse`, ont été
installés temporairement dans la session Xcode de l'iPhone. Aucune occurrence
du parcours demandé n'a été observée pendant leur présence. Ils ont ensuite
été supprimés explicitement, sans toucher aux autres réglages du débogueur.
La vidéo prouve la perte de sélection ; elle ne prouve pas quel recognizer
MapKit l'a provoquée. Le correctif traite la concurrence de taps identifiée
dans le code, avec validation sur l'iPhone encore ouverte.

Xcode a ensuite recompilé, installé et lancé la version corrigée sur l'appareil
physique « iPhone de Samuel ». L'état « Running wander on iPhone de Samuel »
est confirmé dans Xcode. Aucun simulateur n'a été démarré. Ce lancement réussi
ne valide pas le geste : la réponse de Samuel à l'essai de Café, puis le parcours
Modifier → Supprimer, restent attendus. Validation globale : partielle.

Les trois notes Obsidian ont leur propriété `updated` au
`2026-09-08T09:18:56+09:00`. Leurs sections modifiées sont vérifiées en mode
lecture : suivi du correctif dans le backlog, carte et validation dans la note
technique, comportement attendu et parcours manuel dans la note UX. Les
frontmatters YAML, les liens internes et les clôtures de blocs de code sont
valides. Aucun tableau ni diagramme n'a été modifié par cette reprise.
Captures locales : `/private/tmp/wander-row-touch-obsidian-backlog.jpeg`,
`/private/tmp/wander-row-touch-obsidian-technique.jpeg`,
`/private/tmp/wander-row-touch-obsidian-validation.jpeg`,
`/private/tmp/wander-row-touch-obsidian-ux.jpeg` et
`/private/tmp/wander-row-touch-obsidian-ux-validation.jpeg`.

## Correctif de stabilité approuvé le 7 septembre 2026

Samuel a explicitement approuvé le plan présenté après lecture de sa vidéo
`ScreenRecording_09-07-2026 16-51-31_1.MP4`. Ce correctif appartient au sprint 01
encore ouvert ; il n'autorise aucun sprint suivant. Le statut repasse par
`approved` avant la reprise de l'implémentation.

### Résultat attendu et périmètre

Une sélection dans un groupe de deux événements ou dans un groupe mixte doit
ouvrir le membre choisi et le conserver pendant le recentrage automatique.
Une fermeture volontaire restaure le groupe sans doublon ni membre manquant.
Les seuils 20/25 mètres, l'indépendance au zoom, Firebase et les données métier
restent hors du correctif. Aucun Git mutateur, commit ou publication.

La vidéo montre notamment un retour au groupe sans fiche vers 6–9 secondes
et une sélection brève de Sam vers 14–15 secondes. Aucun saut horizontal propre
à la liste n'est confirmé. La cause runtime exacte reste à reproduire ; les
défauts corrigés ci-dessous sont établis par lecture du code.

### Fichiers du correctif

- `wander/MapSocialProximityController.swift` : focus, synchronisation native,
  sélection différée et protection du recentrage.
- `wander/MapWithFogView.swift` : coordination des taps et callbacks MapKit.
- `wanderTests/MapSocialProximityControllerTests.swift` : régressions des paires
  et intégration avec les callbacks réels du Coordinator.
- Ce plan, `todos/025-ready-p2-valider-gestes-carte-sociale-apres-extraction.md`
  et `docs/solutions/2026-09-02-regrouper-marqueurs-par-proximite.md` : résultats,
  limites et apprentissages vérifiés.
- Obsidian `Backlog features.md` : En cours / carte sociale.
- Obsidian `Documentation technique.md` : Carte, Validation et outils.
- Obsidian `Documentation UX.md` : Amis sur la carte, Sorties prévues,
  Points UX encore à valider.

### Checklist du correctif

- [x] Plan proposé puis explicitement approuvé le 7 septembre 2026.
- [ ] Reproduire les transitions avec un test qui échoue avant correction.
- [x] Corriger la sélection et les callbacks obsolètes dans le périmètre approuvé.
- [x] Ajouter et compiler sept tests de régression, dont les transitions A → B
  et membre ↔ groupe, le remplacement de source et les sélections différées.
- [x] Simplifier puis effectuer une revue indépendante du diff du correctif.
- [x] Compiler l'app et les tests sans nouveau diagnostic Swift.
- [ ] Exécuter les tests de régression.
- [ ] Rejouer deux événements, personne + événement, recentrage, fermeture
  volontaire, taps rapides et VoiceOver sur appareil.
- [x] Actualiser les trois notes Obsidian, leurs propriétés `updated` et les
  sections touchées, puis vérifier le rendu en mode lecture.

### Risques et validation

Le 7 septembre, les appareils existants sont tous arrêtés. Samuel a choisi
explicitement « Continuer sans tests sur simulateur ». Aucun appareil ne sera
démarré : compilation de l'app et des tests uniquement, revue statique et
documentation des scénarios non exécutés. La reproduction avant correction,
les tests runtime, les gestes et VoiceOver restent non validés.

MapKit peut livrer des callbacks synchrones, différés ou réentrants pendant
le remplacement des annotations. Les tests doivent suivre l'identité native,
le membre logique sélectionné et le nombre d'actions produit, y compris pour
une paire dont le représentant disparaît lors de l'extraction.
Les modifications locales préexistantes du mode fantôme sont conservées.
La validation runtime est reportée conformément au choix de Samuel.
Si l'accès à la carte authentifiée ou au coffre Obsidian empêche une validation,
les sections exactes restant à vérifier seront consignées ici sans revendiquer
un résultat positif.

### Résultat et revue du correctif

- Le focus final est publié avant de synchroniser les annotations : le passage
  A → B ne reconstruit plus un groupe intermédiaire qui détache B.
- Le remplacement d'une annotation par une nouvelle instance du même membre
  reprend la sélection native sans fermer la fiche produit.
- Une génération invalide les sélections et désélections différées obsolètes.
  Les callbacks natifs revalident l'identité des vues et la sélection courante.
- Le contrôleur possède la fermeture produit. Les transitions membre → groupe
  et groupe → membre libèrent explicitement la présentation précédente.
- Les gestes actifs ferment la présentation ; les changements de caméra
  automatiques la conservent. Le tap sur le fond annule aussi une sélection
  encore en attente. La détection des gestes réels reste à exercer sur appareil.
- `ce-simplify-code` : passes réutilisation, qualité et efficacité effectuées ;
  gardes existantes réutilisées, callback visuel doublonné supprimé, parcours
  des gestes évité sans présentation active.
- Le protocole automatisé `ce-code-review` n'a pas pu terminer : son collecteur
  exige un résultat terminal bloquant, indisponible avec les primitives de
  collaboration de cette session. Le reçu porte `status: failed`. Une revue
  statique indépendante équivalente a été réalisée sur les trois fichiers
  de code/tests du correctif, sans exporter le reste du diff local.
- Cette revue a signalé puis vérifié la correction de trois constats P2 :
  libération du membre avant ouverture d'un groupe, fermeture du groupe avant
  activation d'un membre et attente de la file principale avant les assertions
  des tests de désélection différée. Aucun défaut matériel restant identifié
  par cette revue statique ; aucune preuve runtime revendiquée.
- Rapport : `/private/tmp/wander-social-review-ro2_tz65/manual-review.json`.
  Reçu du protocole :
  `/private/tmp/wander-social-review-ro2_tz65/ce-code-review-receipt.json`.
- Les fichiers préexistants du mode fantôme sont préservés. Aucun changement
  Git, commit, déploiement ou sprint suivant.

### Validation du 7 septembre 2026

XcodeBuildMCP étant absent, l'équivalent CLI de `ce-test-xcode` est utilisé.
La commande finale, exécutée après la dernière modification des tests, termine
avec le code 0 ; son journal est vide, sans diagnostic :

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx \
  -disableAutomaticPackageResolution -skipPackageUpdates -quiet build-for-testing \
  > /private/tmp/wander-selection-reviewed-build.log 2>&1
```

| Vérification | Résultat | Preuve ou limite |
|---|---|---|
| Compilation app et cible de tests | PASS | Commande finale ci-dessus, code 0 |
| Tests du contrôleur | COMPILÉS | 14 scénarios, dont 7 nouveaux ; non exécutés |
| Tests de règles de proximité | NON EXÉCUTÉS | Les 18 tests existants sont inchangés |
| Reproduction causale de la vidéo | NON VÉRIFIÉE | Pas de test runtime avant/après |
| Gestes, fiche produit et VoiceOver dans l'app | SKIP | Samuel a choisi de continuer sans tests sur simulateur |
| Revue statique indépendante | PASS | Trois constats corrigés ; rapport cité ci-dessus |
| `git diff --check` | PASS | Aucun problème d'espacement |
| Notes Obsidian | PASS | Propriétés, liens et sections affectées vérifiés en mode lecture |

Les builds de référence et intermédiaire signalent deux avertissements
préexistants : `CFBundleVersion` des extensions 15 et 27, contre 35 pour l'app.
Ils figurent dans `/private/tmp/wander-selection-before-build.log` et
`/private/tmp/wander-selection-after-build.log`. Aucun nouveau diagnostic Swift
n'a été observé. Aucune console runtime n'a été surveillée.

Résultat global : **PARTIAL**. Le sprint reste `in_progress`, sans
`completed_at`, et le todo 025 reste ouvert pour la validation sur appareil.
Les résultats du 5 septembre plus bas sont historiques ; ils ne valident pas
le correctif du 7 septembre.

### Documentation du correctif

Les trois notes Obsidian ont été actualisées avec
`updated: 2026-09-07T18:19:33+09:00`. Le mode lecture « Aperçu » a été confirmé.
Les sections En cours du backlog, Carte et Validation et outils de la note
technique, puis les groupes et Points UX encore à valider de la note UX
ont été observées sans erreur de rendu. Les propriétés et liens introductifs
sont conservés. Captures locales :

- `/private/tmp/wander-selection-obsidian-backlog.png`.
- `/private/tmp/wander-selection-obsidian-technique.png`.
- `/private/tmp/wander-selection-obsidian-technique-validation.jpeg`.
- `/private/tmp/wander-selection-obsidian-ux-groups.jpeg`.
- `/private/tmp/wander-selection-obsidian-ux-validation.jpeg`.

Le frontmatter YAML et les délimiteurs de blocs de code des six documents
affectés sont valides ; les wikilinks des trois notes ciblent des notes
existantes. Aucun diagramme ni tableau n'a été modifié par ce correctif.
`ce-compound` ne produit pas de nouvel apprentissage déclaré validé, faute de
preuve runtime : seule la note de solution existante est actualisée avec
les changements locaux et leurs limites. `CONCEPTS.md` reste inchangé.

## Outcome — extraction du 5 septembre 2026

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

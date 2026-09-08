---
title: "Carte plein écran derrière les barres système"
status: completed
date: 2026-09-08
approved_at: 2026-09-08
completed_at: 2026-09-08
owner: Samuel
tags: [plan, map, ux]
---

# Carte plein écran derrière les barres système

## Approbation et résultat

Samuel demande de retirer les bandes de safe area en haut et en bas. Il a
approuvé le plan proposé dans la conversation par « impelmente ». Explorer
dessine sa carte jusqu'aux quatre bords, derrière l'heure et la barre d'onglets.
Les commandes flottantes restent dans une zone accessible. Une fiche ouverte
prolonge son fond derrière la barre d'état ; sa carte descend jusqu'en bas.
Les arrondis et le correctif Metal restent en place.

## Périmètre et fichiers

- `wander/MapDetailSplitView.swift` : mesurer séparément l'écran entier et ses
  insets, rendre le conteneur bord à bord, transmettre les insets des commandes,
  garder la taille native totale indépendante de la fiche.
- `wander/ContentView.swift` : carte derrière la barre d'onglets, commandes
  flottantes et états de contenu positionnés selon les insets.
- `wander/MapViewportView.swift`, `wander/MapWithFogView.swift` : zone sûre de
  contenu explicite pour MapKit, ses mentions et les indicateurs/groupes.
- `wander/FriendEdgeRailView.swift` : rail et geste de bord dans la zone utilisable.
- `wander/DebugSocialMapScenario.swift` : variante de scénario dans un TabView
  pour vérifier l'étendue réelle ; conserver les scénarios existants.
- `wanderTests/MapViewportViewTests.swift`,
  `wanderUITests/MapSocialGestureUITests.swift` : géométrie pleine fenêtre,
  insets et stabilité native pendant les trois positions et la fermeture.
- Ce plan, le plan précédent et `todos/` si une revue identifie un défaut.
- Notes Obsidian dans
  `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Backlog features.md`, `Documentation UX.md`, `Documentation technique.md`,
  `00 - Wander.md`. Actualiser `updated` et vérifier leur lecture.

## Mise en œuvre

- [x] Étendre le conteneur de carte en conservant les insets pour ses contenus.
- [x] Placer boutons, rail, fiche et éléments natifs dans leur zone accessible.
- [x] Ajouter les contrôles plein écran et préserver le contrat Metal.
- [x] Compiler et contrôler le simulateur iPhone 17 déjà lancé.
- [x] Installer et vérifier sur iPhone 12 mini connecté avec Metal actif.
- [x] Simplifier, revoir et actualiser les notes.

## Risques et validation

- Un frame bord à bord ne prouve pas qu'aucun fond opaque ne couvre la carte :
  capturer et examiner l'écran fermé et avec fiche, derrière les barres.
- Éviter les boutons sous l'encoche, le rail derrière les onglets ou les
  mentions MapKit masquées. Préserver les gestes de carte et le défilement.
- Ne pas faire varier les bounds natifs de MapKit à l'ouverture/fermeture.
- Vérifier les limites de la fenêtre, les insets et les changements de position,
  puis le parcours réel sur iPhone avec Metal API Validation actif.
- Reprendre la taille de texte et les réglages du simulateur tels qu'ils sont.
  Aucun autre appareil/runtime ne sera créé ou démarré.
- Arbre non commité des deux tâches précédentes offert par la continuité de la
  demande : préserver les autres changements. Aucun Git mutateur ni publication.
- Firebase, données d'événement et permissions restent hors du périmètre.

## Acceptation

- [x] Carte fermée couvrant la fenêtre derrière la barre d'état et les onglets.
- [x] Fiche arrondie ouverte, commandes accessibles et carte jusqu'au bas.
- [x] Bounds MapKit stables et gestes opérationnels.
- [x] Résultats de tests, captures et limites exactes consignés.
- [x] Notes Obsidian actualisées et relues.

## Résultats et revue

- Le conteneur mesure la fenêtre entière séparément des insets. Les quatre
  bords de dessin ignorent la safe area ; la fiche, les boutons, les groupes
  et le rail conservent des marges de contenu explicites. Seul Explorer masque
  le fond de sa barre d’onglets native.
- `MapViewportView` combine les insets système et explicites par maximum, sans
  réduire sa fenêtre visible ni changer les bounds natifs pendant les transitions.
- `/tmp/wander-fullscreen-focused.xcresult` : les cinq tests du viewport passent.
  Le premier contrôle UI échoue uniquement sur une égalité flottante AX,
  873,9999999999998 contre 874 pt. La comparaison UI utilise désormais une
  précision de 0,01 pt ; les tests UIKit conservent leurs égalités exactes.
- `/tmp/wander-fullscreen-final.xcresult` : **56/56**, dont 43 tests unitaires et
  13 tests UI. Pleine fenêtre, portrait/paysage, changement d’onglet, trois
  positions, fermeture, stabilité native, groupes, gestes et défilement.
- La revue indépendante trouve deux P2 en paysage, corrigés dans ce périmètre :
  les insets latéraux étaient encore réservés, et le capteur du rail quittait le
  bord physique. Voir `todos/036-done-p2-preserver-bords-et-rail-en-paysage.md`.
- `/tmp/wander-fullscreen-rail-final.xcresult` : **1/1** après le dernier correctif.
  Le test plein écran ouvre aussi le vrai rail depuis le bord physique en paysage,
  vérifie son contenu accessible et sa marge droite. Aucun retrait d’assertion.
- `/tmp/wander-fullscreen-device.xcresult` puis
  `/tmp/wander-fullscreen-device-final.xcresult` : **1/1 chacun**, sans skip,
  sur iPhone 12 mini iOS 26.5.2. Quatre ouvertures/fermetures d’une sortie
  existante, douze changements de position et quatre glissements. Les assertions
  contrôlent aussi la carte aux quatre bords et les commandes accessibles.
- Les journaux d’application exportés pour ces deux exécutions contiennent
  `Metal API Validation Enabled`, sans assertion échouée ni SIGABRT. Aucun
  événement ni paramètre de compte modifié pendant le contrôle.
- Captures physiques fermée/ouverte relues :
  `/tmp/wander-fullscreen-device-attachments/2BD92324-6FAA-4DAE-99CF-E51EAD17FDBA.png`
  et `/tmp/wander-fullscreen-device-attachments/78C33856-AC04-480E-8724-094C8DD968E9.png`.
  La carte remplit les zones derrière l’heure et les onglets. La fiche conserve
  ses arrondis et un en-tête sous l’encoche. Les mentions Apple restent visibles.
- Le fichier de capture XCTest en paysage présente un cadrage incohérent avec
  les frames vérifiés. Le rendu a donc été contrôlé directement dans Simulator
  après la rotation : aucune bande vide. Capture de ce contrôle :
  `/tmp/wander-fullscreen-landscape-verified.png`.
- Build Debug physique du dernier ajustement du rail réussi, installation avec
  données conservées, puis lancement confirmé à **17:19** avec `MTL_DEBUG_LAYER=1`.
  Ce dernier ajustement du rail a été testé en UI sur simulateur ; les cycles
  physiques Metal précèdent cette retouche du rail.
- `git diff --check` passe. Aucun nouvel avertissement Swift ; les deux warnings
  préexistants de CFBundleVersion des extensions 15/27 face à l’app 36 persistent.
- Réutilisation et simplification : même MapKit, insets partagés par environnement,
  corps de carte réutilisé dans le scénario, aucun état de sélection dupliqué.
  Le comportement est documenté dans le code, les tests et les notes ; aucune
  nouvelle solution durable n’est nécessaire au-delà du diagnostic GPU précédent.

### Commandes

```bash
xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'id=6F13855D-10B8-45AF-9205-17C8393379E3' \
  -derivedDataPath /tmp/wander-participant-badge-derived-data \
  -disableAutomaticPackageResolution -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  -resultBundlePath /tmp/wander-fullscreen-final.xcresult \
  -only-testing:wanderTests/MapViewportViewTests \
  -only-testing:wanderTests/MapSocialProximityStateTests \
  -only-testing:wanderTests/MapSocialProximityControllerTests \
  -only-testing:wanderUITests/MapSocialGestureUITests test
```

Le test du rail reprend ces options avec seulement
`-only-testing:wanderUITests/MapSocialGestureUITests/testMapFillsWindowBehindNativeTabBar`
et le résultat `/tmp/wander-fullscreen-rail-final.xcresult`.
Le contrôle physique utilise la destination iPhone connectée, son DerivedData
Xcode existant, et `-only-testing:wanderUITests/MapDeviceSmokeUITests`.
L’équivalent CLI Xcode et Computer Use remplace XcodeBuildMCP absent.

### Limites

Le parcours VoiceOver parlé complet et les transitions sociales réelles du
chantier précédent restent à vérifier ; aucune nouvelle validation n’est
revendiquée pour eux. Les tests grande police/Réduire les animations du correctif
précédent restent documentés dans son plan. La présente vérification conserve
la taille de texte et les réglages existants du simulateur.

### Clôture

Les quatre notes Obsidian ont été actualisées à 17:15:53 et contrôlées en mode
Aperçu : propriétés, paragraphes modifiés, listes et liens internes. Les
vérifications des liens, du frontmatter et des clôtures de blocs passent. Aucun
tableau, callout, diagramme Mermaid ou bloc de code n’a été ajouté ou modifié
dans ces notes. Le simulateur est revenu en portrait ; ses autres réglages
restent inchangés. La dernière revue indépendante confirme les deux P2 résolus,
sans constat restant sur ces corrections.

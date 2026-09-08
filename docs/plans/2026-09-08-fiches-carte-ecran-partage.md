---
title: "Fiches en haut et carte redimensionnable en bas"
status: completed
date: 2026-09-08
approved_at: 2026-09-08
completed_at: 2026-09-08
owner: Samuel
tags: [plan, map, ux]
---

# Fiches en haut et carte redimensionnable en bas

## Résultat et approbation

Samuel a approuvé le plan présenté dans la conversation le 8 septembre 2026,
par « j ápprouve ». Dans Explorer, sélectionner un événement ou un ami ouvre
ses informations au-dessus de la carte. La séparation se déplace au doigt,
avec trois positions : fiche réduite, moitié et agrandie. La fermeture rend
tout l'espace à la carte. Les contrôles, couleurs et typographies restent iOS.

Le propriétaire a ensuite signalé un crash sur iPhone 12 mini et demandé des
arrondis marqués. Le [correctif approuvé séparément](2026-09-08-corriger-crash-metal-et-arrondir-fiches.md)
stabilise désormais la surface de rendu native et ajoute les arrondis autour de
la bande noire. Les résultats de simulateur ci-dessous décrivent la première
version ; la validation physique et les contrôles supplémentaires sont dans ce
nouveau plan.

## Périmètre

- Conteneur partagé, animation, défilement autonome des informations et carte
  interactive conservant son identité pendant l'ouverture et le redimensionnement.
- Une seule fiche sélectionnée. Réutilisation des actions de participation,
  modification et itinéraire, des états de chargement et du mode fantôme.
- Les profils ouverts depuis l'onglet Amis conservent leur feuille native.
- Le formulaire de création/modification, Firebase et le modèle métier ne font
  pas l'objet d'une refonte.

## Fichiers concernés

- `wander/ContentView.swift` : sélection et composition de l'écran Explorer.
- `wander/MapDetailSplitView.swift` : nouveau conteneur et poignée accessible.
- `wander/MapWithFogView.swift` : sélection/désélection des amis et événements.
- `wander/OutingPlanDetailCardView.swift` : contenu défilant dans la zone supérieure.
- `wander/FriendProfileSheet.swift` : contenu de profil réutilisable sans dépendance
  à la fermeture d'une feuille pour l'itinéraire intégré.
- `wander/DebugSocialMapScenario.swift` : même conteneur et fiches pour les scénarios.
- `wanderUITests/MapSocialGestureUITests.swift` : gestes et écran partagé.
- `wanderTests/MapSocialProximityControllerTests.swift` : sélection si son contrat change.
- Ce plan, `todos/` pour les constats de revue et `docs/solutions/` si un
  apprentissage vérifié mérite une note.

Notes du coffre Obsidian
`/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :

- `Backlog features.md` : En cours, fiches événement/profil.
- `Documentation UX.md` : Onglet Explorer, amis, sorties, accessibilité.
- `Documentation technique.md` : Carte, responsabilités des vues, validation.
- `00 - Wander.md` : État du projet.

Mettre à jour `updated`, préserver les wikilinks et vérifier la lecture dans
Obsidian. Le coffre est lisible mais hors des racines d'écriture autorisées au
départ. En cas d'accès impossible, préciser les mises à jour/contrôles restants
sans créer de coffre de substitution ni déclarer leur validation réussie.

## Mise en œuvre

- [x] Créer le conteneur stable, les trois positions, la poignée et les actions VoiceOver.
- [x] Adapter les contenus événement et profil avec fermeture explicite.
- [x] Intégrer la sélection exclusive dans Explorer et MapKit.
- [x] Adapter les scénarios de test et renforcer les contrôles gestuels.
- [x] Simplifier, compiler, tester et effectuer la revue.
- [x] Mettre à jour les notes Obsidian et consigner les limites de validation.

## Risques et garde-fous

- Les gestes de la poignée doivent rester dans sa zone, sans absorber le
  défilement ni les gestes MapKit. Le contenu doit rester accessible en grande police.
- Une modification de taille ne doit ni recréer MKMapView ni fermer la fiche.
  Vérifier les clusters ouverts et les sélections rapides ami/événement.
- Garder les listeners de participation alignés sur la fiche événement active.
- Retrait d'amitié, événement supprimé, position absente ou mode fantôme :
  conserver la réconciliation et revérifier la destination au moment de l'action.
- Ne pas lancer/créer/télécharger d'autre simulateur que l'iPhone 17 déjà démarré.
- Aucun Git mutateur, commit, déploiement ni publication dans cette intervention.

## Validation et critères d'acceptation

- [x] Build Debug sans nouveaux avertissements.
- [x] Tests ciblés de sélection et tests UI existants adaptés passent.
- [x] Événement et ami : fiche au-dessus, carte dessous, remplacement et fermeture.
- [x] Trois positions atteignables ; le contenu défile et la carte se déplace/zoome.
- [x] Modification/annulation et actions de fiche conservées dans les scénarios.
- [x] Grandes tailles de texte contrôlées par gestes UI ; réduction des animations
  et actions VoiceOver revues dans le code (parcours vocal complet non exécuté).
- [x] Capture de l'écran partagé sur l'iPhone 17.
- [x] Notes Obsidian mises à jour et vérifiées en lecture.

## Preuves et revue

Investigation initiale en lecture seule : arbre Git propre, branche `main`.
Des cibles XCTest et XCUITest existent déjà, malgré la mention historique contraire
dans AGENTS.md. Le scénario local utilise les vraies vues et des données fictives,
sans authentification ni publication. Les tests UI sont privilégiés pour prouver
le contrat visuel/gestuel ; la compilation et la validation intégrée suivent les
modifications coordonnées plutôt qu'une phase rouge sur un conteneur absent.

La première lecture de CoreSimulator dans le sandbox a échoué. L'accès a été
rétabli avec les commandes Xcode/simctl approuvées hors sandbox ; seul l'iPhone 17
déjà démarré a été utilisé. XcodeBuildMCP étant indisponible, le contrôle
`ce-test-xcode` est effectué avec `xcodebuild`, XCTest et `simctl`.

Le build Debug passe. Deux avertissements préexistants concernent les versions
des extensions (15 et 27, contre 36 pour l'app) ; aucun nouveau diagnostic Swift.
La suite ciblée du 8 septembre passe : 48 tests, dont 37 unitaires de proximité
et 11 tests UI, sans échec ni test ignoré.
Résultat : `/tmp/wander-split-tests-final.xcresult`.

Les revues de simplification puis de code ont été exécutées avec les agents
disponibles et des lectures locales. Les corrections de sélection persistante
et de poignée accessible sont consignées dans les todos
[032](../../todos/032-done-p1-preserver-fiche-pendant-gestes-carte.md) et
[033](../../todos/033-done-p2-retirer-poignee-fermee-accessibilite.md).

### Commandes et résultats

Build (code de sortie 0) :

```bash
xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration Debug -destination 'id=6F13855D-10B8-45AF-9205-17C8393379E3' -derivedDataPath /tmp/wander-participant-badge-derived-data -disableAutomaticPackageResolution build
```

Suite principale (48/48) :

```bash
xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration Debug -destination 'id=6F13855D-10B8-45AF-9205-17C8393379E3' -derivedDataPath /tmp/wander-participant-badge-derived-data -disableAutomaticPackageResolution -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -resultBundlePath /tmp/wander-split-tests-final.xcresult -only-testing:wanderTests/MapSocialProximityControllerTests -only-testing:wanderTests/MapSocialProximityStateTests -only-testing:wanderUITests/MapSocialGestureUITests test
```

- Les 11 tests UI sont ensuite repassés après amélioration du helper de ciblage :
  `/tmp/wander-split-ui-final.xcresult`.
- À `accessibility-extra-extra-extra-large`, le test du défilement événement
  passe dans `/tmp/wander-split-large-text.xcresult` et sa relance.
- Le test du profil passe dans `/tmp/wander-split-large-profile-visible.xcresult` :
  sélection d'Amina, disposition, défilement jusqu'à Itinéraire et fermeture.
  Sa précondition place le groupe plus bas afin que toute sa liste soit visible.
- Le même test passe après restauration de la taille standard et avec le helper
  final : `/tmp/wander-split-profile-standard.xcresult`.
- Les contrôles ciblés utilisent la même commande, en remplaçant les filtres par
  `-only-testing:wanderUITests/MapSocialGestureUITests/testDetailScrollKeepsPaneAndHeaderInPlace`
  et/ou `-only-testing:wanderUITests/MapSocialGestureUITests/testMixedGroupOpensFriendAboveMap`.
- Réglage utilisé : `xcrun simctl ui 6F13855D-10B8-45AF-9205-17C8393379E3 content_size accessibility-extra-extra-extra-large`,
  puis restauration de la valeur initiale `large`.
- Capture visuellement vérifiée : `/tmp/wander-split-event-iphone17.png`.
- `git diff --check` passe. Aucun Git mutateur n'a été exécuté.

### Limites et suivi

En très grande police, le groupe mixte initialement centré dépasse le haut de
la carte et deux essais n'ont pas conservé son ouverture. Le toucher et la caméra
ont été vérifiés dans les artefacts ; la cause exacte reste à établir. Ce cas
concerne les groupes et est suivi dans le
[todo 034](../../todos/034-ready-p2-valider-groupes-en-tres-grande-police.md).
Le passage du test avec un cadrage adapté ne constitue pas sa correction.

L'accessibilité de la poignée est vérifiée par ses valeurs et sa disparition
dans XCTest, ainsi que par la revue des actions incrément/décrément. Réduire les
animations supprime aussi la transaction de fin de glissement. Une session
VoiceOver complète, les itinéraires vers les apps externes et les transitions
sociales Firebase réelles n'ont pas été exécutés dans le scénario local. Les
gardes d'amitié, de position et de mode fantôme ont été revus ; aucune écriture
distante n'est nécessaire pour cette validation du conteneur.

Les quatre notes Obsidian prévues sont actualisées. Leurs propriétés, liens
vers les notes/sections, listes, tableaux et callouts ont été contrôlés en mode
Aperçu. Le diagramme technique reste rendu et inchangé. Les frontmatters,
wikilinks et clôtures de blocs de code passent aussi le contrôle mécanique.

La décision principale est de séparer la fiche persistante du focus MapKit
transitoire. Fermer la fiche sur chaque désélection native contredisait le
panoramique demandé. Une carte recréée à chaque ouverture ferait perdre son état ;
elle garde donc son emplacement structurel. Les contrôles réels VoiceOver et
multi-appareils restent les aspects les moins certains.

`ce-compound` : **Documentation skipped** — les choix et la prévention sont
déjà présents dans l'implémentation, les tests, les constats 032/033 et les notes
UX/technique. Aucune note de solution supplémentaire n'apporte de raisonnement
durable absent de ces sources.

Référence plateforme : [actions accessibles SwiftUI](https://developer.apple.com/documentation/swiftui/accessible-controls).

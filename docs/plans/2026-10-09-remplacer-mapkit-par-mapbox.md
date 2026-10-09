---
title: "Remplacer le moteur de carte par Mapbox"
status: completed
date: 2026-10-09
approved_at: 2026-10-09
completed_at: 2026-10-09T20:43:03+09:00
owner: Samuel
tags: [plan, map, mapbox]
---

# Remplacer le moteur de carte par Mapbox

## Outcome

La carte principale utilise Mapbox à la place de MKMapView. L'exploration H3,
le brouillard, la position personnelle, les amis, événements, groupes, gestes,
fiches et indicateurs hors écran restent disponibles. Les données SwiftData
et Firebase et les modifications locales antérieures sont conservées.

Samuel a approuvé le plan présenté dans la conversation avec « je valide ».
Un seul sprint couvre le remplacement complet. Samuel n'a pas encore de
jeton Mapbox au début et demande de le solliciter seulement à la fin de
l'implémentation. Il fournit ensuite son jeton public pendant le travail ;
celui-ci est enregistré uniquement dans Config/Mapbox.local.xcconfig, ignoré.

## Scope and approach

- Remplacer directement le moteur dans MapWithFogView, sans conserver un
  second moteur ou ajouter de sélecteur de fournisseur.
- Garder le conteneur SwiftUI et les contrôles iOS existants ; adapter les
  vues UIKit des marqueurs aux annotations Mapbox.
- Utiliser la projection plane et un masque issu des cellules H3, avec
  contrôle des cellules adjacentes et du passage à l'antiméridien.
- Garder CoreLocation comme source de positions et permissions.
- Garder les services Apple de recherche/géocodage et la navigation externe
  hors du remplacement du rendu.
- Installer une version stable exacte de Mapbox par SPM ; lire le jeton
  public depuis une configuration locale ignorée. Ne jamais utiliser un
  jeton de démonstration appartenant à un tiers.
- Garder logo et attribution visibles, y compris quand les panneaux recadrent
  la carte, avec accès au choix de télémétrie prévu par le SDK.
- Aucun changement de schéma, de règles Firebase, ni déploiement.
- Aucune opération Git mutante, aucun commit, branche ou publication.

## Affected files

- wander/MapWithFogView.swift
- wander/MapViewportView.swift
- wander/MapFriendCameraController.swift
- wander/MapEdgeZoomController.swift
- wander/MapSocialProximityController.swift
- wander/MapSocialProximityGroupAnnotation.swift
- wander/MapSocialClusterAnnotationView.swift
- wander/ContentView.swift
- wander/DebugSocialMapScenario.swift
- wander/Info.plist
- Types locaux nécessaires au rendu des annotations Mapbox et du brouillard
  dans wander/, sans couche multi-fournisseur.
- wander.xcodeproj/project.pbxproj
- wander.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
- .gitignore et configuration locale/exemple Mapbox dans Config/
- wanderTests/MapUserCameraControllerTests.swift
- wanderTests/MapFriendCameraControllerTests.swift
- wanderTests/MapEdgeZoomControllerTests.swift
- wanderTests/MapViewportViewTests.swift
- wanderTests/MapSocialProximityControllerTests.swift
- Tests du masque H3 dans wanderTests/
- wanderUITests/MapSocialGestureUITests.swift
- wanderUITests/MotionDockUITests.swift
- docs/README.md, ce plan, constats éventuels dans todos/, enseignements
  réutilisables vérifiés dans docs/solutions/.
- Coffre Obsidian existant : Backlog features.md, Documentation technique.md,
  Documentation UX.md, 00 - Wander.md. Mettre à jour updated et conserver les
  wikilinks. Le coffre est hors du périmètre d'écriture par défaut ; demander
  une autorisation technique ciblée si nécessaire, sans créer de copie.

## Implementation

- [x] Ajouter/configurer Mapbox et préserver les réglages Xcode existants.
- [x] Remplacer MKMapView et porter le brouillard H3.
- [x] Porter les annotations, groupes et sélections sociales.
- [x] Porter le suivi, le cadrage, les gestes et les indicateurs hors écran.
- [x] Adapter les scénarios de test et les suites concernées.
- [x] Simplifier et effectuer une revue du changement réel.
- [x] Mettre à jour la documentation et les notes Obsidian.
- [x] Vérifier les critères d'acceptation et enregistrer les résultats exacts.

## Risks and dependencies

- Le masque H3 et les mises à jour de caméra peuvent modifier la fluidité ou
  les interactions : tester cellules voisines, retrait/ajout, déplacement,
  zoom, sélection et ouverture/fermeture des panneaux.
- Les tests UI doivent cibler un identifiant stable du canvas Mapbox.
- Le jeton public de Samuel est configuré localement. Les tuiles réelles
  sont vérifiées ; le fichier de configuration reste ignoré par Git.
- Le téléchargement SPM et CoreSimulator peuvent nécessiter l'accès réseau
  et l'accès ciblé aux services Xcode hors sandbox.
- La suppression de heatmap déjà présente reste intégralement conservée.

## Validation and acceptance criteria

- [x] Build Debug et cibles de tests compilés sans nouveau diagnostic Swift.
- [x] Tests caméra, zoom, viewport, groupes, sélection et masque H3 réussis.
- [x] Tests UI fonctionnels à taille de texte standard sur l'iPhone 17 déjà
  démarré uniquement ; aucun nouveau simulateur/runtime installé ou démarré.
- [x] Vérification de la carte, du brouillard, des marqueurs, des groupes,
  de l'appui long, des profils, des panneaux et du retour d'arrière-plan.
- [x] Tuiles réelles et jeton/réseau validés avec le jeton fourni. Aucun
  rendu MapKit ne subsiste dans la carte principale.
- [x] Données d'exploration et services conservés, aucun jeton secret ajouté.
- [x] Attribution visible dans tous les cadrages et documentation actualisée.

## Review notes

- Décision principale : remplacer le moteur tout en conservant les vues et
  interactions existantes, sans doubler l'architecture.
- Alternative écartée : livrer un simple prototype ou une carte sans les
  fonctions sociales et le brouillard.
- Incertitudes initiales : performances du masque avec beaucoup de cellules,
  comportement tactile et validation des tuiles sans jeton disponible.
- Preuve avant modification : inventaire lu et tests existants identifiés.
  La migration implique un nouveau SDK ; le portage des suites et leur
  exécution intégrée serviront de preuve, sans prétendre à un cycle rouge
  observé avant chaque remplacement de type.

## Validation finale

La migration est terminée et validée sur l’iPhone 17 Pro iOS 26.3 déjà démarré.
Aucun autre simulateur ou runtime n’a été créé, installé ou démarré.

### Build et dépendances

- SDK officiels résolus : Maps/CoreMaps 11.32.0, Common 24.32.0 et Turf 4.0.0.
  Preuve : `/tmp/wander-mapbox-packages-final.log`.
- `build-for-testing` réussi pour l’app et les cibles de tests. Preuve :
  `/tmp/wander-mapbox-build-2.log`, puis compilations des passes de validation.
  L’avertissement Swift de variable inutilisée a été corrigé. Les avertissements
  AppIntents et les versions d’extensions différentes de celle de l’app sont
  préexistants.
- Le blocage initial de récupération Common a été résolu après le clone ciblé
  exécuté par Samuel. Codex n’a exécuté aucune commande Git mutante. Les
  archives SDK correspondent aux empreintes officielles.

### Tests natifs

La passe 5 exécute 113 tests, zéro échec, en 9,285 secondes.
Preuves : `/tmp/wander-mapbox-validation-5.log` et
`/tmp/wander-mapbox-validation-5.xcresult`.

| Suite | Tests réussis |
|---|---:|
| MapEdgeZoomControllerTests | 24 |
| MapFriendCameraControllerTests | 7 |
| MapSocialProximityControllerTests | 34 |
| MapSocialProximityStateTests | 18 |
| MapUserCameraControllerTests | 9 |
| MapViewportViewTests | 7 |
| MapboxFogGeometryTests | 10 |
| MapboxFogRendererTests | 4 |

Les dix tests géométriques passent aussi dans un paquet macOS temporaire avec
les fichiers réels et l’isolation MainActor par défaut. La sonde synthétique
contiguë mesure environ 0,005 seconde pour 1 027 cellules, 0,040 seconde pour
10 267 et 0,197 seconde pour 50 311. Ces mesures excluent le GPU et ne sont
pas une mesure de performance sur iPhone.

### Parcours UI et inspection visuelle

- Les 26 scénarios UI distincts vérifiés ont un dernier résultat réussi dans
  les passes ciblées 2 à 6. Il ne s’agit pas d’une exécution unique de 26 tests.
  Agrégation par scénario : `/tmp/wander-mapbox-ui-results.json`.
- La passe 5 réussit 11 de ses 12 tests UI ; l’attente ancienne du scénario
  de zoom aux deux bords est corrigée. La passe 6 reprend ce scénario,
  le zoom sur le profil seul et la fermeture de fiche ami : trois tests,
  zéro échec, 58,45 secondes, `TEST SUCCEEDED`.
  Preuves : `/tmp/wander-mapbox-validation-6.log` et
  `/tmp/wander-mapbox-validation-6.xcresult`.
- Couverture fonctionnelle à taille de texte standard : déplacement, pincement,
  double toucher, zoom aux bords, groupes, sélection unique entre amis proches,
  profils, recentrage, événements et annulations, panneaux et rendu stable.
  L’appui long crée un seul brouillon ; appuyer sur son pin n’en crée pas un second.
- Inspection des vraies tuiles avec le jeton local : couronne H3 de
  54 cellules révélées autour de sept cellules centrales inexplorées,
  désactivation/restauration des zones, retour via l’écran d’accueil puis
  Wander et menu d’attribution Mapbox/OpenStreetMap, télémétrie et confidentialité.
- Le logo et l’attribution suivent le cadre de la feuille native sans modifier
  la caméra ni le viewport. La capture de profil compact confirme l’attribution
  au-dessus de la fiche et la boussole sous le bouton de profil.
- Captures inspectées dans `/tmp/wander-mapbox-evidence/` :
  `fog-revealed.png`, `fog-restored.png`, `attribution-options.png`,
  `friend-profile-compact.png` et `own-profile-compact.png`. Le dernier
  contrôle sur la build finale est conservé dans `fog-final.png` et
  `attribution-final.png` ; la carte reste ouverte dans l’app.

### Corrections issues de la validation

- Les demandes de caméra attendent une taille de carte exploitable avant
  d’être consommées. Les contrôleurs utilisent la caméra native Mapbox.
- La projection hors champ Mapbox peut renvoyer `(-1, -1)`. Les indicateurs
  traitent cette sentinelle avec un calcul d’azimut relatif au cap de caméra.
- La fusion H3 précède la soustraction CoreGraphics pour limiter le nombre
  d’arêtes. Le renderer sérialise les calculs et écarte les snapshots périmés.
- `isStyleLoaded` peut devenir faux pendant le traitement d’une source déjà
  installée. Le renderer autorise désormais sa mise à jour si elle existe.
  Deux cas échouaient sur vingt exécutions dans
  `/tmp/wander-mapbox-fog-race.log`. Après correction, vingt tests répétés
  passent, zéro échec, en 4,25 secondes dans `/tmp/wander-mapbox-fog-fixed.log`.
  Les assertions interrogent la couche rendue avec `queryRenderedFeatures`.

### Revue, données et documentation

- La revue initiale a couvert dix axes. La reprise ciblée ne retient aucun
  finding actif. Reçus :
  `/tmp/compound-engineering-501/ce-code-review/20261009-mapbox-final/review.json`
  et `review-followup.json` dans le même dossier. La reprise précédait le
  résultat final ; les preuves de tests ci-dessus complètent ce reçu.
- `DiscoveredCell.swift`, `DiscoveredCellStore.swift`, `LocationTracker.swift`,
  `WanderMigrationPlan.swift` et `ProfilePanelView.swift` sont identiques octet
  par octet à la copie initiale `/tmp/wander-mapbox-baseline/wander/`.
  La suppression de heatmap antérieure est conservée. Aucun schéma, règle ou
  déploiement Firebase n’a changé.
- Jeton public uniquement dans `Config/Mapbox.local.xcconfig`, ignoré par Git.
  Aucun jeton incorporé aux sources versionnées ou à la documentation.
- README et quatre notes Obsidian actualisés, avec leur frontmatter `updated`.
  [Le constat 075 est clôturé](../../todos/075-done-p1-valider-mapbox-sur-simulateur.md).
- Enseignement conservé dans
  [Fusionner H3 avant le masque](../solutions/2026-10-09-fusionner-h3-avant-masque-mapbox.md).

### Limites

Les scénarios utilisent des données locales ; ils ne valident pas de nouveaux
échanges Firebase authentifiés. Le ressenti haptique et les performances sur
appareil physique ne sont pas mesurés. Aucun test dédié d’accessibilité n’a
été ajouté ou exécuté.

## Sources

- [Installation Mapbox iOS](https://docs.mapbox.com/ios/maps/guides/install/)
- [Couches de style Mapbox](https://docs.mapbox.com/ios/maps/guides/styles/work-with-layers/)
- [Guides du SDK iOS](https://docs.mapbox.com/ios/maps/guides/)

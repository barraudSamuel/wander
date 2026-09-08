---
title: "Corriger le crash Metal et arrondir les panneaux de carte"
status: completed
date: 2026-09-08
approved_at: 2026-09-08
completed_at: 2026-09-08
owner: Samuel
tags: [plan, map, bug, ux]
---

# Corriger le crash Metal et arrondir les panneaux de carte

## Approbation et résultat

Samuel a approuvé le plan présenté dans la conversation par « j'approuve la
correctin ». La carte garde une surface native de rendu stable pendant les
transitions de fiche. Sa fenêtre visible change de hauteur, avec coins supérieurs
arrondis ; la fiche garde ses coins inférieurs arrondis au-dessus d'une bande
sombre contenant la poignée. Les trois positions et les gestes restent disponibles.

## Diagnostic observé

Sur l'iPhone 12 mini connecté, iOS 26.5.2, Xcode est arrêté sur SIGABRT.
La pile lue avec `thread backtrace` montre : `MKMapView.setFrame` →
`_sizeDidChangeWithCenterCoordinate` → `MKBasicMapView.setFrame` →
`VKMapView.forceLayout` → `MetalSwapchain::resize` →
`CAMetalLayer.setDrawableSize` → destruction d'un `CAMetalDrawable` → assertion
`MTLDebugDevice.notifyExternalReferencesNonZeroOnDealloc`.
Une texture « CAMetalLayer Display Drawable » est libérée alors qu'un command
buffer l'utilise encore. Le conteneur précédent transmet sa hauteur animée
directement à la carte. Les essais sur simulateur ne reproduisaient pas cette
condition du GPU A14 ; leur scénario ne construisait pas tout Explorer.

## Périmètre et fichiers

- `wander/MapViewportView.swift` : nouveau conteneur UIKit, surface native stable,
  fenêtre visible et callback de changement de cette fenêtre.
- `wander/MapDetailSplitView.swift` : transmettre la taille de rendu stable et
  appliquer les arrondis continus et la bande sombre.
- `wander/OutingPlanDetailCardView.swift`, `wander/FriendProfileSheet.swift` :
  fond système de panneau pour rendre les arrondis visibles aussi en mode sombre.
- `wander/MapWithFogView.swift` : intégrer le conteneur et utiliser la fenêtre
  visible pour les indicateurs, le brouillon et le repli de projection.
- `wander/MapSocialProximityController.swift`,
  `wander/MapSocialClusterAnnotationView.swift` : exposer les groupes dans la
  fenêtre disponible et borner leur liste défilante.
- `wander/ContentView.swift`, `wander/DebugSocialMapScenario.swift` : adapter la
  composition si nécessaire, conserver les boutons dans la fenêtre visible.
- `wander/FriendEdgeRailView.swift`, `wander/RightEdgePanGestureView.swift` :
  conserver le rail dans le repère local de la carte visible.
- `wanderUITests/MapSocialGestureUITests.swift`,
  `wanderTests/MapSocialProximityControllerTests.swift`,
  `wanderTests/MapViewportViewTests.swift` : régression de géométrie et gestes.
- Ce plan, le plan précédent des fiches partagées, les constats dans `todos/`,
  et une solution dans `docs/solutions/` si l'apprentissage remplit le critère durable.

Notes Obsidian dans
`/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
`Backlog features.md`, `Documentation UX.md`, `Documentation technique.md`,
`00 - Wander.md`. Actualiser `updated` et contrôler le rendu en lecture.

## Mise en œuvre

- [x] Ajouter un contrôle de régression qui échoue sur la taille native variable.
- [x] Conserver les dimensions de MKMapView pendant l'ouverture, le glissement,
  les changements de position et la fermeture. Centrer la surface dans la fenêtre.
- [x] Actualiser explicitement les géométries visibles sans relancer la sélection.
- [x] Adapter les groupes, indicateurs et gestes du rail aux limites visibles.
- [x] Arrondir les panneaux avec une forme système continue, rayon initial 32 pt
  borné pour les petites hauteurs, et adapter les zones tactiles.
- [x] Compiler et vérifier les tests ciblés, puis le téléphone avec Metal actif.
- [x] Simplifier, revoir et mettre à jour le plan, les constats et Obsidian.

## Risques et contraintes

- Un masque ne corrige rien si MKMapView continue de changer de taille : tester
  directement ses bounds, y compris à des hauteurs intermédiaires.
- Les coordonnées des annotations restent celles de la carte native. Les zones
  visibles, le centrage, les groupes et les contrôles doivent partager ce repère.
- Vérifier le compas, les mentions cartographiques et les éléments accessibles
  près des bords masqués. Une fenêtre trop courte doit garder une liste défilante.
- Ne pas désactiver Metal API Validation pour masquer le crash.
- Ne pas modifier Firebase, les données personnelles, le partage de position,
  les schémas ou les permissions pour les besoins de cette correction.
- Préserver les modifications non commitées de la tâche précédente. Aucun Git
  mutateur, commit ni déploiement. Seul le simulateur iPhone 17 déjà lancé est autorisé.
- L'installation de la build corrigée sur l'iPhone connecté fait partie de la
  vérification approuvée ; conserver ses données et ses réglages.

## Validation et acceptation

- [x] Le test de taille native variable échoue avant correction puis passe.
- [x] Tests du conteneur et des groupes passent avec tailles intermédiaires.
- [x] Les gestes UI, les trois tailles, la fermeture, les profils et événements passent.
- [x] Contrôle sur iPhone 12 mini du parcours Explorer avec Metal actif : ouvertures,
  fermetures et redimensionnements répétés, sans assertion résiduelle.
- [x] Arrondis, zones tactiles, grande police et Réduire les animations contrôlés.
- [x] Commandes, résultats et limites consignés ; notes Obsidian relues.

## Preuves et suivi

Avant correction : branche `main`, HEAD `aeb2b18`, modifications non commitées de
l'écran partagé présentes. Le crash est observé dans la session Xcode de
l'iPhone ; aucune relance ni modification n'a été faite pendant le diagnostic.
Ne conserver ici que les extraits pertinents du crash, sans positions ni identifiants.

### Régression et première vérification

- Rouge : `/tmp/wander-metal-regression-red.xcresult`, un échec attendu. Après
  ouverture de la fiche, la hauteur native passe de 678,67 à 317,33 pt.
- Premier contrôle corrigé : `/tmp/wander-metal-regression-green.xcresult`,
  23 réussites dont la régression UI et les trois tests du viewport. Un nouveau
  test de groupe révèle un décalage de centrage, corrigé ensuite.
- Le test de groupe avec une vraie MKMapView et une zone sûre non symétrique
  montre que `convert(centerCoordinate)` vaut y=451 lorsque `bounds.midY` vaut
  437. Le centrage utilise maintenant le point projeté. Le test attend le layout
  différé de l'annotation et conserve les assertions à 1 pt. Résultat ciblé :
  `/tmp/wander-group-viewport-layout-fix.xcresult`, une réussite.
- Premier essai physique : `/tmp/wander-iphone-metal-smoke.xcresult`, une réussite
  sur iPhone 12 mini, iOS 26.5.2. Quatre ouvertures/fermetures d'une sortie
  existante, douze changements de position et quatre glissements. Le journal
  de cette exécution contient `Metal API Validation Enabled`, aucune assertion
  échouée, aucun SIGABRT ni exception fatale. Aucune donnée de sortie modifiée.
- Capture physique : `/tmp/wander-iphone-metal-smoke-attachments/F29406CD-AAC1-4505-B031-E76E40A44F50.png`.
  Arrondis des panneaux, poignée, carte, marqueurs, boutons et mentions Apple
  visibles. Le test final réinstalle aussi l'ajustement du centrage des groupes.
- Simplification : une optimisation appliquée, les changements de fenêtre ne
  forcent plus le layout des lignes si leur taille effective reste identique.
  Passes réutilisation et qualité sans autre constat. Revue indépendante Swift,
  géométrie, performances et accessibilité sans défaut statique supplémentaire.

### Résultats finaux

- `/tmp/wander-rounded-map-final.xcresult` : **53/53**, soit 41 tests unitaires
  et 12 tests UI. Groupes, viewport, annulation des événements fictifs, sélection,
  gestes natifs, poignée, trois tailles, fermeture et défilement des fiches.
- `/tmp/wander-iphone-metal-final.xcresult` : **1/1** sur le téléphone avec le
  dernier ajustement du centrage des groupes. Le journal de cette exécution
  confirme Metal actif et zéro assertion échouée, SIGABRT ou exception fatale.
- `/tmp/wander-rounded-map-accessibility.xcresult` : **3/3** avec
  `accessibility-extra-extra-extra-large` et Réduire les animations activé dans
  Réglages. Fiche événement défilante, glissement de la poignée et ouverture du
  profil Amina depuis le groupe mixte initialement centré. L'ancienne précondition
  qui déplaçait ce groupe avant de l'ouvrir a été retirée du test.
- Le contrôle visuel en sombre a montré un panneau noir se confondant avec la
  bande noire. Les fonds des deux fiches et du conteneur utilisent désormais
  `secondarySystemGroupedBackground`, blanc en clair et distinct du noir en sombre.
  `/tmp/wander-rounded-map-dark-colors.xcresult` : **1/1** après cette retouche.
  Capture vérifiée : `/tmp/wander-rounded-map-dark-colors-attachments/2C45FFF9-BA6E-4A66-9CAC-4AF7D08A4AAF.png`.
- Build Debug physique de cette dernière retouche réussi, installation conservant
  les données et lancement sur l'iPhone confirmés à 16:49, avec `MTL_DEBUG_LAYER=1`.
- Réglages du simulateur restaurés et relus : taille `large`, Réduire les animations
  à 0. Le mode sombre préexistant est conservé ; aucun autre appareil démarré.
- `git diff --check` passe. Aucun avertissement Swift nouveau. Deux avertissements
  préexistants concernent les versions d'extensions 15/27 face à l'app 36.
- Les quatre notes Obsidian ont été mises à jour à 16:43, puis relues en mode
  Aperçu : propriétés, texte des sections modifiées et liens internes présents.
  Aucun nouveau tableau, callout, bloc Mermaid ou bloc de code n'a été introduit.
- La solution `docs/solutions/2026-09-08-stabiliser-rendu-mapkit-pendant-fiche.md`
  conserve la preuve GPU absente du code final. Les validateurs de claims et de
  frontmatter passent. Vocabulaire parcouru, aucun terme métier à ajouter.

Commandes de validation, depuis le dépôt :

```bash
xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'id=6F13855D-10B8-45AF-9205-17C8393379E3' \
  -derivedDataPath /tmp/wander-participant-badge-derived-data \
  -disableAutomaticPackageResolution -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  -resultBundlePath /tmp/wander-rounded-map-final.xcresult \
  -only-testing:wanderTests/MapViewportViewTests \
  -only-testing:wanderTests/MapSocialProximityStateTests \
  -only-testing:wanderTests/MapSocialProximityControllerTests \
  -only-testing:wanderUITests/MapSocialGestureUITests test
```

Le contrôle physique utilise le même projet/schéma Debug, la destination iPhone
12 mini connectée, le DerivedData Xcode existant et
`-only-testing:wanderUITests/MapDeviceSmokeUITests`. Les journaux de compilation
et d'exécution sont conservés dans les fichiers `/tmp/wander-iphone-metal-final.log` et
`/tmp/wander-rounded-map-accessibility.log`. XcodeBuildMCP étant absent, la
validation suit l'équivalent CLI Xcode et Computer Use du workflow demandé.

### Bilan des surfaces et limites

Projet `wander.xcodeproj`, schéma `wander`, simulateur iPhone 17 iOS 26.3.1 ;
build réussi. Quatre surfaces contrôlées :

| Surface ou contrôle | Résultat | Preuve |
|---|---|---|
| Fiche événement, trois tailles, scroll et fermeture | PASS | Tests UI, captures clair/sombre |
| Profil ami au-dessus de la carte | PASS | Scénario mixte standard et texte maximal |
| Groupes, indicateurs et gestes natifs de carte | PASS | Tests MapKit, viewport et UI ; carte réelle visible |
| Crash iPhone avec Metal actif | PASS | Test physique et journal dédiés |
| Parcours VoiceOver parlé complet | SKIP | Revue des actions et assertions AX uniquement |

Erreurs console fatales sur le test physique final : **0**. Vérifications humaines
dépendantes : **1**, déverrouillage de l'iPhone confirmé par le propriétaire et
par le démarrage effectif du test. Échecs résiduels observés : **0**.
Résultat fonctionnel demandé : **PASS**. Couverture élargie d'accessibilité :
**PARTIAL**, le parcours VoiceOver complet reste au backlog. Les transitions
Firebase de retrait d'amitié/mode fantôme ne sont pas exercées par ces tests.

La décision la plus délicate est de séparer le rendu natif du cadre visible :
elle exige de propager le bon repère aux annotations. Le masque seul et la
désactivation de Metal ont été écartés car ils ne retirent pas le déclencheur.
La couverture vocale et les transitions sociales réelles restent les points
les moins vérifiés. Aucun commit, Git mutateur ou déploiement effectué.

### Suite approuvée : plein écran

Les safe areas noires observées sur la capture suivante sont corrigées dans
[le plan carte plein écran](2026-09-08-carte-plein-ecran.md). Le conteneur stable
et les arrondis restent en place ; les insets de contenu sont séparés de la
surface dessinée derrière les barres système.

---
title: "Pins des adresses enregistrées : états et animations"
status: completed
approved_at: 2026-10-24
completed_at: 2026-10-24
date: 2026-10-24
owner: Samuel
tags: [plan, spec, map, saved-places, animation, ios]
---

# Pins des adresses enregistrées : états et animations

## Reprise dans un nouveau contexte

Ce document contient la spécification et le plan d'un seul sprint. Il doit permettre d'implémenter la fonctionnalité sans relire la conversation d'origine.

Samuel a explicitement approuvé ce plan dans cette conversation le 24 octobre 2026 (« j'approuve »). Le simulateur autorisé est celui déjà démarré et vérifié avant approbation : iPhone 18 Pro, iOS 27.0, UDID `CD1E7A76-F65E-495D-A525-F328746F152F`. Il remplace la référence historique à l'iPhone 17 dans les consignes de validation ci-dessous. Utiliser le scénario Debug existant sans connexion et sans modifier l'authentification.

Lire `AGENTS.md` et `docs/README.md` avant toute modification. Les règles du dépôt priment sur les exemples historiques cités ici. Préserver les modifications déjà présentes. Les commandes Git sont exclusivement en lecture seule ; aucun commit, changement de branche ou autre commande Git mutatrice.

**La validation sur simulateur est obligatoire.** Exécuter l'application et les tests ciblés sur le simulateur déjà démarré et autorisé ci-dessus, puis inspecter les transitions et les gestes dans l'application. Une compilation réussie, des tests seulement écrits ou des captures au repos ne suffisent pas pour terminer ce sprint. Les modalités et les preuves attendues figurent dans la section Validation.

## Résultat attendu et contexte

Les adresses enregistrées restent faciles à repérer quand la carte est dense, affichent davantage d'informations quand l'espace le permet et indiquent clairement quelle fiche est ouverte. Les changements de présentation sont courts, fluides et interrompables.

La référence est une vidéo de 24 secondes montrant de petits pins circulaires, des pins agrandis avec une catégorie et un agrandissement à la sélection. Sa logique exacte de priorité ne peut pas être déduite de l'image. Les règles ci-dessous définissent le comportement propre à Wander. La vidéo n'est pas nécessaire pour exécuter ce plan.

Le code inspecté utilise Mapbox Maps iOS 11.32.0 et des vues UIKit attachées par `ViewAnnotation`. Les adresses emploient déjà un SF Symbol, un rond Liquid Glass, un nom et une catégorie. Le modèle `SavedPlace` ne contient pas de photo. Les cibles `wanderTests` et `wanderUITests` existent et sont référencées par le schéma `wander`, malgré une mention historique contraire dans les consignes.

## Périmètre

Inclus : les états compact, détaillé et sélectionné des adresses enregistrées, leurs animations, leurs collisions, leur synchronisation avec la fiche existante, les tests et la documentation correspondante.

Les symboles de catégorie et le matériau iOS existants sont conservés. Le texte utilise les polices système. La fiche native actuelle, ses hauteurs moyenne et grande, ses avertissements et ses actions restent en place.

Hors périmètre : photos de lieux et leur stockage, lettrage décoratif façon autocollant, retournement 3D de fiche, nouveau moteur de carte, nouvelle dépendance, changement de Firebase ou de SwiftData, nouveau regroupement de favoris, modification des pins sociaux ou du brouillard. Ce sprint n'ajoute pas de recentrage automatique à l'ouverture d'une adresse.

## Spécification produit

### R1. Trois états de présentation

Les dimensions suivantes sont les valeurs de départ. Un ajustement mineur après inspection sur simulateur doit être consigné dans le plan ; un changement de comportement ou de périmètre exige une nouvelle approbation.

| État | Présentation | Condition |
|---|---|---|
| Compact | Rond de 28 pt, SF Symbol de catégorie, sans texte. Cible tactile d'au moins 44 × 44 pt. | Zoom insuffisant ou place insuffisante pour les détails. |
| Détaillé | Rond de 40 pt, nom sur une ligne et catégorie à côté du rond, dans la disposition actuelle. Nom tronqué en fin de ligne, largeur de texte bornée à 160 pt. | Autorisation de zoom et espace disponible pour l'ensemble. |
| Sélectionné | Rond de 48 pt, accentuation avec la teinte système existante et priorité parmi les adresses. Nom et catégorie si l'espace le permet, indépendamment du seuil de zoom. | L'adresse correspond à la fiche effectivement ouverte. |

L'état sélectionné conserve sa taille et son accentuation si ses textes doivent être masqués. Une seule adresse peut être sélectionnée. Le contenu reste lisible sur le fond pastel actuel et l'icône reste ancrée sur sa coordonnée dans tous les états.

La visibilité est distincte de ces états. Un lieu hors champ, à coordonnées invalides ou masqué par une collision ne devient pas un quatrième état visuel. Un lieu sélectionné hors champ reste sélectionné logiquement et réapparaît correctement quand il revient à l'écran.

### R2. Zoom, placement et collisions

- Conserver les seuils initiaux des détails : activation à zoom 14 et désactivation sous 13,7. Entre les deux, conserver l'autorisation précédente.
- Donner la priorité aux icônes. Un nom trop long ou une catégorie en collision fait revenir le lieu non sélectionné au compact avant d'envisager son masquage.
- Placer d'abord les icônes compactes, puis accepter les agrandissements et les textes qui tiennent. L'agrandissement d'une adresse non sélectionnée ne doit pas évincer une autre icône compacte déjà acceptée.
- Masquer un lieu entier seulement lorsque son icône compacte rencontre un autre marqueur prioritaire. Les textes et les lieux masqués ne réservent pas d'espace.
- Garder l'ordre stable existant par `sourceID`, puis `placeID`, avec l'adresse sélectionnée traitée en premier. Conserver les règles existantes de priorité des marqueurs sociaux ; les adresses restent hors de leurs groupes.
- La sélection garantit l'icône de l'adresse dans le champ selon la priorité actuelle du store. Ses textes restent soumis aux collisions. Elle ne doit pas permettre des textes superposés.
- Garder séparés les rectangles visuels et les zones tactiles. L'espace occupé par un texte ou une cible de 44 pt ne doit pas servir à masquer abusivement les petits cercles.
- Conserver le rejet des coordonnées invalides et de la sentinelle de projection Mapbox `(-1, -1)`.

Aucun quota de pins et aucun classement par distance au centre de l'écran. L'ancien filtrage progressif par densité a été annulé ; les collisions réelles restent le critère de masquage.

### R3. Stabilité pendant les gestes

Appliquer les changements dus au seul seuil de zoom à l'arrêt effectif de la caméra. Pendant un geste, conserver les dimensions tant qu'une collision ne nécessite pas de réduction. Une adresse réduite ou masquée ne doit pas être promue plusieurs fois pendant le même dézoom.

Les nouvelles promotions vers détaillé attendent le repos. Les réductions nécessaires aux collisions restent possibles, mais l'espace libéré ne déclenche pas une cascade de réapparitions. Préserver la mémorisation actuelle des masquages pendant le dézoom et ses conditions de remise à zéro. Le zoom de bord doit toujours signaler son début et sa fin à Mapbox.

### R4. Sélection liée à la fiche

`ContentView.selectedSavedPlace` est la source de vérité. Le toucher demande l'ouverture de la fiche ; le pin devient sélectionné seulement lorsque l'application accepte cette ouverture.

- Transmettre l'identifiant sélectionné à la carte et synchroniser son apparence après la réconciliation des annotations.
- Une synchronisation programmatique ne doit pas rappeler l'ouverture de la fiche ni produire une boucle SwiftUI/UIKit.
- Fermer par le bouton ou par glissement efface la sélection visuelle. Le pin reprend l'état permis par le zoom et l'espace actuels.
- L'action « Créer un événement » efface également la sélection avant le passage au formulaire existant.
- Pouvoir rouvrir plusieurs fois la même adresse après fermeture.
- Si une ouverture est refusée parce qu'un import ou un formulaire est déjà présenté, le pin ne reste pas sélectionné.
- Réimporter un lieu conserve son identité et actualise son nom, sa catégorie et sa coordonnée sans rejouer une animation d'apparition à chaque mise à jour.
- Retirer l'annotation ou démonter la carte annule ses animations et nettoie son état. Un changement de compte ne conserve aucune sélection de l'ancien compte.

Aujourd'hui, `MapWithFogView` désélectionne immédiatement le favori après le toucher pour permettre sa réouverture. Ne pas simplement supprimer cette ligne : remplacer ce comportement par la synchronisation complète du cycle de la fiche.

### R5. Animations et interaction

Prévoir environ 180 à 220 ms pour un changement compact/détaillé et un léger ressort pour la sélection. L'ouverture de la fiche commence sans attendre la fin de l'animation.

Animer le contenu intérieur de la vue, en laissant Mapbox gérer son placement géographique. Informer Mapbox d'une nouvelle taille logique lors d'un changement d'état, sans déclencher une mesure et un recalcul de collisions à chaque image de l'animation. Mesurer le contenu attendu indépendamment des anciens frames que Mapbox peut encore appliquer.

Réserver l'encombrement nécessaire à la transition entre les tailles de départ et d'arrivée. Masquer un texte avant qu'il ne rencontre un autre marqueur et ne le révéler que lorsque sa place est disponible. Les icônes visibles gardent une opacité de 100 % ; ne pas réintroduire l'atténuation des lieux superposés.

Une nouvelle transition repart de l'apparence courante et remplace la précédente. Les callbacks terminés en retard ne doivent pas restaurer un ancien état. Les sous-vues décoratives n'interceptent pas les touches. Conserver une cible tactile utilisable et vérifier que les cibles proches n'activent pas un autre lieu que celui touché.

Respecter le réglage système de réduction des animations avec un changement direct ou atténué. Conserver le nom, la catégorie et les actions d'accessibilité natives existantes.

## Architecture et fichiers concernés

Conserver la chaîne existante : `ContentView` possède l'adresse ouverte, `MapWithFogView` transmet cet état, `MapAnnotationStore` décide du placement et `SavedPlaceAnnotationView` dessine et anime. Centraliser la géométrie des états pour que mesure, collisions et tests utilisent des dimensions cohérentes. Étendre les composants existants sans recréer un moteur général de densité.

| Fichier | Travail prévu |
|---|---|
| `wander/SavedPlaceAnnotation.swift` | États, géométrie, mesure, aspect sélectionné et animations interrompables. |
| `wander/MapAnnotations.swift` | Collisions tenant compte des tailles, priorité et synchronisation visuelle sans boucle de sélection. |
| `wander/MapWithFogView.swift` | Entrée d'identifiant sélectionné, réconciliation, traitement de la fin des gestes et des changements de sources. |
| `wander/ContentView.swift` | Transmettre la sélection de la fiche et préserver son cycle de fermeture/création d'événement. |
| `wander/DebugSocialMapScenario.swift` | Reproduire la même liaison de sélection dans les scénarios locaux. |
| `wanderTests/SavedPlaceAnnotationTests.swift` | États, mesure, collisions, sélection, interruption et réconfiguration. |
| `wanderUITests/NaverImportUITests.swift` | Parcours réels, assertions adaptées à la géométrie variable, captures de validation. |
| Ce plan | Checklist, approbation, résultats exacts et limites. |

`SavedPlaceDetailView.swift` et `SavedPlace.swift` servent de références ; leur modification n'est pas prévue. Réutiliser les tests de `MapEdgeZoomControllerTests` et `MapSocialProximityControllerTests` pour les régressions partagées. Ne pas modifier les attentes des tests uniquement pour faire passer un comportement incorrect.

## Plan d'implémentation

### U1. Présentation et géométrie

Implémenter R1 et les mesures nécessaires à R5 dans `SavedPlaceAnnotation.swift`, avec les scénarios correspondants dans `SavedPlaceAnnotationTests.swift`.

- [x] Définir les trois états et leurs dimensions dans un emplacement unique.
- [x] Maintenir l'ancrage du cercle, la mesure indépendante des frames et la cible tactile.
- [x] Couvrir les noms longs, les catégories inconnues et la reconfiguration d'un lieu.

Terminé lorsque chaque état produit la géométrie attendue après placement Mapbox, y compris après réception d'un ancien frame compact.

### U2. Placement stable

Dépend de U1. Appliquer R2 et R3 dans `MapAnnotations.swift` et `MapWithFogView.swift`, avec tests dans `SavedPlaceAnnotationTests.swift` et adaptation du scénario dense dans `NaverImportUITests.swift`.

- [x] Remplacer les hypothèses fixes de cercles de 36 pt par la géométrie de présentation.
- [x] Conserver les icônes compactes avant d'ajouter les détails et traiter les priorités.
- [x] Préserver les masquages stables pendant le dézoom et recalculer au repos.
- [x] Couvrir les coordonnées invalides, les entrées/sorties du champ et les changements de caméra ; limites de couverture du viewport précisées ci-dessous.

Terminé lorsque plusieurs adresses restent visibles en zone dense sans texte superposé ni alternance masqué/visible au cours d'un même dézoom continu.

### U3. Sélection et transitions animées

Dépend de U1 et U2. Appliquer R4 et R5 dans les vues et le store, puis transmettre la sélection depuis `ContentView` et `DebugSocialMapScenario`. Étendre les tests natifs et UI cités dans les fichiers concernés.

- [x] Synchroniser l'adresse effectivement ouverte sans récursion ni réouverture de fiche.
- [x] Rétablir compact/détaillé après toutes les voies de fermeture.
- [x] Ajouter les animations courtes et annulables sans retard d'activation.
- [x] Nettoyer les animations lors de la suppression, du démontage et de la réutilisation.
- [x] Vérifier les sélections répétées et les changements d'état pendant une animation.

Terminé lorsque le pin sélectionné correspond toujours à la fiche, revient au bon état à sa fermeture et reste utilisable après interruption d'une animation.

### U4. Validation, revue et documentation

Dépend de U1 à U3. Suivre le workflow du dépôt avec `ce-simplify-code`, `ce-test-xcode`, `ce-code-review`, puis `ce-compound` seulement si un apprentissage réutilisable le justifie. Si un outil est indisponible, effectuer l'équivalent et préciser la méthode employée.

- [x] Exécuter la validation obligatoire sur simulateur ci-dessous.
- [x] Inspecter visuellement les états et les transitions ; joindre les preuves.
- [x] Effectuer une revue ciblée et consigner les problèmes restants dans `todos/` avec leur priorité.
- [x] Actualiser les notes Obsidian listées ci-dessous, leur propriété `updated` et leurs wikilinks.
- [x] Consigner les résultats et limites, puis vérifier tous les critères de clôture.

## Validation obligatoire sur simulateur

### Environnement

Utiliser uniquement l'iPhone 18 Pro déjà démarré et autorisé en tête du plan. Les validations historiques utilisaient un iPhone 17 Pro ; vérifier le nom et l'UDID du simulateur actuellement actif plutôt que recopier un ancien identifiant.

Ne pas démarrer, créer, cloner ou télécharger un autre simulateur ou runtime sans approbation explicite de Samuel. Désactiver l'exécution parallèle des tests pour éviter les simulateurs de test supplémentaires. Si aucun simulateur autorisé n'est actif, signaler la validation bloquée et demander son démarrage ou l'autorisation nécessaire ; ne pas remplacer cette validation par une simple compilation.

Utiliser une taille de texte standard. Aucun test d'accessibilité dédié, de grande police, de Display Zoom, de VoiceOver ou de Switch Control n'est demandé pour ce sprint.

### Exécution et suites ciblées

Utiliser les outils Xcode disponibles ou `xcodebuild` avec `simctl`. Exécuter réellement les tests sur la destination choisie et vérifier le nombre de tests exécutés et leurs résultats dans le `.xcresult`.

Exemple de préparation en lecture seule :

```bash
xcrun simctl list devices booted
```

Depuis la racine du dépôt, remplacer `UDID_DU_SIMULATEUR_DEJA_DEMARRE` par l'identifiant vérifié avant d'exécuter :

```bash
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'platform=iOS Simulator,id=UDID_DU_SIMULATEUR_DEJA_DEMARRE' \
  -parallel-testing-enabled NO \
  -only-testing:wanderTests/SavedPlaceAnnotationTests \
  -only-testing:wanderTests/MapEdgeZoomControllerTests \
  -only-testing:wanderTests/MapSocialProximityControllerTests \
  -only-testing:wanderUITests/NaverImportUITests \
  test
```

La commande compile les cibles et exécute les suites choisies. Traiter les avertissements introduits comme des défauts. Décrire séparément tout avertissement préexistant.

Les fixtures locales existent déjà : arguments `-debug-social-map`, `-debug-social-map-fullscreen`, `-debug-social-map-naver`, puis liens de démonstration `https://naver.me/demo`, `https://naver.me/dense` et `https://naver.me/long-place` dans l'import. Ces URL sont interceptées par le scénario Debug pour produire des données synthétiques ; elles ne prouvent pas un échange Naver réel. La fixture dense contient 36 adresses.

### Scénarios d'acceptation

| ID | Scénario | Résultat à vérifier |
|---|---|---|
| V1 | Import simple, zoom avant puis arrière autour de 14/13,7. | Compact puis détaillé selon les seuils ; pas de changement de taille dû au seul zoom avant la fin du geste. |
| V2 | Huit icônes espacées avec noms longs, puis scénario de 36 adresses denses. | Les noms cèdent avant les icônes ; pas de texte superposé ni de quota arbitraire. |
| V3 | Dézoom continu au pincement puis au bord, inversion vers le zoom avant. | Pas de cascade masqué/visible/masqué, pas de saut d'ancrage, retour des détails au repos. |
| V4 | Toucher une adresse depuis compact puis depuis détaillé. | Une seule fiche s'ouvre immédiatement ; le bon pin passe en sélectionné. |
| V5 | Fermer par le bouton puis par glissement et rouvrir la même adresse. | Sélection effacée, état recalculé, réouverture possible à chaque fois. |
| V6 | Choisir « Créer un événement » depuis une fiche. | Pin désélectionné et formulaire toujours prérempli ; la fiche ne se rouvre pas. |
| V7 | Touchers rapprochés et nouvelle transition pendant une animation. | Aucun callback tardif ne restaure l'ancien état, aucune double ouverture ni blocage des gestes. |
| V8 | Réimporter un lieu et retirer une annotation au niveau du store. | Texte/catégorie actualisés sans doublon ; animation et sélection nettoyées au retrait. |
| V9 | Pan, rotation, sortie/retour dans le champ et présentation de la fiche près d'un bord. | Ancrage conservé, visibilité correcte, aucun pin affiché à la sentinelle `(-1, -1)`. |
| V10 | Adresses proches des amis et événements ; geste de bord démarré sur icône ou texte. | Priorités et activation sociales conservées ; zoom de bord et toucher ordinaire restent distincts. |

Les tests actuels contiennent des dimensions fixes de 36/44 pt et des attentes de largeur pour identifier les libellés. Les adapter aux états réellement affichés en conservant les assertions de séparation et de maintien des icônes. Vérifier les rectangles rendus, pas seulement les valeurs d'une fonction de calcul.

### Inspection et preuves

Après les tests automatisés, lancer l'application dans le simulateur et inspecter les trois états, le dézoom continu, une interruption d'animation et la fermeture/réouverture de fiche. Utiliser les outils de contrôle du simulateur disponibles. Si l'observation ou le contrôle sont impossibles, signaler précisément cette limite et laisser la validation visuelle non acquittée.

Enregistrer des captures des trois états et une courte vidéo couvrant zoom, sélection et fermeture. Examiner les captures et la vidéo avant de conclure. Vérifier le contraste sur la carte pastel, la fluidité, l'ancrage et l'absence de chevauchement pendant le mouvement. Les fixtures avec un style vide isolent les tests natifs ; elles ne remplacent pas l'inspection du rendu de l'application.

Consigner ici le modèle du simulateur, son UDID, son runtime, les commandes exactes, les suites et nombres de tests, les résultats, le chemin du `.xcresult`, les captures/vidéos et les limites. Les scénarios synthétiques ne prouvent ni la liste privée de Samuel ni les échanges Firebase/Naver réels.

## Documentation à actualiser pendant l'implémentation

Vault : `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander`.

- `Backlog features.md`, section Import de favoris Naver : démarrage, périmètre et clôture de l'évolution.
- `Documentation UX.md`, section Import d'une liste Naver : états, dimensions finales, règles de zoom, collisions, animations et sélection.
- `Documentation technique.md`, section Favoris Naver locaux : propriété de la sélection, synchronisation, géométrie et validation.
- `00 - Wander.md`, section État du projet : résumé du nouveau comportement et liens utiles.

Mettre à jour `updated` sur chaque note modifiée et préserver les wikilinks. Ne pas ouvrir Obsidian. Si le vault est absent ou inaccessible en écriture, consigner les notes et sections restantes ici et le signaler à Samuel ; ne pas créer de copie ailleurs et ne pas annoncer ces mises à jour comme réalisées.

## Risques et décisions

| Risque | Réponse prévue |
|---|---|
| Clignotement lorsque les pins changent de dimensions. | Promotions au repos, réductions stables pendant le mouvement, tests pendant le dézoom. |
| Mesure réduite par un ancien frame Mapbox. | Mesurer le contenu attendu indépendamment des bounds attribués par le moteur. |
| Fiche ouverte avec un pin désélectionné, ou sélection restée active après fermeture. | Propriété unique dans `ContentView` et synchronisation sans callback d'ouverture. |
| Collision pendant un agrandissement ou mauvaise cible au toucher. | Géométrie de transition explicite, contrôle des rectangles rendus et tests de touches proches. |
| Charge excessive à chaque image. | Vues réutilisées, animations internes et recalculs regroupés selon les événements existants. |

Les dimensions finales sont 28/40/48 pt, avec transitions de 200 ms et sélection avec ressort de 220 ms. Leur rendu a été inspecté dans les preuves ci-dessous. Aucun système hybride de `SymbolLayer`, cache d'images ou nouveau framework d'animation n'a été ajouté.

## Critères de clôture

- [x] R1 à R5 sont satisfaits dans l'application.
- [x] V1 à V10 ont une preuve de validation ; les échecs et les tests non exécutés sont explicitement identifiés.
- [x] Les suites ciblées ont réellement tourné sur le simulateur autorisé et passent.
- [x] Les états et les transitions ont été inspectés sur simulateur, avec captures et vidéo.
- [x] La revue ne laisse aucun défaut bloquant ; les autres constats sont consignés avec leur priorité dans `todos/`.
- [x] Les notes prévues sont actualisées, ou leur indisponibilité est signalée avec les sections restantes.
- [x] Les tentatives abandonnées sont retirées et les modifications préexistantes sont préservées.
- [x] La validation exacte est ajoutée ci-dessous avant `status: completed` et `completed_at`.

Ne pas marquer le sprint terminé si la validation sur simulateur ou l'inspection des animations n'a pas été effectuée. Un blocage de validation doit être rapporté comme tel.

## Validation réalisée

### Environnement et premières passes du 24 octobre 2026

- Approbation explicite de Samuel obtenue avant toute édition, passage `approved` puis `in_progress`.
- Checkout existant conservé. Aucune commande Git mutatrice. Modification préexistante de `wander/MapboxConfiguration.swift` et plan d'inclinaison préservés.
- Ponytail et `ce-work` utilisés. `ce-test-xcode` ne dispose pas de XcodeBuildMCP dans cette session ; exécution équivalente via `xcodebuild`, `simctl` et les tests XCUITest, comme autorisé par le plan.
- Simulateur vérifié : iPhone 18 Pro, iOS 27.0 build 24A434, UDID `CD1E7A76-F65E-495D-A525-F328746F152F`. Aucun autre appareil créé ou démarré. Tests parallèles désactivés.
- Mode local existant : `-debug-social-map -debug-social-map-fullscreen -debug-social-map-naver`. SwiftData en mémoire, aucun patch d'authentification. Jeton Mapbox local présent dans le build, vraies tuiles observées sans lire ni afficher le jeton.
- Contrôle macOS indisponible car le Mac est verrouillé et Samuel est absent. Les tests UI et `simctl io ... screenshot` fonctionnent néanmoins. L'inspection utilise les captures et enregistrements du simulateur.
- Première passe native : **69 tests réussis, 0 échec, 0 ignoré**. Résultat `/private/tmp/wander-pins-native-1.xcresult`, log `/private/tmp/wander-pins-native-1.log`. Vérification par `xcresulttool get test-results summary`.
- Les tests ont été ajoutés/adaptés après inspection du comportement existant ; aucun échec préalable test-first n'est revendiqué. Les tests de présentation vérifient les sous-vues réellement dessinées et les couches de présentation pendant interruption.
- Avertissements de build préexistants : `CFBundleVersion` des extensions 15/27 différent du parent 53. Xcode émet aussi des diagnostics de version du système et de débogueur ; aucun avertissement Swift introduit dans cette passe.
- `ce-simplify-code` terminé : aucun constat de réutilisation ; suppression d'une propriété de géométrie inutilisée, d'allocations intermédiaires par pin dans le calcul de collision et de commentaires narratifs. Les tests de preuve sont conservés. Revue `ce-code-review` terminée, résultat détaillé ci-dessous.
- Les quatre notes Obsidian prévues sont actualisées avec la clôture, les 79 tests et les limites ; propriété `updated` rafraîchie et wikilinks préservés. Aucun lancement d'Obsidian.

Commande de la première passe :

```bash
xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration Debug -destination 'platform=iOS Simulator,id=CD1E7A76-F65E-495D-A525-F328746F152F' -parallel-testing-enabled NO -collect-test-diagnostics never -disableAutomaticPackageResolution -only-testing:wanderTests/SavedPlaceAnnotationTests -only-testing:wanderTests/MapEdgeZoomControllerTests -only-testing:wanderTests/MapSocialProximityControllerTests -resultBundlePath /private/tmp/wander-pins-native-1.xcresult test > /private/tmp/wander-pins-native-1.log 2>&1
```


### Diagnostic et correction de l'ancrage

La mesure initiale comparait la géométrie cible à la projection. Son renforcement vers le centre réellement rendu a révélé un décalage transitoire supérieur à 8 pt. Une simple animation de frame, puis de bounds/center, du matériau n'a pas corrigé ce point sur iOS 27. La transformation directe du matériau ne correspondait pas non plus à sa couche de présentation. Un conteneur UIKit ordinaire à bounds fixes porte désormais l'échelle du matériau et du symbole ; Mapbox conserve le placement géographique. Les dimensions visibles et les durées approuvées restent inchangées.

La [note de diagnostic](../solutions/2026-10-24-animer-pins-liquid-glass-autour-ancre.md) conserve les mesures et les approches écartées. `ce-debug` a servi au diagnostic et `ce-compound`, en mode léger, à cette capture. Les validateurs de références et de frontmatter passent. `CONCEPTS.md` est inchangé, aucun nouveau terme de domaine n'étant nécessaire.

| Exécution dans `/private/tmp/` | Résultat | Interprétation |
|---|---|---|
| `wander-pins-native-2.xcresult` | 69/69 | Régression native après simplification, avant renforcement de la mesure d'ancrage. |
| `wander-pins-ui-1.xcresult` | 7/10 | Deux publications bloquées par le fuseau, une fausse classification de largeur compacte. |
| `wander-pins-dense-2.xcresult` | 1/1 | Le seuil de largeur du test tolère les arrondis autour de 44 pt. |
| `wander-pins-final.xcresult` | 77/79 | Mesure réelle d'ancrage en échec ; assertion de sélection UI conservant un indice devenu instable. |
| `wander-pins-diagnostic.xcresult` | 1/2 | Touchers voisins validés par identifiant stable ; décalage du matériau reproduit. |
| `wander-pins-anchor-fix.xcresult` | 8/10 | Bounds/center insuffisants. |
| `wander-pins-anchor-scale.xcresult` | 9/10 | Échelle directe du matériau insuffisante pour une présentation cohérente. |
| `wander-pins-glass-probe.xcresult` | 0/1 | Diagnostic modèle/présentation confirmant la divergence. |
| `wander-pins-container.xcresult` | 10/10 | Conteneur ordinaire, ancrage rendu et interruptions validés. |

Le scénario UI capture l'identifiant de chaque voisin avant sélection, car la priorité du pin sélectionné peut changer l'ordre des éléments retournés par XCTest. Il vérifie ensuite le nom de la fiche et la sélection du bon identifiant, y compris après un double toucher.

Les publications utilisent `TZ=Asia/Seoul` dans le seul processus du scénario de test. Le système retournait `Asia/Kolkata`, accepté par Foundation mais rejeté par la liste utilisée dans la validation existante. Ce défaut préexistant est suivi dans [le constat P2 082](../../todos/082-pending-p2-accepter-alias-fuseaux-iana.md) ; aucune validation métier ni règle Firebase n'a été modifiée.

La revue ciblée ne demande plus de correction source. Receipt : `/tmp/compound-engineering-501/ce-code-review/20261024-201050-f3f796c4/review.json`. La revue adversariale utilise le repli local, le runner externe ne permettant pas de limiter son diff aux sept fichiers du sprint. Risque de test retenu : un simulateur suspendu pendant toute une transition de 200 ms peut manquer sa fenêtre de mesure. Aucun échec de cette nature n'a été observé ; les échecs ci-dessus ont été diagnostiqués séparément.

### Validation finale : 79 tests réussis

La dernière exécution complète termine avec un code de sortie 0 : **79 réussites, 0 échec, 0 test ignoré**. Le résumé est lu depuis le résultat Xcode, et non déduit de la seule compilation. Durée des tests : 339,709 s.

| Suite | Réussites |
|---|---:|
| `SavedPlaceAnnotationTests` | 10 |
| `MapEdgeZoomControllerTests` | 25 |
| `MapSocialProximityControllerTests` | 34 |
| `NaverImportUITests` | 10 |

Commande finale, depuis la racine du dépôt :

```bash
xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration Debug -destination 'platform=iOS Simulator,id=CD1E7A76-F65E-495D-A525-F328746F152F' -parallel-testing-enabled NO -collect-test-diagnostics never -disableAutomaticPackageResolution -only-testing:wanderTests/SavedPlaceAnnotationTests -only-testing:wanderTests/MapEdgeZoomControllerTests -only-testing:wanderTests/MapSocialProximityControllerTests -only-testing:wanderUITests/NaverImportUITests -resultBundlePath /private/tmp/wander-pins-verified.xcresult test > /private/tmp/wander-pins-verified.log 2>&1
```

Résultat : `/private/tmp/wander-pins-verified.xcresult`. Résumé exporté : `/private/tmp/wander-pins-verified-summary.json`. Les dernières modifications après ce passage concernent uniquement la documentation et les preuves.

| Scénario | Preuves obtenues et limites |
|---|---|
| V1 | Hystérésis 14/13,7 et maintien des dimensions pendant le mouvement vérifiés nativement ; états finaux et zoom vérifiés en UI et dans la vidéo. |
| V2 | Huit noms longs : icônes conservées et rectangles rendus séparés pendant le dézoom. Fixture dense de 36 adresses en UI ; les marqueurs visibles sont vérifiés, sans exiger 36 icônes simultanées. |
| V3 | Échantillonnage natif pendant le dézoom, absence de réapparitions successives, retour des détails au repos ; gestes de bord UI, pincement avant et inspection du dézoom filmé. L'inversion immédiate d'un pincement arrière dans un même geste n'est pas un parcours UI automatisé distinct. |
| V4 | Ouverture depuis détaillé et compact, sélection du bon pin et diamètre de 48 pt vérifiés en UI. La latence d'ouverture n'est pas chronométrée. |
| V5 | Fermeture par bouton et glissement, sélection effacée, retour au compact et réouverture vérifiés en UI et sur l'enregistrement. |
| V6 | Préremplissage, annulation/réouverture et publication validés dans le scénario local. La désélection au passage au formulaire repose sur la revue de la liaison de sélection ; aucune assertion UI spécifique ne mesure ce passage. |
| V7 | Interruption mesurée sur la couche de présentation, un seul callback final ; séquence native interrompue inspectée image par image. Double toucher et deux cibles de 44 pt chevauchantes activent la bonne identité en UI. |
| V8 | Réimport identique et message de mise à jour en UI ; reconfiguration native du nom/type et retrait nettoyant la sélection. Pas de réimport de contenu modifié de bout en bout, ni de comptage explicite des objets persistés après réimport. |
| V9 | Centre réellement rendu échantillonné pendant la sélection, rotation de 55° puis séparation, sortie/retour conservant la sélection, coordonnées invalides et sentinelle exclues ; pans UI. Pas de mesure pendant la rotation elle-même ni de test dédié au redimensionnement du viewport. |
| V10 | Priorité sociale au niveau du store ; 34 tests sociaux et 25 tests de zoom de bord ; gestes UI démarrant sur icône/texte suivis d'un toucher ordinaire. Données sociales synthétiques. |

### Preuves visuelles examinées

Les captures issues du dernier résultat et l'enregistrement `simctl` ont été examinés. La vidéo du parcours a été parcourue à une image par seconde, puis les ouvertures/fermetures à dix images par seconde et le dézoom à cinq images par seconde. La séquence native d'interruption a été extraite à vingt images par seconde. Ces observations complètent les mesures de la couche de présentation ; elles ne constituent pas un benchmark de fluidité sur appareil physique.

- [Compact](/private/tmp/wander-pins-validation/compact.png), [détaillé](/private/tmp/wander-pins-validation/detaille.png), [sélectionné](/private/tmp/wander-pins-validation/selectionne.png) et [zone dense](/private/tmp/wander-pins-validation/dense.png).
- [Vidéo de 26 secondes : zoom, sélection, fermeture et réouverture](/private/tmp/wander-pins-validation/pins-demo.mp4).
- Planches inspectées : `/private/tmp/wander-pins-validation/selection-motion.png`, `dismiss-motion.png`, `zoom-motion.png` et `interruption-motion.png` dans le même dossier.

Les cercles restent circulaires, la sélection bleue est distincte sur la carte pastel et les noms visibles restent séparés. Le retour à 28/40 pt après fermeture et le retrait des textes au dézoom sont observés. Le test natif de l'interruption utilise une fenêtre transparente de test ; il complète l'inspection de la vraie carte sans la remplacer. Les preuves sont locales et temporaires, sous `/private/tmp/`.

### Clôture et limites conservées

La revue ciblée et sa vérification finale du conteneur ne laissent aucun défaut bloquant du sprint. Le résultat final de 79/79 complète le receipt de revue, produit avant la fin de ce passage. Le défaut de fuseau préexistant reste suivi séparément en P2, sans modification de la publication dans ce sprint.

Le mode Debug existant a permis de tester sans connexion au compte. Aucun changement d'authentification, de schéma, de règle Firebase ou de dépendance n'a été ajouté. Les échanges réels Firebase/Naver, les données privées, les changements réels de compte et le refus d'ouverture par un autre formulaire ne sont pas couverts de bout en bout ; leur liaison a été revue dans le code. Aucun test d'accessibilité dédié n'a été exécuté.

Les quatre notes Obsidian sont à jour. Les approches d'animation abandonnées sont retirées. `git diff --check` passe. La modification préexistante de `MapboxConfiguration.swift` et le plan d'inclinaison restent préservés ; aucune commande Git mutatrice n'a été exécutée.

## Références

- `docs/plans/2026-10-11-conserver-icones-et-eviter-textes-superposes.md` : collision des cercles et des textes, mesure après placement natif.
- `docs/plans/2026-10-11-stabiliser-adresses-pendant-dezoom.md` : seuils au repos et signalement du zoom de bord.
- `docs/plans/2026-10-11-annuler-adresses-progressives.md` : abandon du filtrage arbitraire par densité.
- `docs/solutions/2026-09-02-rendre-interactions-mapkit-immediates.md` : distinguer latence d'activation et durée d'animation ; appliquer le principe UIKit sans copier les anciennes API MapKit.
- `docs/solutions/2026-08-26-controle-parent-indicateur-mapkit.md` : préserver la cible du toucher dans les vues composées.
- [Mapbox : View annotations](https://docs.mapbox.com/ios/maps/guides/markers-and-annotations/view-annotations/) : vues UIKit, ancrage et mise à jour de taille.

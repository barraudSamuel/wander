---
title: Fluidité et priorité des pins d'adresses
date: 2026-10-25
status: completed
completed_at: 2026-10-25T10:46:12+05:30
approved_at: 2026-10-25
tags: [map, saved-places, animation, ios]
---

# Fluidité et priorité des pins d'adresses

## Approbation et résultat attendu

Samuel a approuvé le plan présenté dans cette conversation par « je valide » le 25 octobre 2026. Un seul sprint est autorisé. L'exception visuelle aux contrôles iOS natifs reste celle déjà approuvée pour les pins photo.

Les adresses proches du centre utile doivent pouvoir grandir pendant le déplacement de la carte, sans attendre le relâchement du geste. Les transitions compact/détaillé doivent être progressives, interrompables et ancrées au lieu. Une photo périphérique déjà grande ne doit pas garder indéfiniment la place d'une adresse centrale. Les libellés ne doivent pas décider seuls de la taille des photos.

Ce correctif remplace les règles du sprint précédent qui gelaient les promotions pendant les gestes et interdisaient la priorité au centre. Les états restent compact, détaillé et sélectionné. Les fiches recto/verso et leurs actions doivent rester fonctionnelles.

## Périmètre et dépendances

Utiliser les vues UIKit et Mapbox déjà présentes. Pas de migration, de nouvelle dépendance, de changement des données ou du rendu des pins sociaux. Respecter leurs zones occupées. Aucun changement Git mutateur, commit ou publication. Préserver les modifications préexistantes, y compris celles sans rapport avec les pins.

Référence : `/Users/samuelbarraud/Downloads/8WlF_NQxpVslwGdX.mp4`, surtout le déplacement et le zoom de 0 à 7 secondes. La capture de Samuel montre le problème de hiérarchie. Les règles exactes du logiciel filmé ne sont pas connues.

Le simulateur existant iPhone 18 Pro, iOS 27, `CD1E7A76-F65E-495D-A525-F328746F152F`, est déjà démarré et a servi à la validation précédente. Ne pas démarrer, créer ni télécharger un autre appareil/runtime. Utiliser la taille de texte standard.

## Fichiers concernés

- `wander/MapAnnotations.swift` : attribution commune des états cibles, centre utile et transfert de place.
- `wander/MapWithFogView.swift` : actualisation pendant la caméra et les gestes.
- `wander/SavedPlaceAnnotation.swift`, `wander/SavedPlacePresentation.swift`, `wander/SavedPlaceCalloutView.swift` : taille et texte indépendants, courbe, interruption et silhouette réservée.
- `wanderTests/SavedPlaceAnnotationTests.swift`, `wanderTests/SavedPlacePresentationTests.swift`, `wanderTests/SavedPlaceSelectionTests.swift` : contrat corrigé et régressions.
- `wanderUITests/NaverImportUITests.swift`, `wander/DebugSocialMapScenario.swift` si nécessaire : démonstration et recette des gestes.
- Ce plan, les preuves vidéo sous `docs/plans/assets/`, les constats de revue sous `todos/` et une leçon réutilisable sous `docs/solutions/`.
- Notes Obsidian dans `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/` : `Backlog features.md`, `Documentation technique.md`, `Documentation UX.md`, `00 - Wander.md`. Mettre à jour `updated`, préserver les wikilinks et ne pas ouvrir Obsidian. Si inaccessible, consigner exactement les mises à jour restantes.

## Étapes

- [x] Diagnostic et approbation explicite.
- [x] Capturer les preuves avant correction et les tests qui reproduisent le mauvais contrat.
- [x] Calculer les états cibles ensemble : sélection, proximité du centre utile, puis identifiant pour départager. Stabiliser les changements pendant le mouvement sans verrou permanent.
- [x] Séparer la place occupée par photo, libellé et transition ; permettre de céder la place progressivement et de détailler une photo dont le libellé doit rester caché.
- [x] Actualiser pendant pan, zoom, inertie et zoom de bord. Remplacer la courbe trop frontale, préserver la continuité et l'ancre.
- [x] Simplifier puis valider les tests natifs et les gestes sur le simulateur existant.
- [x] Comparer la vidéo à la référence, examiner les frames longues avant/après et produire une courte vidéo du déplacement réel.
- [x] Revue indépendante, documentation, notes Obsidian et bilan exact de validation.

## Risques et décisions

La priorité au centre peut provoquer des échanges incessants entre voisins : une marge de stabilité pendant le mouvement doit les limiter, puis la vue stabilisée doit converger. Les états cibles sont calculés sans donner une priorité permanente aux tailles actuelles. Les réservations de transition servent uniquement à éviter que l'agrandissement traverse un voisin qui rétrécit.

Une animation déjà commencée peut changer de cible. Continuer depuis la forme affichée, avec une vitesse cohérente, et ne jamais déplacer indépendamment l'ancre géographique. Mesurer avant de prétendre qu'un coût de rendu est la cause de pertes d'images.

## Validation et critères d'acceptation

- Un compact isolé peut grandir pendant un geste, sans attendre la fin de la caméra.
- À zoom autorisant le détail, une adresse centrale peut prendre la place d'une adresse périphérique, indépendamment des identifiants et de l'historique d'affichage.
- Les changements de sens près d'une limite ne provoquent pas de bascules continuelles.
- Une collision de texte peut cacher le libellé sans imposer une petite photo.
- Le transfert de place, les croisements, les sélections et les fermetures n'introduisent pas de chevauchement durable ni de saut d'ancre.
- Les tests couvrent les comportements nouveaux et la sélection existante ; la vidéo montre pan, zoom et changements de taille à densité représentative.
- Comparer la progression temporelle et les temps de frames sur le même scénario. Distinguer le coût de calcul de l'animation, les frames du simulateur et la cadence d'encodage de la vidéo. Ne pas présenter un GIF à 15 images/s comme mesure de fluidité.

## Validation exécutée

Diagnostic analytique initial : l'ancienne courbe d'agrandissement de 240 ms atteint environ 63 % à 16,7 ms et 92 % à 33,3 ms. Ce calcul établit une progression brusque, pas une mesure de FPS.


### Implémentation retenue

- Les candidats partagent un classement : fiche ouverte/fermeture, distance au centre de `visibleSafeMapRect`, puis sourceID/placeID. Une avance de 12 pt protège le gagnant pendant un mouvement ; elle disparaît au repos. La planification part des empreintes compactes, sans privilégier une grande photo déjà affichée.
- La photo peut rester détaillée quand son texte ne tient pas. Les réservations photo, texte et fiche 3D restent distinctes. Le perdant libère sa place avant l’agrandissement du gagnant.
- Compact/détaillé dure 280 ms avec une cubique paramétrique. Un changement de cible conserve la forme et la vitesse ; la poignée de contrôle est bornée pour empêcher une fermeture interrompue de réduire la photo sous 24 pt. Une demande identique conserve l’animation en cours et son éventuelle nouvelle completion.
- Les mises à jour de caméra ne gèlent plus les promotions. Le changement de viewport relance aussi le résolveur. La partie visible d’un avatar garde sa réservation même quand son centre est hors du crop.
- Le dézoom pur conserve les petits pins déjà masqués. Une tolérance de 0,01 pt sur la projection du centre ignore les arrondis Mapbox, sans figer un déplacement réel.
- Les petites photos ne mesurent ni titre de fiche ni scroll d’informations à chaque frame. Les priorités Mapbox restent constantes hors sélection.

### Preuves de reproduction et mesures

| État | p95 des intervalles de rendu, 3 passages | Maximum observé | p95 du résolveur |
|---|---|---|---|
| Avant le sprint, promotions gelées (`red2`) | 18,05 / 19,42 / 21,23 ms | 33,94 ms | ≤ 0,46 ms |
| Première correction avec layout des fiches invisibles (`green1`) | 41,83 / 43,92 / 42,36 ms | 119,99 ms | ≤ 0,74 ms |
| Après suppression du layout invisible (`green3`) | 17,73 / 17,77 / 18,01 ms | 21,45 ms | ≤ 0,71 ms |
| Version finale (`final2`) | 18,11 / 17,86 / 17,67 ms | 22,53 ms | ≤ 0,69 ms |

Même appareil, même scénario synthétique de 36 pins sur style sans fond, trois séquences pan/zoom de 0,8 s par passage, sans profileur pour ces mesures. Il s’agit d’intervalles entre callbacks `onRenderFrameFinished`, pas d’une mesure GPU ni d’une garantie sur appareil physique. Le sample CPU qui a identifié le layout des UILabel/scroll est conservé dans `/private/tmp/wander-pin-motion-cpu.txt` ; son exécution perturbait les timings et n’entre pas dans ce tableau.

Les tests de déplacement pendant caméra/zoom tenu échouaient trois fois avant correction (`/private/tmp/wander-pin-motion-red2.xcresult`). Le test de prise de priorité centrale, après correction de sa fixture initiale, échouait quatre fois (`/private/tmp/wander-pin-motion-priority-red.xcresult`). Ils passent dans `green3` avec 28 tests natifs sans échec, y compris les allers-retours de ±3 pt autour d’une égalité et la convergence au repos.

La mesure de continuité compare une différence finie sur 1 µs à la vitesse initiale, tolérance 0,25 pt/s. L’ancien essai sur 0,1 ms confondait une vitesse instantanée avec une moyenne pendant la forte accélération initiale d’une inversion ; l’écart n’était pas une rupture de continuité. L’inversion temporelle utilise 36 bissections. Le scénario vérifié reste sous 0,13 pt d’excursion initiale après inversion.

### Recette UI et revue

- `/private/tmp/wander-pin-motion-ui-demo.xcresult` : nouveau pan/zoom dense réussi. Ce test vérifie présence des pins et absence d’ouverture involontaire ; la preuve automatique de priorité centrale est dans le test natif, pas dans son simple comptage d’éléments UI.
- `/private/tmp/wander-pin-motion-ui-regressions.xcresult` : sept parcours réussis (zoom, deux bords, fiche suivant la carte, recto/verso, création d’événement et longue fiche). L’ancien test dense attendait le retour d’un même pin après recadrage de sélection, malgré le nouveau classement par centre. Le test choisit maintenant sa paire après chaque recadrage, ouvre deux IDs distincts par leurs photos séparées malgré leurs cibles tactiles qui se chevauchent, vérifie le titre exact puis l’absence de sélection après fermeture.
- La revue indépendante a retenu deux P2 : relancer les collisions après crop/expansion et réserver les marqueurs sociaux partiellement visibles. Les deux corrections et leurs tests sont présents. `/private/tmp/wander-pin-motion-viewport.xcresult` : deux tests réussis. Le premier montage du test social reparentait une carte déjà montée et a fait planter le processus Mapbox ; la fixture crée désormais son viewport avant le montage, comme l’application. La recette interrompue `wander-pin-motion-final.xcresult` ne vaut pas validation.
- Captures recto/verso de `ui-regressions` exportées et inspectées : photo, catégorie, titre, pointe et contrôles visibles ; texte du verso lisible, contenu inférieur accessible par scroll. Le contrôle pixel complète les assertions d’existence des boutons.
- Validation finale : `/private/tmp/wander-pin-motion-final2.xcresult`, **TEST SUCCEEDED** le 25 octobre à 10:44. **30 tests natifs et 4 parcours UI sans échec**, sur le binaire final. Durées : 41,29 s pour les tests natifs, 202,35 s pour les UI. Les captures recto/verso de cette dernière exécution ont aussi été inspectées : [recto](assets/2026-10-25-fluidite-pins/fiche-recto.png), [verso](assets/2026-10-25-fluidite-pins/fiche-verso.png).

### Preuves visuelles

- [Déplacement et zoom — MP4](assets/2026-10-25-fluidite-pins/deplacement-et-zoom.mp4).
- [Aperçu animé](assets/2026-10-25-fluidite-pins/deplacement-et-zoom.gif).
- [Début du déplacement](assets/2026-10-25-fluidite-pins/debut-deplacement.png) et [pendant le déplacement](assets/2026-10-25-fluidite-pins/pendant-deplacement.png).

La vidéo est issue d’un enregistrement du simulateur, à vitesse réelle, sans interpolation de mouvement. Le fichier MP4 est encodé à 60 images/s et l’aperçu GIF à cadence réduite ; ni l’un ni l’autre ne remplace les mesures de callbacks ci-dessus. Comparaison avec les 0–7 s de la référence : même ancre stable, variation progressive de taille au déplacement/zoom, catégorie au-dessus et maintien de photos compactes pour les collisions. La règle interne de l’application de référence reste inconnue ; aucune fidélité pixel à pixel n’est revendiquée.

### Limites

Les imports et coordonnées des recettes sont synthétiques ; aucun flux Naver/Firebase réel n’est validé ici. Pas de nouveau simulateur, test dédié d’accessibilité, migration, dépendance ou commande Git mutatrice. Les warnings de tooling Xcode/AppIntents et les messages Mapbox de localisation refusée dans les fixtures existaient avant ce sprint ; aucun nouveau warning Swift n’est accepté. Une densité qui ne permet pas une photo de 50 pt garde un pin compact même près du centre.


### Commande finale reproductible

```bash
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'platform=iOS Simulator,id=CD1E7A76-F65E-495D-A525-F328746F152F' \
  -disableAutomaticPackageResolution -parallel-testing-enabled NO \
  -only-testing:wanderTests/SavedPlaceAnnotationTests \
  -only-testing:wanderTests/SavedPlacePresentationTests \
  -only-testing:wanderTests/SavedPlaceSelectionTests \
  -only-testing:wanderUITests/NaverImportUITests/testDenseAddressesHideOverlapsAndOpenDetails \
  -only-testing:wanderUITests/NaverImportUITests/testDensePinsFollowPanAndZoomWithoutOpeningCard \
  -only-testing:wanderUITests/NaverImportUITests/testOpenCardFollowsMapDragAndClosesOutsideTheUsefulViewport \
  -only-testing:wanderUITests/NaverImportUITests/testPhotoCardFlipsAndClosesFromBothPinSizes \
  -resultBundlePath /private/tmp/wander-pin-motion-final2.xcresult test
```

Utiliser un nouveau chemin de résultat pour relancer : Xcode refuse d’écraser un `.xcresult` existant. Les trois suites natives contiennent respectivement 13, 12 et 5 tests. Les valeurs brutes du tableau sont aussi conservées dans [cadence.json](assets/2026-10-25-fluidite-pins/cadence.json).

La revue `ce-code-review` complète porte uniquement sur le delta de ce sprint, contre les instantanés pris avant travail, et non sur toutes les modifications préexistantes du checkout. Huit lectures indépendantes et une validation des deux corrections de viewport : aucun constat actionnable restant. Reçu `status: complete` : `/tmp/compound-engineering-501/ce-code-review/20261025-102747-f728099c/review.json`. Le parcours cross-model n’a pas été exécuté, son entrée Git ne pouvant représenter le delta d’instantanés sans élargir le périmètre ; la contradiction a été réalisée par un reviewer local indépendant. Constats clos : [083](../../todos/083-done-p2-recalculer-pins-sur-viewport.md), [084](../../todos/084-done-p2-reserver-avatars-partiellement-visibles.md).


### Clôture

Tous les critères d’acceptation de ce sprint passent. Les quatre notes Obsidian approuvées ont été mises à jour le 25 octobre, propriété `updated` comprise, sans ouvrir Obsidian : Backlog features, Documentation technique, Documentation UX et 00 - Wander. Le diagnostic de layout invisible est consigné dans [la solution dédiée](../solutions/2026-10-25-eviter-layout-fiches-invisibles-pins.md). La vérification de format `git diff --check` passe. Les modifications préexistantes sont conservées ; aucune commande Git mutatrice, aucun commit ni déploiement n’a été effectué.

La vidéo finale de 16 secondes provient du test pan/zoom réussi dans `final2` ; le GIF de 7 secondes en est un extrait à 20 images/s. Le reçu de revue a été rendu pendant les derniers UI ; sa réserve sur la recette finale est levée par le résultat ci-dessus. Les suites testées ne sont pas présentées comme la totalité des tests du projet.

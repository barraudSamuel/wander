---
title: Zoom à un doigt aux bords de la carte
status: in_progress
date: 2026-09-20
owner: Samuel
---

# Zoom à un doigt aux bords de la carte

## Résultat et approbation

Samuel approuve le plan avec la bulle de retour visuel : « je valide, implemente ».
Un glissement vertical à un doigt commencé dans les 28 points du bord gauche
ou droit de la carte visible zoome vers le haut et dézoome vers le bas, sans
déplacer son centre. Une bulle noire attachée au bord suit la hauteur du doigt
et se rétracte au relâchement ou à l'annulation, selon la capture Bump fournie.

## Périmètre et approche

Un contrôleur UIKit possède le geste et les commandes de zoom MapKit. Il
distingue les départs verticaux des panoramiques horizontaux, ignore les
contrôles et annotations interactives et interrompt le suivi utilisateur avant
de modifier la caméra. Un dessin non interactif restitue le geste au bord.
Les coordonnées viennent du viewport visible, y compris avec un panneau ouvert.
Le pincement, le double toucher, le recentrage et les panneaux restent disponibles.
Aucun changement Firebase, dépendance, navigation ou dessin de brouillard.

## Fichiers concernés

- `wander/MapWithFogView.swift` : installation, coordination et nettoyage.
- `wander/MapEdgeZoomController.swift` : reconnaissance et zoom continu.
- `wander/MapEdgeZoomFeedbackView.swift` : dessin et rétraction de la bulle.
- `wanderTests/MapEdgeZoomControllerTests.swift` : géométrie, limites et coordination.
- `wanderUITests/MapSocialGestureUITests.swift` : gestes aux bords et non-régression.
- `docs/plans/2026-09-20-zoom-bords-carte.md` : progression et preuves.
- `todos/` : constat priorisé si une validation reste indisponible.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md` : avancement.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md` : geste et retour visuel.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md` : contrôleur, dessin et validation.

## Mise en œuvre

- [x] Installer un geste vertical à un doigt sur les deux bords.
- [x] Appliquer un zoom progressif borné, arrêter le suivi et préserver le centre.
- [x] Dessiner, déplacer et rétracter la bulle ; nettoyer à l'annulation.
- [x] Ajouter les tests de géométrie, échelle du zoom et coexistence des gestes.
- [x] Simplifier, compiler, relire et consigner les limites de validation.
- [x] Actualiser les trois notes Obsidian et leur propriété `updated`.
- [ ] Valider les gestes et le rendu en exécution sur iPhone.

## Risques et validation

- Éviter que le panoramique natif et le zoom de bord déplacent simultanément la caméra.
- Exclure les contrôles, les fiches et les zones masquées de la reconnaissance.
- Annuler proprement lors d'un second doigt, d'un redimensionnement ou d'une interruption.
- Vérifier les deux bords, le sens, les limites du zoom, le centre fixe, la bulle,
  le panoramique horizontal et central, le pincement, le double toucher et le recentrage.
- Compiler l'application et ses tests. Exécuter les tests sur l'iPhone 17 uniquement
  s'il est déjà démarré ; aucun appareil ou runtime supplémentaire ne sera lancé.
- Aucun test dédié d'accessibilité. Aucun Git mutateur, commit ou publication.

## État initial

Le dépôt contient des modifications préexistantes de navigation et de documentation,
conservées hors du périmètre. Le travail reste dans le checkout actuel conformément
à l'interdiction de commandes Git mutatrices. Les instructions du dépôt priment sur
les étapes de branche, commit et publication des skills Compound Engineering.
`xcrun simctl list devices booted` ne trouve aucun simulateur démarré.
Les tests seront ajoutés et compilés ; aucune exécution rouge/verte ne sera revendiquée
sans simulateur disponible. La validation tactile sur appareil restera explicite.

## Implémentation et revue

Le contrôleur possède un `UIPanGestureRecognizer` à un doigt. Les autres pans
de la carte attendent sa décision ; les appuis longs n'attendent pas son échec,
ce qui préserve la création d'événement sur un bord immobile. Le contrôleur ne
remplace aucun delegate de MapKit et ne désactive pas ses interactions.

Les changements de distance sont exponentiels, avec 150 points pour doubler ou
diviser par deux. Chaque delta part de la distance appliquée par MapKit pour
éviter une zone morte à l'inversion aux limites. Les valeurs demandées restent
dans `cameraZoomRange`, ou entre 80 mètres et 30 000 kilomètres à défaut.
La caméra du début de geste fournit le centre, le cap et l'inclinaison.

La bulle mesure 20 points de profondeur et 144 points de hauteur. Son tracé est
recadré à la zone visible ; sa rétraction dure 0,16 seconde et respecte Réduire
les animations. Le nouveau geste repart du bord courant, même après un geste
sur l'autre bord. Elle est non interactive. Le changement de viewport,
l'interruption de l'app et le démontage nettoient le geste et son retour visuel.

Skills utilisés : `ce-work`, `ce-simplify-code`, `ce-code-review`, `obsidian-markdown`.
`ce-test-xcode` ne peut pas exécuter son parcours sans XcodeBuildMCP, absent des
outils disponibles ; la compilation CLI du projet sert de validation partielle.
Trois relectures de simplification n'ont signalé aucune duplication ou anomalie
de qualité. Deux optimisations de dessin ont été appliquées : ne pas réassigner
une frame inchangée et ne pas lire le tracé de présentation sans animation.
L'ordre des sous-vues est rétabli à chaque mise à jour, car les indicateurs
hors écran remontent aussi leur conteneur lors des changements de caméra.
Les copies de caméra préservent le snapshot initial ; leur coût n'est pas mesuré.

Revue de correction : `/tmp/wander-edge-zoom-review/report.md`.
Corrections issues de la revue : préserver l'appui long au bord et empêcher
l'animation d'entrée de traverser la carte lors d'un changement de côté.
Décision principale : donner la priorité au zoom seulement après sélection du
bord et de l'intention verticale, avec les API publiques UIKit.
Alternative écartée : une zone transparente qui intercepterait tous les touchers
au bord, y compris les contrôles et les panoramiques horizontaux.
Incertitude restante : arbitrage effectif des recognizers internes MapKit et
rendu tactile, suivis dans `todos/058-ready-p2-valider-zoom-bords-carte.md`.

## Validation

- Application et tests compilés avec `xcodebuild -project wander.xcodeproj
  -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator'
  build-for-testing`.
- Première compilation : `TEST BUILD SUCCEEDED`, journal `/tmp/wander-edge-zoom-build.log`.
- Compilation finale après corrections de revue : `TEST BUILD SUCCEEDED`,
  journal `/tmp/wander-edge-zoom-final-build.log`, le 20 septembre 2026 à 15:34 KST.
  Aucun nouvel avertissement Swift ; extraction AppIntents ignorée comme auparavant.
- `git diff --check` réussi. Vérification des nouveaux fichiers, frontmatters,
  propriétés `updated` et références du plan dans les trois notes réussie.
- Sept tests unitaires et trois parcours UI ajoutés ; aucune exécution revendiquée.
- Avertissements préexistants : extraction AppIntents sans dépendance et versions
  des extensions 15/27 différentes de l'app 42, déjà suivies dans le constat 054.
- Les trois notes Obsidian ont été mises à jour avec leur propriété `updated`
  et leurs wikilinks préservés. Obsidian n'a pas été ouvert.
- Le plan reste `in_progress` jusqu'à validation en exécution. Pas de nouvelle
  leçon vérifiée à consigner dans `docs/solutions/` avant ce retour.

Références d'API :
- https://developer.apple.com/documentation/uikit/uigesturerecognizerdelegate/gesturerecognizer(_:shouldberequiredtofailby:)
- https://developer.apple.com/documentation/mapkit/mkmapcamera/centercoordinatedistance

## Correction du calcul des limites après retour sur iPhone

Le 20 septembre, Samuel signale « le zoom fonctinne pas » et fournit un
enregistrement de 4,64 secondes. La bulle suit le doigt, mais la carte saute
à une échelle très proche puis reste bloquée. Le geste se déclenche donc bien.
Ce correctif conserve le geste, la bulle et le périmètre approuvés.

Cause : `cameraZoomRange` peut être non nil et contenir `MKMapCameraZoomDefault`
pour les deux bornes. Cette constante vaut -1 ; `??` ne la remplace pas. Le calcul
`max(-1, min(-1, distance))` envoyait systématiquement -1 à la caméra. Un essai
MapKit sur macOS confirme une plage initiale -1/-1 et reproduit le calcul fautif
avec la fonction extraite directement du fichier de production.

- [x] Reproduire le défaut de calcul avant correction : trois échecs, y compris
  pour un déplacement nul. Journal `/tmp/wander-edge-zoom-default-red.log`.
- [x] Résoudre chaque borne par défaut indépendamment en 80 / 30 000 000 mètres.
- [x] Renforcer les tests existants avec une vraie plage MapKit par défaut et
  les combinaisons borne par défaut / borne explicite.
- [x] Rejouer le calcul, compiler les tests, relire et actualiser la documentation.
- [x] Confirmer le fonctionnement du zoom sur l'iPhone de Samuel, retour « ça fcntionne ».

Les tests précédents utilisaient des bornes explicites et ne couvraient pas la
valeur sentinelle. La reproduction macOS vérifie le calcul et l'API de plage,
pas l'interaction tactile iOS. Aucun simulateur n'est démarré.

### Validation du correctif

- Avant : trois cas échouent avec la vraie plage par défaut de MapKit sur macOS,
  la fonction calculant -1 mètre pour haut, bas et déplacement nul.
- Après : huit cas de calcul passent, couvrant les deux sens, l'absence de mouvement,
  les limites explicites et les combinaisons avec une borne par défaut.
  Journal `/tmp/wander-edge-zoom-default-green.log` ; reproduction
  `/tmp/wander-edge-zoom-default-probe.swift`. La fonction est extraite du fichier
  de production, sans réécrire sa logique dans le programme de vérification.
- `build-for-testing` : `TEST BUILD SUCCEEDED`, journal
  `/tmp/wander-edge-zoom-sentinel-build.log`, le 20 septembre à 15:41 KST.
  Aucun nouvel avertissement Swift ; seuls les avertissements AppIntents habituels.
- Deux tests ajoutés à `MapEdgeZoomControllerTests`, compilation réussie,
  non exécutés sur iOS. Les parcours tactiles restent à confirmer.
- `git diff --check` réussi. Revue ciblée des quatre lignes de production et des
  assertions de régression. Aucun autre comportement ou fichier d'implémentation
  modifié. Pas de simplification supplémentaire utile sur ce correctif minimal.
- Code review: targeted manual due to unrelated branch work. Défaut vérifié et
  corrigé dans le calcul ; aucun défaut supplémentaire identifié dans ces lignes.
- Les trois notes Obsidian et leurs propriétés `updated` ont été actualisées.
  Le constat 058 reste ouvert jusqu'au retour sur iPhone.

## Sensibilité augmentée de 20 %

Samuel confirme le fonctionnement sur son iPhone puis demande un zoom légèrement
plus rapide. Il approuve le réglage proposé de 180 à 150 points avec « implemente ».
Le coefficient de réponse au déplacement augmente de 20 %. La bulle, la zone
de départ et les bornes de caméra restent celles du plan.

Périmètre : `MapEdgeZoomController.swift`, tests existants de sensibilité et de
plages par défaut, ce plan, le constat 058 et les trois notes Obsidian déjà listées.
Validation : rejouer les huit cas de calcul avec la fonction de production,
compiler l'application et les tests, vérifier le diff. Le risque est une
sensibilité excessive ; le réglage reste exponentiel et borné.

- [x] Passer à 150 points et ajuster les assertions existantes.
- [x] Vérifier le calcul, compiler et relire le changement.
- [x] Documenter la confirmation iPhone et le nouveau réglage dans le suivi et Obsidian.

Le retour de Samuel valide le fonctionnement général du zoom corrigé, sans
attester individuellement tous les scénarios secondaires du constat 058.

Validation de l'ajustement : huit cas de calcul passent avec la fonction extraite
du contrôleur, journal `/tmp/wander-edge-zoom-speed-check.log`. Application et
tests compilés avec `build-for-testing` : `TEST BUILD SUCCEEDED`, journal
`/tmp/wander-edge-zoom-speed-build.log`, le 20 septembre à 15:47 KST. Aucun nouvel
avertissement Swift, seuls les avertissements AppIntents habituels.
Tests iOS compilés mais non exécutés. `git diff --check` réussi. Revue ciblée
du coefficient, du commentaire et des attentes numériques existantes ; aucune
simplification supplémentaire utile pour ce réglage. Les trois notes Obsidian
sont actualisées avec leur propriété `updated` et leurs liens conservés.

## Ancrage social automatique

Le plan approuvé `docs/plans/2026-09-20-zoom-cible-centrale.md` ajoute le choix
automatique de l'ami, de l'événement ou du groupe visible le plus central au
début du geste. La coordonnée est figée jusqu'au relâchement, sans sélection ni
ouverture de fiche. Le centre fixe de ce plan devient le repli sans cible ;
avec une cible, la caméra zoome autour de sa position. Bulle et sensibilité de
150 points conservées. Compilation et 71 vérifications Mac réussies ; validation
iPhone du nouvel ancrage et limite native à forte inclinaison suivies au constat 058.

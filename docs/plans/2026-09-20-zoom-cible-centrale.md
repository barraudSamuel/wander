---
title: Ancrer automatiquement le zoom sur le repère le plus central
status: in_progress
date: 2026-09-20
owner: Samuel
---

# Ancrer automatiquement le zoom sur le repère le plus central

## Résultat et approbation

Samuel demande que le zoom au bord vise automatiquement l'ami ou l'événement
le plus proche du centre. Après clarification du caractère automatique, il
approuve le comportement par « je valide ».

Au début du geste, choisir le repère social visible le plus proche du centre de
la carte visible. Un groupe affiché constitue une seule cible. Après l'ajustement approuvé en fin
de document, une transition de 0,18 seconde amène la cible au centre visible, avec
un impact léger unique au début. Le zoom accompagne cette transition puis
reste centré sur la cible, sans ouverture de fiche. La coordonnée
cible reste figée pendant le geste, même si les données sociales évoluent.
Sans repère éligible, garder le zoom autour du centre de caméra. Les bords,
la bulle, le suivi interrompu et la sensibilité de 150 points sont conservés.

## Périmètre et dépendances

Réutiliser les annotations effectivement affichées et le viewport existant.
Les cibles sont le profil personnel, les amis, événements et groupes qui en
contiennent. Exclure les brouillons et les indicateurs hors écran. Le profil
personnel a été ajouté par l’ajustement approuvé en fin de document.
Ne pas utiliser la sélection MapKit : cibler ne doit pas ouvrir une fiche.
Le centre de caméra peut maintenant se déplacer pour maintenir le point
d'ancrage du zoom ; cela remplace le centre fixe du plan précédent quand une
cible est présente. Aucune modification Firebase, navigation ou regroupement.

## Fichiers concernés

- `wander/MapEdgeZoomController.swift` : choix et mémorisation de la cible, caméra ancrée.
- `wander/MapWithFogView.swift` : candidats issus des annotations sociales affichées.
- `wanderTests/MapEdgeZoomControllerTests.swift` : sélection, repli, stabilité et caméra.
- `wanderUITests/MapSocialGestureUITests.swift` : zoom autour du groupe visible et fiche ouverte.
- `docs/plans/2026-09-20-zoom-cible-centrale.md` : progression et preuves.
- `docs/plans/2026-09-20-zoom-bords-carte.md` : lien vers le nouveau comportement.
- `todos/058-ready-p2-valider-zoom-bords-carte.md` : suivi des validations tactiles restantes.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md`.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md`.

## Mise en œuvre

- [x] Fournir les repères affichés, en conservant les groupes comme cibles uniques.
- [x] Choisir le plus central une seule fois et figer sa coordonnée pendant le geste.
- [x] Calculer la caméra autour de l'ancrage sans saut au démarrage ; conserver le repli sans cible.
- [x] Adapter les tests de sélection et de caméra, y compris sans cible et avec fiche.
- [x] Simplifier, valider, relire et mettre à jour les trois notes Obsidian.

## Risques et validation

Le choix de cible ne doit pas changer entre deux événements du geste. Les
annotations masquées par les panneaux et celles hors écran sont exclues.
Éviter les sauts de caméra, y compris aux limites du zoom ou près de l'antiméridien.
Conserver cap et inclinaison. Vérifier l'ancrage, le choix déterministe à égalité,
le repli sans cible, la cible figée et l'absence de sélection automatique.

Compiler l'app et ses tests. Exécuter les calculs MapKit vérifiables sur macOS
et les tests iOS uniquement si l'iPhone 17 est déjà démarré. Aucun nouveau
simulateur ni test dédié d'accessibilité. Distinguer les preuves de calcul,
la compilation et la validation tactile sur iPhone.

Le dépôt contient des modifications préexistantes, conservées. Aucun Git
mutateur, commit ou publication. Le workflow Compound Engineering est appliqué
dans ces limites ; le plan demeure la source du suivi.

## Validation et revue du 20 septembre

Implémentation terminée. Le statut reste `in_progress` jusqu'à la validation
fonctionnelle iPhone, suivie par le constat 058.

- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug
  -destination 'generic/platform=iOS Simulator' build-for-testing` :
  `TEST BUILD SUCCEEDED`, journal `/tmp/wander-edge-zoom-target-final-build.log`,
  16:02 KST. Aucun nouvel avertissement Swift ; avertissements AppIntents habituels.
- Sept tests unitaires ajoutés pour le ciblage, les groupes, le snapshot, le
  repli, l'antiméridien et la projection d'une vraie carte tournée/inclinée.
  Le parcours UI des deux bords vérifie maintenant la stabilité du groupe et
  l'absence d'ouverture automatique. Le parcours avec fiche reste présent.
  Tests iOS compilés mais non exécutés : aucun simulateur démarré, constat
  confirmé par `xcrun simctl list devices booted`. Aucun appareil lancé.
- 71 vérifications réussies sur macOS avec `Target`, `ZoomSession`,
  `nearestTarget`, `anchoredCenter` et `distance` extraits du code de production.
  Projection MapKit testée à 0° et 30° d'inclinaison, caps 0°/45°/180°, échelles
  1/0,5/2/0,125/8. Dérive inférieure à un point. Sélection visible, égalités,
  snapshot, repli et antiméridien vérifiés. Journal
  `/tmp/wander-edge-zoom-target-probe.log`, programme du même nom en `.swift`.
- Limite native identifiée séparément : à 50° et au dézoom, MapKit impose 35°
  dans le probe macOS ; l'ancrage dérive alors d'environ 19 points. Les 12
  assertions d'ancrage/orientation échouées dans cette exploration ne sont pas
  comptées comme passantes. Journal `/tmp/wander-edge-zoom-target-pitch-limit.log`.
  La caméra demandée conserve bien le cap et l'inclinaison ; cette limite du
  rendu natif reste à apprécier sur iPhone, notamment aux échelles lointaines.
- `ce-simplify-code` : trois lectures indépendantes, qualité/réutilisation/coût.
  La session ne conserve maintenant que la coordonnée cible. Pas de nouvel enum
  d'identité : la chaîne locale ne sert qu'au départage. Pas de cache géométrique
  supplémentaire pour deux projections constantes par échantillon, ni de lookup
  de vue pour les annotations non sociales : pas de bénéfice démontré.
- `ce-code-review` : lecture ciblée du contrôleur, de son intégration et des
  tests selon le plan et `AGENTS.md`, profondeur lite (comportement local visible).
  Les modifications préexistantes de navigation/recentrage sont exclues ; les
  nouveaux fichiers non suivis sont lus explicitement. Aucun défaut bloquant
  retenu. Couverture tactile et limite d'inclinaison consignées dans le constat
  058 et `/tmp/wander-edge-zoom-target-review/report.md`.
- `git diff --check` réussi après les dernières modifications.
- Les trois notes Obsidian prévues ont été mises à jour avec `updated` et les
  liens existants conservés, sans ouvrir Obsidian.

- [ ] Confirmer sur iPhone le ciblage ami/événement/groupe, les deux sens, le
  repli sans repère et la fiche ouverte ; apprécier le dézoom fortement incliné.

## Ajustement approuvé : recentrage et retour haptique

Statut de cet ajustement : in_progress. Approbation enregistrée avant modification. Samuel approuve le plan présenté par
« je valide » : recentrer la cible au centre de la carte visible avec une courte
transition au début du glissement, puis zoomer sur cette cible. Une seule vibration
légère signale la prise de focus. Sans cible, aucun recentrage ni vibration.
Ce comportement remplace l'ancrage à la position initiale du repère.

Fichiers : contrôleur, tests unitaires et UI existants, ce plan, constat 058,
et les trois notes Obsidian déjà listées. Validation : calcul de projection avec
viewport recadré, continuité zoom/recentrage, focus unique, annulation, compilation
et iPhone 17 seulement s'il est déjà démarré. Le ressenti haptique requiert un iPhone.

- [x] Recentrer progressivement et zoomer avec une seule commande de caméra.
- [x] Déclencher un impact léger une fois par cible acquise au début du geste.
- [x] Adapter et vérifier les tests, relire, actualiser le suivi et Obsidian.

### Validation de l'ajustement

- Caméra pilotée par `CADisplayLink` pendant 0,18 seconde. Les deltas du doigt
  sont accumulés puis consommés une seule fois par image avec le recentrage.
  Après la transition, le geste pilote directement la caméra comme auparavant.
- Un relâchement précoce termine le focus sans saut ; une nouvelle touche,
  l'annulation, le redimensionnement ou le démontage interrompent la transition.
  Le display link est invalidé dans tous les chemins de fin.
- Impact natif `.light` unique à l'acquisition d'une cible, sur le main actor.
  Aucun impact sans cible ; aucune répétition pendant le zoom. La bulle et la
  sensibilité de 150 points sont conservées.
- 77 vérifications Mac passent avec les fonctions de production extraites :
  centrage dans un viewport décalé, caps/inclinaisons, plusieurs échelles,
  progression continue du focus combiné au zoom, snapshot et repli.
  `/tmp/wander-edge-zoom-focus-probe.log` et programme `.swift` associé.
- Tests existants adaptés au nouveau centrage. Deux tests de lifecycle ajoutés :
  callback unique/absence de cible/annulation et fin de geste court/reprise.
  Les ticks de transition sont pilotés par un temps explicite dans le test de
  fin de geste. Ils sont compilés, non exécutés faute de simulateur démarré.
  La vérification préalable utilisait les tests existants et le comportement
  observé ; aucun résultat rouge XCTest n'est revendiqué.
- `build-for-testing` final : `TEST BUILD SUCCEEDED`, 16:16 KST,
  `/tmp/wander-edge-zoom-focus-final-build.log`. Les avertissements d'isolation
  du callback haptique apparus au premier build ont été corrigés. Aucun nouvel
  avertissement Swift, seul l'avertissement AppIntents habituel.
- Simplification à trois lectures : pas de réutilisation équivalente ; les
  suggestions de commande de caméra unique par image et de tests de fin courte
  ont été appliquées. Revue finale du périmètre, transitions et exigences :
  `/tmp/wander-edge-zoom-focus-review/report.md`. Aucun défaut bloquant retenu.
- Les trois notes Obsidian sont actualisées. Aucun simulateur lancé, aucun Git
  mutateur. `git diff --check` réussi.

Le ressenti haptique, la transition et les gestes réels sur iPhone restent à
confirmer dans le constat 058. Le plan conserve `in_progress` pour cette validation.

## Profil personnel : ajustement approuvé

Statut : in_progress, après approbation. Samuel valide l'ajout de son propre profil aux cibles le
20 septembre. Même règle du repère visible le plus central, même recentrage et
impact léger, sans priorité forcée ni réactivation du suivi de position.
Périmètre : MapWithFogView.swift, tests unitaires et UI existants, ce plan,
constat 058 et les trois notes Obsidian listées. Vérifier profil seul, compétition
avec un ami/événement, groupes et exclusion des repères hors écran.

- [x] Inclure UserLocationAnnotation et adapter l'éligibilité des groupes.
- [x] Adapter les tests et compiler ; actualiser la documentation et le suivi.

Validation : filtre et sélection vérifiés par 11 cas sur Mac. Les fonctions
sont extraites de production, avec des types d'annotations de test réduits pour
le filtre ; ce probe ne valide pas leur rendu iOS. Journal
`/tmp/wander-edge-zoom-self-probe.log`. Les tests XCTest utilisent les vrais types.
Le test UI des deux bords cible maintenant le profil central ; un parcours avec
le profil seul vérifie le recentrage après un panoramique. Compilation
`build-for-testing` réussie, journal `/tmp/wander-edge-zoom-self-final-build.log`.
Aucun nouveau warning Swift. Tests iOS compilés mais non exécutés : aucun
simulateur démarré. Le ressenti sur iPhone reste suivi dans le constat 058.
Revue ciblée du filtre, de la règle du plus proche et des assertions existantes ;
aucune simplification supplémentaire utile pour ce changement de quatre lignes.
Aucun défaut bloquant retenu. Documentation Obsidian actualisée ; diff vérifié.

Reçu de revue : `/tmp/wander-edge-zoom-self-review/report.md`.

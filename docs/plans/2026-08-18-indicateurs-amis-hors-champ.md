---
title: "Indicateurs d’amis et d’événements hors champ sur la carte"
status: in_progress
date: 2026-08-18
approved_at: 2026-08-18
started_at: 2026-08-18
spacing_reapproved_at: 2026-08-18
local_overlap_reapproved_at: 2026-08-18
size_reapproved_at: 2026-08-18
event_scope_reapproved_at: 2026-08-18
direction_arrow_reapproved_at: 2026-08-18
nonoverlap_pointer_reapproved_at: 2026-08-18
pointer_geometry_reapproved_at: 2026-08-18
compact_overlap_reapproved_at: 2026-08-18
event_pointer_reapproved_at: 2026-08-18
owner: "Samuel Barraud"
related:
  - "2026-08-15-rail-amis-carte.md"
tags: [plan, map, friends, events, interaction]
---

# Indicateurs d’amis et d’événements hors champ sur la carte

## Outcome

Lorsqu’un ami possédant une dernière position utilisable sort du champ de la
carte, son avatar apparaît automatiquement sur le bord correspondant à sa
direction. L’indicateur suit le panoramique, le zoom et la rotation, puis
disparaît dès que le pin normal redevient visible. Un toucher recentre la carte
sur cet ami.

Les événements restent toujours représentés, quel que soit le niveau de zoom.
Dans le cadrage, un badge natif personnalisé affiche le SF Symbol de leur
catégorie dans la couleur de l’organisateur. Hors cadrage, ce badge rejoint le
même système de bord que les avatars ; un toucher recentre, sélectionne
l’événement et ouvre sa fiche.

## Context

La carte affiche déjà les positions des amis sous forme de pins, conserve les
dernières positions connues et sait centrer un ami. Le rail social du bord
droit reste une interaction séparée : il permet de parcourir les amis, tandis
que les nouveaux indicateurs rendent immédiatement visibles les amis situés
hors du cadrage courant.

La demande approuvée le 2026-08-18 étend ce sprint aux événements. Elle remplace
l’ancien non-objectif qui les excluait et délègue la validation visuelle et
interactive au propriétaire du projet.

Les compétences Compound Engineering demandées par le dépôt ne sont pas
disponibles dans cette session. Le workflow équivalent est appliqué
manuellement : investigation et choix de solution, implémentation,
simplification, validation, revue et capitalisation si une leçon réutilisable
émerge.

## Scope

- Included:
  - indicateur automatique pour chaque ami possédant une position valide et
    dont le pin est hors champ ;
  - direction calculée selon la projection courante de MapKit, y compris après
    rotation de la carte ;
  - avatar et couleur de profil existants, avec opacité réduite pour une
    position ancienne ;
  - triangle de la couleur du profil attaché directement à chaque avatar
    d’ami hors champ, dont la pointe vise la position projetée exacte ;
  - placement dans une zone sûre de la carte et regroupement compact à environ
    30 % de superposition lorsque plusieurs directions proches doivent être
    réparties autour du périmètre ;
  - mise à jour pendant le panoramique et le zoom ;
  - toucher pour centrer et sélectionner l’ami ;
  - libellé et indication VoiceOver ;
  - coexistence avec les pins, contrôles, fiches de sortie et rail d’amis.
  - priorité MapKit requise pour tous les événements, sans clustering ;
  - badge d’événement personnalisé à partir de la catégorie et de la couleur
    existantes, sans nouvel asset bitmap ;
  - triangle compact de la couleur de l’organisateur attaché au badge hors
    champ et pointant vers la position projetée exacte de l’événement ;
  - indicateur de bord pour chaque événement hors cadrage ;
  - résolution commune des chevauchements entre avatars et événements ;
  - toucher pour recentrer, sélectionner et ouvrir la fiche de l’événement.
- Not included:
  - distance ou adresse affichée en permanence ;
  - modification de Firebase, des règles Firestore ou du modèle d’amitié ;
  - changement du rail d’amis existant ;
  - indicateur pour la position de l’utilisateur ;
  - nouvel asset bitmap ou modification des catégories ;
  - validation interactive ou visuelle, prise en charge manuellement par le
    propriétaire ;
  - déploiement ou publication TestFlight.

## Proposed approach

Observer les changements de région de `MKMapView` dans son coordinateur. Pour
chaque annotation d’ami, convertir sa coordonnée en point d’écran et vérifier
si le cadre complet du pin appartient encore à la zone utile de la carte. Si
le pin est hors champ, intersecter le rayon allant du centre de cette zone vers
le point projeté avec son rectangle intérieur.

Un composant UIKit dédié présente l’avatar existant dans un bouton circulaire
de taille tactile native. Le coordinateur crée, met à jour et retire ces vues
sans republier chaque image de caméra dans l’état SwiftUI. Les positions proches
sont décalées de manière déterministe le long d’un même bord afin de conserver
tous les indicateurs visibles et touchables. Les contrôles SwiftUI existants
restent au-dessus de la carte.

Le toucher réutilise le flux de sélection cartographique existant : le
coordinateur centre le pin avec la région déjà utilisée pour un ami et le
sélectionne, sans nouvelle donnée ni nouvelle navigation.

L’avatar compact reste dans une cible tactile de 48 points. Le badge rond et
son chevron sont remplacés par un triangle plein de la couleur du profil,
dessiné derrière le cercle et attaché à celui-ci. Sa pointe est calculée depuis
le centre finalement résolu vers le point projeté réel : elle conserve donc la
direction exacte de l’ami même si le cercle est décalé pour éviter une
collision.

La résolution commune distribue les indicateurs le long du périmètre avec 19,6
points entre leurs centres, soit environ 30 % de superposition pour les visuels
de 28 points. Elle conserve leur ordre directionnel et peut franchir un coin
lorsque le bord naturel est saturé. Les cibles tactiles restent à 48 points et
les badges d’événement participent au même calcul compact.

La retouche réapprouvée réduit la hauteur totale du triangle à 7,5 points,
dont 1,5 point reste sous l’avatar, et élargit très légèrement sa base de 10 à
11 points. Elle ne modifie ni son angle, ni sa couleur, ni la géométrie de
placement.

Le triangle vectoriel devient un composant partagé par les avatars et les
badges d’événement. Pour une sortie hors champ, il reprend la couleur de
l’organisateur, reste derrière le cercle de catégorie et reçoit le même angle
exact calculé après résolution des collisions.

La géométrie de bord devient générique et reçoit dans une seule passe les amis
et les événements afin que leurs collisions soient résolues ensemble. Le
marqueur d’événement devient une `MKAnnotationView` personnalisée, composée de
vues UIKit et du SF Symbol déjà porté par `OutingCategory`. Sa priorité
`.required` empêche MapKit de le masquer au dézoom. Le bouton hors champ reprend
le même badge dans une cible tactile de 48 points et réutilise le flux existant
de centrage et de sélection par `eventId`.

## Affected files

- `wander/MapWithFogView.swift` — observation de la caméra, visibilité des pins,
  cycle de vie des indicateurs et centrage au toucher.
- `wander/FriendOffscreenIndicatorView.swift` →
  `wander/MapOffscreenIndicatorView.swift` — géométrie générique, bouton
  d’avatar et bouton de catégorie d’événement.
- `docs/plans/2026-08-18-indicateurs-amis-hors-champ.md` — suivi du sprint et
  validation exacte.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md`
  — état de la fonctionnalité.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`
  — comportement visible, interaction et accessibilité.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md`
  — architecture générique des indicateurs et priorité des annotations.
- `docs/solutions/` — note uniquement si une leçon réutilisable émerge.
- `todos/` — findings de revue uniquement si un défaut reste ouvert.

## Implementation

- [x] Passer le plan à `in_progress` avant le premier changement de code.
- [x] Ajouter le composant d’indicateur et les calculs de placement.
- [x] Synchroniser les indicateurs avec les annotations et la caméra MapKit.
- [x] Réutiliser le centrage et la sélection au toucher.
- [x] Gérer positions anciennes, suppressions, rotation et chevauchements.
- [x] Ajouter les libellés VoiceOver et respecter Réduire les animations.
- [x] Mettre à jour les deux notes Obsidian concernées par le périmètre initial.
- [x] Compiler sans nouvel avertissement.
- [ ] Vérifier les scénarios accessibles sur l’iPhone 17 Simulator déjà démarré.
- [x] Simplifier puis effectuer la revue statique.
- [x] Conserver la position directionnelle et former uniquement des piles
  locales à 50 % de superposition lorsque des amis sont proches.
- [x] Réduire les avatars hors champ de 40 à 28 points tout en conservant leur
  cible tactile de 48 points, leur contact avec le bord et 50 % de
  superposition locale.
- [x] Généraliser la géométrie et le conteneur aux amis et aux événements.
- [x] Remplacer le marqueur générique par un badge natif propre à la catégorie.
- [x] Rendre toutes les annotations d’événement obligatoires pour MapKit.
- [x] Ajouter, mettre à jour et retirer les indicateurs d’événement hors champ.
- [x] Réutiliser le centrage, la sélection et l’ouverture de fiche au toucher.
- [x] Ajouter un premier chevron directionnel aux seuls avatars d’amis hors
  champ ; essai ensuite remplacé par le pointeur triangulaire approuvé.
- [x] Remplacer le badge à chevron par un triangle attaché à l’avatar et coloré
  comme le profil.
- [x] Pointer vers la position projetée exacte après résolution des collisions.
- [x] Supprimer la superposition visuelle et répartir les indicateurs autour du
  périmètre lorsque leur bord naturel est saturé ; essai ensuite remplacé par
  le regroupement compact réapprouvé.
- [x] Appliquer environ 30 % de superposition, soit 19,6 points entre les
  centres des visuels de 28 points.
- [x] Réduire le triangle à 7,5 points de hauteur et élargir sa base à 11
  points sans modifier sa direction.
- [x] Mutualiser le triangle vectoriel entre les indicateurs d’amis et
  d’événements.
- [x] Ajouter le triangle coloré aux badges d’événement hors champ et lui
  transmettre l’angle exact du placement.
- [x] Mettre à jour le plan de sprint avec le périmètre réapprouvé.
- [ ] Mettre à jour les trois notes Obsidian concernées ; leur vault est présent
  mais hors des racines d’écriture autorisées de cette session.
- [x] Compiler sans nouvel avertissement lié au changement puis effectuer la
  revue statique.

## Edge cases and risks

- Une projection MapKit peut devenir non finie à une coordonnée extrême —
  utiliser la direction géographique comme repli et ne jamais afficher une vue
  à une position invalide.
- Le cadre du pin peut toucher le bord alors que son centre est encore visible
  — tester le cadre complet afin d’éviter un indicateur prématuré ou un doublon.
- Plusieurs amis et événements peuvent partager presque la même direction — les
  espacer ensemble le long du bord en conservant leur ordre déterministe.
- Les contrôles et zones système peuvent masquer un indicateur — utiliser un
  rectangle intérieur avec marges et conserver les contrôles SwiftUI au-dessus.
- Des mises à jour à chaque image pourraient être coûteuses — garder les vues
  dans UIKit, réutiliser les boutons et ignorer les changements négligeables.
- Le rail droit peut recouvrir temporairement un indicateur — conserver le rail
  au-dessus sans modifier son geste ni bloquer le panoramique ailleurs.

## Validation

- [x] Le build Debug iOS Simulator réussit sans nouvel avertissement.
- [x] La géométrie initiale à 50 % de superposition a été validée statiquement,
  puis remplacée par la résolution sans chevauchement réapprouvée.
- [x] Le triangle reste dans la cible de 48 points, est attaché au cercle et sa
  pointe vise le point projeté exact sur les quatre bords et les diagonales.
- [x] Le triangle raccourci conserve une base de 11 points, une attache de 1,5
  point sous l’avatar et le même angle exact.
- [x] Chaque badge d’événement hors champ possède le même triangle compact,
  coloré comme l’organisateur et orienté vers la position projetée exacte.
- [ ] Un ami visible n’a aucun indicateur et un ami hors champ n’a aucun pin
  visible en doublon.
- [ ] Haut, bas, gauche, droite et diagonales correspondent au cadrage courant.
- [ ] Panoramique, zoom et rotation déplacent les indicateurs sans saut notable.
- [ ] Plusieurs amis proches restent distincts et touchables.
- [ ] Le toucher recentre et sélectionne l’ami attendu.
- [ ] Une position ancienne conserve une présentation atténuée.
- [ ] Suppression de position ou révocation retire immédiatement l’indicateur.
- [ ] Les contrôles, la fiche de sortie et le rail d’amis restent utilisables.
- [ ] VoiceOver, clair/sombre et Réduire les animations restent utilisables.
- [x] Les propriétés, wikiliens, tableaux et callouts des notes Obsidian restent
  valides et leur rendu est vérifié en mode Lecture.
- [x] La revue ne laisse aucun défaut P1/P2 non consigné.
- [x] Le nouveau build Debug iOS Simulator réussit sans nouvel avertissement
  lié au changement.
- [ ] Chaque événement visible conserve son badge à tous les niveaux de zoom.
- [ ] Un événement hors champ reçoit un indicateur de bord sans doublon avec
  son annotation normale.
- [x] Les placements mixtes amis/événements sont déterministes et ne se
  recouvrent pas entièrement.
- [x] La résolution sans chevauchement a été validée statiquement puis
  remplacée par le regroupement compact réapprouvé.
- [x] Les avatars et badges proches se superposent à environ 30 % avec 19,6
  points entre leurs centres, tout en conservant leur ordre sur le périmètre.
- [x] Le toucher d’un indicateur d’événement réutilise le bon `eventId`.
- [x] La revue statique du nouveau périmètre ne laisse aucun défaut P1/P2 non
  consigné.
- Validation visuelle et interactive : déléguée au propriétaire du projet.

## Acceptance criteria

- Un ami hors champ est représenté par son avatar sur le bord indiquant sa
  direction selon la caméra courante.
- Le pin et l’indicateur ne sont jamais affichés simultanément.
- L’indicateur reste à l’intérieur de la zone utilisable et tous les amis
  restent identifiables en cas de directions proches.
- Un toucher centre et sélectionne le bon ami.
- Les positions anciennes restent distinguables et les positions supprimées ne
  laissent aucune vue résiduelle.
- Les interactions cartographiques et sociales existantes continuent de
  fonctionner.
- Un événement reste affiché dans le cadrage, même au dézoom, sous la forme
  d’un badge de catégorie distinct d’un avatar.
- Un événement hors cadrage est représenté sur le bord selon sa direction et
  son toucher ouvre la bonne fiche après recentrage.
- Amis et événements partagent une résolution de chevauchements unique.

## Review notes

- Hardest decision: conserver les mises à jour de caméra et les boutons dans la
  couche UIKit de MapKit afin d’éviter de republier un état SwiftUI à chaque
  image, tout en laissant passer les gestes de carte hors des avatars.
- Rejected alternatives: étendre le rail existant, qui n’exprime pas la
  direction du cadrage ; forcer un zoom englobant tous les amis, qui retirerait
  le contrôle de la caméra ; republier toutes les projections dans
  `ContentView`, qui ferait reconstruire davantage de vue pendant le pan.
- Least certain: rendu, coexistence avec les contrôles superposés et densité
  avec de nombreux amis sur un petit écran, à confirmer sur l’iPhone 17
  Simulator.
- Static review: le seuil de prise de relais a été corrigé pour attendre que le
  cadre complet de 88 points du pin soit sorti avant d’afficher l’indicateur.
  Après validation utilisateur, l’action du contrôle personnalisé a aussi été
  déplacée de `primaryActionTriggered` vers `touchUpInside`, avec une activation
  VoiceOver explicite, afin que le toucher centre réellement l’ami. La marge
  extérieure a ensuite été ramenée de 8 à 0 point pour rapprocher les avatars
  du bord sans sortir leur zone tactile de la zone sûre. Après réapprobation,
  un premier essai d’écart visuel normal à 4 points a été rejeté parce qu’il
  conservait une présentation en liste. Après une nouvelle réapprobation, les
  amis conservent leur point directionnel et seuls ceux qui sont proches sont
  décalés localement de 20 points, soit 50 % de superposition. Les marges de
  coin sont réduites avant de déplacer une pile hors de la zone utile. Après
  réapprobation de la taille, le visuel passe de 40 à 28 points sans réduire la
  cible tactile de 48 points ; il est aligné contre son bord et l'écart local
  passe à 14 points pour conserver 50 % de superposition. Aucun défaut P1/P2
  statique ne reste ouvert et aucun fichier `todos/` n’a été créé.
- Exact build, relancé après la réduction des indicateurs : `xcodebuild -quiet
  -project wander.xcodeproj -scheme wander
  -configuration Debug -destination 'generic/platform=iOS Simulator'
  -derivedDataPath /tmp/wander-derived-data
  -disableAutomaticPackageResolution build` réussit le 2026-08-18.
- Simulator limitation: `xcrun simctl list devices` ne retourne aucun appareil
  démarré ; l’iPhone 17 iOS 26.3 disponible est `Shutdown`. Conformément aux
  règles du dépôt, il n’a pas été démarré sans autorisation explicite.
- Obsidian validation: `Backlog features.md` et `Documentation UX.md` affichent
  leur nouveau frontmatter et leur contenu en mode Lecture ; le passage mis à
  jour sur les 28 points visuels et 48 points tactiles est rendu correctement,
  tout comme les wikiliens, le callout du backlog et le tableau UX.
- Event extension implementation: `OutingPlanAnnotationView` est désormais une
  annotation UIKit personnalisée de priorité `.required`, alimentée par la
  catégorie et la couleur déjà présentes. Les amis et événements hors champ
  passent par une liste commune de candidats et une seule résolution de
  collisions ; chaque bouton d’événement conserve son `eventId` pour recentrer
  et sélectionner l’annotation correspondante.
- Event extension build: `xcodebuild -quiet -project wander.xcodeproj -scheme
  wander -configuration Debug -destination 'generic/platform=iOS Simulator'
  -derivedDataPath /tmp/wander-derived-data
  -disableAutomaticPackageResolution build` réussit le 2026-08-18 après la
  simplification finale. Un build complet a également signalé l’avertissement
  préexistant de versions différentes entre l’app (`16`) et l’extension (`15`),
  sans rapport avec ce changement.
- Manual validation: conformément à la demande du propriétaire, aucune
  vérification interactive ou visuelle n’a été effectuée. Les critères de
  cadrage, toucher et rendu restent à confirmer manuellement avant de passer le
  plan à `completed`.
- Obsidian limitation: le vault est lisible mais hors des racines d’écriture de
  cette session. Restent à mettre à jour `Backlog features.md` (étendre l’item
  hors champ aux événements), `Documentation UX.md` (badge de catégorie,
  priorité visuelle, interaction de bord, regroupement à 30 % de
  superposition et triangle compact de 7,5 × 11 points visant la position
  exacte depuis les avatars et badges d’événement)
  et `Documentation technique.md`
  (conteneur générique, priorité `.required` et résolution mixte), avec leur
  propriété `updated`, puis à vérifier en mode Lecture.
  Les sections exactes sont l’item **Afficher les amis hors champ sur le bord
  de la carte** du backlog, le paragraphe d’indicateurs sous la carte dans
  `Documentation UX.md` et la section **Carte** de
  `Documentation technique.md`.
- First direction-arrow implementation: chaque avatar d’ami hors champ conserve son
  cercle de 28 points collé au bord. Un badge système de 16 points, placé sur
  son côté intérieur dans la même cible de 48 points, affiche le chevron du
  bord courant. L’alpha reste porté par le contrôle parent, donc avatar et
  chevron s’atténuent ensemble pour une position ancienne. Les indicateurs
  d’événement ne changent pas.
- Direction arrow review: les quatre couples de cadres sont contenus dans
  `48 × 48` (`top`: avatar `10,0,28,28`, chevron `16,28,16,16`; `right`:
  avatar `20,10,28,28`, chevron `4,16,16,16`; valeurs symétriques pour
  `bottom` et `left`). Aucun défaut P1/P2 statique n’a été relevé.
- Direction arrow build: la commande `xcodebuild -quiet -project
  wander.xcodeproj -scheme wander -configuration Debug -destination
  'generic/platform=iOS Simulator' -derivedDataPath /tmp/wander-derived-data
  -disableAutomaticPackageResolution build` réussit le 2026-08-18. Le seul
  avertissement concerne la divergence préexistante de `CFBundleVersion` entre
  l’extension (`15`) et l’app (`16`). Tous les simulateurs iOS 26.3, dont
  l’iPhone 17, sont arrêtés ; aucune validation visuelle n’a donc été lancée.
- Exact-pointer implementation: le badge rond et le SF Symbol sont supprimés.
  Un `CAShapeLayer` dessine maintenant derrière l’avatar un triangle plein de
  la couleur du profil. Sa base entre sous le cercle de 28 points et sa pointe
  est alignée sur le vecteur qui relie le centre finalement résolu au point
  MapKit projeté de l’ami ; un déplacement anticollision ne dégrade donc plus
  l’information directionnelle.
- Non-overlap implementation: amis et événements sont ordonnés sur un
  périmètre continu. La résolution préserve cet ordre, peut franchir un coin et
  emploie un écart renforcé aux coins pour garantir au moins 32 points entre
  les centres dans la capacité normale du périmètre. Les visuels de 28 points
  sont centrés dans leurs cibles tactiles inchangées de 48 points.
- Initial exact-pointer review: la pointe est contenue dans les `48 × 48` et
  atteignait le
  bord du contrôle dans l’angle exact ; la base recouvre légèrement le disque
  mais reste derrière l’avatar, ce qui forme un seul composant visuel. Les
  changements de chemin désactivent les animations implicites pour suivre la
  caméra sans retard. Aucun défaut P1/P2 statique n’a été relevé.
- Exact-pointer build: `xcodebuild -quiet -project wander.xcodeproj -scheme
  wander -configuration Debug -destination 'generic/platform=iOS Simulator'
  -derivedDataPath /tmp/wander-derived-data
  -disableAutomaticPackageResolution build` réussit le 2026-08-18 sans nouvel
  avertissement.
- Pointer-geometry refinement: après réapprobation, la hauteur du triangle
  passe à 7,5 points, soit 6 points visibles au-delà du cercle, et sa base
  passe de 10 à 11 points. L’angle, la couleur, l’attache sous l’avatar et la
  cible tactile de 48 points restent inchangés. La revue statique ne relève
  aucun défaut P1/P2.
- Pointer-geometry build: la même commande `xcodebuild` réussit le 2026-08-18
  sans nouvel avertissement.
- Compact-overlap refinement: après réapprobation, la séparation commune passe
  à `28 × (1 - 0,30) = 19,6` points. Les avatars et badges proches se
  superposent donc d’environ 8,4 points, conservent leur ordre sur le périmètre
  et gardent leurs cibles tactiles de 48 points. Le triangle et son angle exact
  ne changent pas. Aucun défaut P1/P2 statique n’a été relevé.
- Compact-overlap build: la commande `xcodebuild` de validation réussit le
  2026-08-18 sans nouvel avertissement.
- Event-pointer implementation: le dessin du triangle est centralisé dans
  `MapOffscreenDirectionPointerLayer` et réutilisé par les deux contrôles hors
  champ. Le badge d’événement place cette couche derrière son cercle, la colore
  avec la couleur de l’organisateur et reçoit le `pointerAngle` du placement
  résolu avant de conserver son flux existant de centrage et d’ouverture.
- Event-pointer review: les dimensions `7,5 × 11`, l’absence d’animation
  implicite, la cible tactile de 48 points, le regroupement à 30 % et les
  libellés VoiceOver restent identiques. Aucun défaut P1/P2 statique n’a été
  relevé.
- Event-pointer build: la commande `xcodebuild` de validation réussit le
  2026-08-18 sans nouvel avertissement.

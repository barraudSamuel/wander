---
title: "Indicateurs d’amis hors champ sur la carte"
status: in_progress
date: 2026-08-18
approved_at: 2026-08-18
started_at: 2026-08-18
spacing_reapproved_at: 2026-08-18
local_overlap_reapproved_at: 2026-08-18
size_reapproved_at: 2026-08-18
owner: "Samuel Barraud"
related:
  - "2026-08-15-rail-amis-carte.md"
tags: [plan, map, friends, interaction]
---

# Indicateurs d’amis hors champ sur la carte

## Outcome

Lorsqu’un ami possédant une dernière position utilisable sort du champ de la
carte, son avatar apparaît automatiquement sur le bord correspondant à sa
direction. L’indicateur suit le panoramique, le zoom et la rotation, puis
disparaît dès que le pin normal redevient visible. Un toucher recentre la carte
sur cet ami.

## Context

La carte affiche déjà les positions des amis sous forme de pins, conserve les
dernières positions connues et sait centrer un ami. Le rail social du bord
droit reste une interaction séparée : il permet de parcourir les amis, tandis
que les nouveaux indicateurs rendent immédiatement visibles les amis situés
hors du cadrage courant.

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
  - placement dans une zone sûre de la carte et résolution des chevauchements
    entre amis proches ;
  - mise à jour pendant le panoramique et le zoom ;
  - toucher pour centrer et sélectionner l’ami ;
  - libellé et indication VoiceOver ;
  - coexistence avec les pins, contrôles, fiches de sortie et rail d’amis.
- Not included:
  - distance ou adresse affichée en permanence ;
  - modification de Firebase, des règles Firestore ou du modèle d’amitié ;
  - changement du rail d’amis existant ;
  - indicateurs pour les sorties ou la position de l’utilisateur ;
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

## Affected files

- `wander/MapWithFogView.swift` — observation de la caméra, visibilité des pins,
  cycle de vie des indicateurs et centrage au toucher.
- `wander/FriendOffscreenIndicatorView.swift` — bouton d’avatar, géométrie de
  bord et résolution des chevauchements.
- `docs/plans/2026-08-18-indicateurs-amis-hors-champ.md` — suivi du sprint et
  validation exacte.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md`
  — état de la fonctionnalité.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`
  — comportement visible, interaction et accessibilité.
- `docs/solutions/` — note uniquement si une leçon réutilisable émerge.
- `todos/` — findings de revue uniquement si un défaut reste ouvert.

## Implementation

- [x] Passer le plan à `in_progress` avant le premier changement de code.
- [x] Ajouter le composant d’indicateur et les calculs de placement.
- [x] Synchroniser les indicateurs avec les annotations et la caméra MapKit.
- [x] Réutiliser le centrage et la sélection au toucher.
- [x] Gérer positions anciennes, suppressions, rotation et chevauchements.
- [x] Ajouter les libellés VoiceOver et respecter Réduire les animations.
- [x] Mettre à jour les deux notes Obsidian concernées.
- [x] Compiler sans nouvel avertissement.
- [ ] Vérifier les scénarios accessibles sur l’iPhone 17 Simulator déjà démarré.
- [x] Simplifier puis effectuer la revue statique.
- [x] Conserver la position directionnelle et former uniquement des piles
  locales à 50 % de superposition lorsque des amis sont proches.
- [x] Réduire les avatars hors champ de 40 à 28 points tout en conservant leur
  cible tactile de 48 points, leur contact avec le bord et 50 % de
  superposition locale.

## Edge cases and risks

- Une projection MapKit peut devenir non finie à une coordonnée extrême —
  utiliser la direction géographique comme repli et ne jamais afficher une vue
  à une position invalide.
- Le cadre du pin peut toucher le bord alors que son centre est encore visible
  — tester le cadre complet afin d’éviter un indicateur prématuré ou un doublon.
- Plusieurs amis peuvent partager presque la même direction — les espacer le
  long du bord en conservant leur ordre déterministe.
- Les contrôles et zones système peuvent masquer un indicateur — utiliser un
  rectangle intérieur avec marges et conserver les contrôles SwiftUI au-dessus.
- Des mises à jour à chaque image pourraient être coûteuses — garder les vues
  dans UIKit, réutiliser les boutons et ignorer les changements négligeables.
- Le rail droit peut recouvrir temporairement un indicateur — conserver le rail
  au-dessus sans modifier son geste ni bloquer le panoramique ailleurs.

## Validation

- [x] Le build Debug iOS Simulator réussit sans nouvel avertissement.
- [x] La géométrie conserve 28 points visuels, 48 points tactiles, un contact
  avec chacun des quatre bords et 14 points d'écart pour 50 % de
  superposition locale.
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
- [ ] La revue ne laisse aucun défaut P1/P2 non consigné.

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

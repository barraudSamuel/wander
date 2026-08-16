---
title: "Rail d’amis depuis le bord de la carte"
status: in_progress
date: 2026-08-15
approved_at: 2026-08-15
reapproved_at: 2026-08-15
gesture_position_reapproved_at: 2026-08-15
fixed_geometry_reapproved_at: 2026-08-15
scroll_sync_reapproved_at: 2026-08-15
gesture_tuning_reapproved_at: 2026-08-16
smooth_motion_reapproved_at: 2026-08-16
adaptive_height_reapproved_at: 2026-08-16
scroll_endpoints_reapproved_at: 2026-08-16
scroll_focus_reapproved_at: 2026-08-16
tap_to_focus_reapproved_at: 2026-08-16
focus_haptic_reapproved_at: 2026-08-16
scroll_regression_fix_reapproved_at: 2026-08-16
nearest_default_focus_reapproved_at: 2026-08-16
cold_launch_focus_reapproved_at: 2026-08-16
nearest_focus_rollback_reapproved_at: 2026-08-16
centered_snap_reapproved_at: 2026-08-16
name_blur_reapproved_at: 2026-08-16
permissive_close_reapproved_at: 2026-08-16
liquid_glass_name_reapproved_at: 2026-08-16
untinted_liquid_glass_reapproved_at: 2026-08-17
owner: "Samuel Barraud"
related: []
tags: [plan, map, friends, interaction]
---

# Rail d’amis depuis le bord de la carte

## Outcome

Depuis l’onglet Explorer, un glissement volontaire vers la gauche démarré au
bord droit révèle une rail noire compacte contenant les avatars des amis. La
rail mesure 70 points de large, oppose une résistance initiale,
s’accroche après un seuil explicite avec un retour haptique et affiche le nom
de l’ami sélectionné juste à sa gauche. Sa hauteur s’adapte entre 150 et 260 points. Son centre vertical suit le doigt
pendant le drag et se verrouille à la position d’accrochage.

## Context

La carte reçoit déjà les amis acceptés, leurs avatars et l’action permettant
de les centrer. La nouvelle interaction doit réutiliser ces données sans
modifier Firebase, le modèle d’amitié ou l’onglet Amis existant. La référence
visuelle est la vidéo fournie par le propriétaire le 15 août 2026.

## Scope

- Included:
  - Rail noire de 70 points de large et d’une hauteur comprise entre 150 et 260 points.
  - Centre placé exactement sur la position verticale du drag mesurée dans la
    fenêtre.
  - Carte plein écran, mais commandes maintenues au-dessus de la barre
    d’onglets et hors des zones système.
  - Avatars empilés et défilables, ami sélectionné mis en avant.
  - Focus aimanté au centre pendant le scroll, sans déplacer la carte.
  - Nom de l’ami sélectionné affiché à gauche de la rail.
  - Avatars masqués par le contour noir pendant le scroll.
  - Pseudo synchronisé verticalement avec l’avatar sélectionné.
  - Geste démarrant exclusivement au bord droit.
  - Résistance initiale, seuil d’accrochage et haptique unique à l’ouverture.
  - Glissement inverse pour fermer la rail.
  - Centrage sur la carte lorsque l’ami sélectionné possède des données carte.
  - Liste vide, noms longs, Dynamic Type, VoiceOver et Réduire les animations.
- Not included:
  - Modification de Firebase, des règles Firestore ou des modèles d’amitié.
  - Suppression ou refonte de l’onglet Amis.
  - Nouveaux avatars ou nouvelles données de profil.
  - Déploiement ou publication TestFlight.

## Dependencies

- `FriendSyncService.acceptedFriends` et les résumés déjà produits par
  `ContentView`.
- `ProfileAvatarView` et `FriendAvatarBadge` pour les avatars embarqués.
- `showFriendOnMap(_:)` pour la sélection cartographique existante.
- `UIScreenEdgePanGestureRecognizer` pour isoler le geste du panoramique
  MapKit.

## Proposed approach

Conserver le contenu de l’onglet Explorer dans son environnement normal afin
que ses commandes continuent de recevoir les safe areas de la barre d’état et
de la barre d’onglets. Superposer séparément une couche visuelle plein écran
qui ignore les safe areas uniquement pour dessiner et reconnaître le geste de
la rail. Cette couche ne déplace pas globalement la carte.

Un adaptateur UIKit expose un geste système strictement attaché au bord droit. Sa
translation est convertie en progression avec une résistance avant le seuil.
La rail suit cette progression, puis s’ancre ouverte ou fermée selon le seuil
et la vélocité. Le générateur haptique est préparé au début du geste et émet un
impact ferme une seule fois quand l’ouverture s’accroche.

Le geste transmet aussi la coordonnée verticale courante du doigt dans le
repère de la fenêtre, identique à celui de la couche plein écran. La rail
entière — fond, avatars et nom — la suit pendant l’ouverture, puis conserve la
dernière position au moment de l’accrochage. La couche reçoit un cadre plein
écran explicite et la forme est alignée sur son bord droit afin de supprimer
tout espace résiduel.

Le `ScrollView` des avatars utilise la forme noire comme masque, et la position
de l’avatar sélectionné est mesurée dans le repère du viewport. Le pseudo
réutilise cette coordonnée afin de suivre exactement l’avatar et de disparaître
avec lui lorsqu’il quitte la hauteur visible de la rail.

Une forme SwiftUI compacte, centrée et limitée à 30 % de la hauteur crée le
contour souple visible dans la référence sans élargir la zone de contrôle. Les
avatars restent dans la rail et le nom
de l’élément actif est rendu sur la carte, à gauche. Sélectionner un ami
réutilise le centrage existant lorsque possible, sans inventer un nouvel état
de données.

## Affected files

- `wander/ContentView.swift` — état, données, sélection et intégration sur la
  carte.
- `wander/FriendEdgeRailView.swift` — présentation compacte, contour, avatars
  et nom sélectionné.
- `wander/RightEdgePanGestureView.swift` — reconnaissance du geste de bord et
  transmission de sa progression.
- `docs/plans/2026-08-15-rail-amis-carte.md` — source de vérité et validation.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`
  — synthèse du comportement visuel du rail dans le vault Obsidian.
- `docs/solutions/` — note uniquement si une leçon réutilisable émerge.
- `todos/` — findings de revue uniquement si un défaut reste ouvert.

## Implementation

- [x] Passer le plan à `in_progress` avant le premier changement de code.
- [x] Exposer le résumé d’ami au composant de rail sans dupliquer les données.
- [x] Construire la rail sous 20 % avec avatars, sélection et état vide.
- [x] Ajouter le nom actif à gauche avec troncature et accessibilité.
- [x] Intégrer le geste de bord droit sans intercepter le panoramique MapKit.
- [x] Appliquer résistance, seuil, accrochage et haptique unique.
- [x] Fermer la rail par glissement inverse et réconcilier les amis supprimés.
- [x] Centrer les amis possédant des données carte.
- [x] Compiler sans nouvel avertissement.
- [x] Découpler la couche plein écran des commandes qui respectent les safe areas.
- [x] Limiter la rail à 30 % de la hauteur et la centrer verticalement.
- [x] Maintenir les commandes au-dessus de la barre d’onglets.
- [x] Recompiler et vérifier le diff après la révision approuvée.
- [x] Transmettre la coordonnée verticale depuis le geste de bord.
- [x] Faire suivre la rail complète pendant le tirage et verrouiller sa position.
- [x] Borner la rail pour la conserver intégralement dans l’écran.
- [x] Recompiler après la révision du positionnement.
- [x] Remplacer les dimensions relatives par 70 × 260 points.
- [x] Mesurer la coordonnée verticale directement dans la fenêtre.
- [x] Donner à la couche un cadre plein écran et coller la forme à droite.
- [x] Recompiler après la révision de géométrie fixe.
- [x] Supprimer les extrémités horizontales et lisser le contour de la rail.
- [x] Masquer le scroll des avatars avec `FriendRailShape`.
- [x] Mesurer la position de l’avatar sélectionné dans le viewport.
- [x] Déplacer et masquer le pseudo avec l’avatar sélectionné.
- [x] Recompiler après la synchronisation du scroll.
- [x] Centrer horizontalement la pile d’avatars dans les 70 points de la rail.
- [x] Assouplir le seuil, la zone morte, la vélocité et la résistance d’ouverture.
- [x] Recompiler et vérifier le diff après l’assouplissement du geste.
- [x] Rendre la progression pré-seuil continue et mieux amortir l’accrochage.
- [x] Animer brièvement le changement d’ami sélectionné.
- [x] Recompiler et vérifier le diff après la révision de fluidité.
- [x] Adapter la hauteur au contenu entre 150 et 260 points.
- [x] Animer les changements de hauteur sans désynchroniser le masque et le pseudo.
- [x] Recompiler et vérifier le diff après la hauteur adaptative.
- [x] Supprimer le recentrage automatique vers l’ami sélectionné.
- [x] Ajouter des marges de scroll protégeant les avatars d’extrémité.
- [x] Recompiler et vérifier le diff après la correction des extrémités.
- [x] Séparer le focus du rail de l’action de centrage sur la carte.
- [x] Aimanter chaque avatar au centre et synchroniser le pseudo au scroll.
- [x] Exiger un tap sur l’avatar déjà focusé pour déplacer la carte.
- [x] Recompiler et vérifier le diff après l’ajout du focus central.
- [x] Forcer le centrage animé après un tap sur un avatar non focusé.
- [x] Recompiler et vérifier le diff après le centrage explicite au tap.
- [x] Ajouter un haptique léger à chaque changement réel d’ami focusé.
- [x] Recompiler et vérifier le diff après l’ajout du haptique de focus.
- [x] Séparer l’état observé du scroll de l’état visuel de focus.
- [x] Supprimer la boucle pouvant rappeler l’ancien avatar vers le centre.
- [x] Recompiler et vérifier le diff après la correction de régression.
- [x] Retirer le calcul et le focus automatique de l’ami le plus proche.
- [x] Restaurer la liaison de scroll séparée qui précédait cette expérimentation.
- [x] Ne focusser aucun ami avant un scroll ou un tap réel.
- [x] Recompiler et vérifier le diff après le retour arrière complet.
- [x] Aligner le snap de fin de geste sur l’ancre centrale du rail.
- [x] Recompiler et vérifier le diff après la correction du snap.
- [x] Remplacer le halo flouté par un Liquid Glass natif sans teinte.
- [x] Recompiler et vérifier le diff après l’adoption de Liquid Glass.
- [x] Mettre à jour `Documentation UX.md` et vérifier son rendu Obsidian.
- [x] Étendre de 32 points la zone tactile de fermeture à gauche de la rail.
- [x] Assouplir le verrou directionnel et les seuils de fermeture.
- [x] Recompiler et vérifier le diff après la révision de fermeture.
- [ ] Vérifier le rendu et les gestes sur l’iPhone 17 Simulator déjà démarré.
- [ ] Simplifier puis effectuer la revue finale.

## Edge cases and risks

- Le geste pourrait concurrencer MapKit — limiter la reconnaissance au bord
  système droit et ne poser aucune couche tactile sur le reste de la carte.
- La rail fixe pourrait être partiellement hors écran lors d’un geste très
  proche d’un coin — conserver le doigt comme centre, conformément au
  comportement demandé, et laisser la couche plein écran découper le surplus.
- Une liste longue pourrait dépasser verticalement — utiliser un défilement
  natif et conserver la sélection visible.
- Ignorer les safe areas au niveau du conteneur entier déplacerait les
  commandes sous la barre d’onglets — limiter ce comportement à la couche de
  rail plein écran.
- Un ami supprimé pourrait rester sélectionné — réconcilier la sélection dès
  que la liste change.
- Le haptique pourrait se répéter en oscillant autour du seuil — verrouiller
  l’émission à une fois par geste.
- Le simulateur ne reproduit pas la sensation haptique — vérifier l’appel et
  réserver la validation tactile finale à un iPhone physique.

## Validation

- [x] `xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/wander-derived-data -disableAutomaticPackageResolution build` réussit sans nouvel avertissement.
- [ ] Le geste ne démarre qu’au bord droit et la carte reste panoramique ailleurs.
- [ ] Un tirage sous le seuil revient fermé ; un tirage suffisant s’accroche.
- [ ] L’haptique d’ouverture n’est demandé qu’une fois par geste.
- [ ] La rail reste sous 20 % et affiche correctement zéro, un ou plusieurs amis.
- [ ] La sélection, le nom, le centrage et la fermeture fonctionnent.
- [ ] Dynamic Type, VoiceOver et Réduire les animations restent utilisables.
- [x] `git diff --check` réussit.
- [x] `Documentation UX.md` conserve un frontmatter valide, ses wikilinks,
  tableaux et callouts, et s’affiche correctement en mode Aperçu dans Obsidian.
- [ ] La revue ne laisse aucun défaut P1/P2 non consigné.

## Acceptance criteria

- La rail mesure exactement 70 points de large et entre 150 et 260 points de haut.
- La rail se centre exactement autour du drag mesuré dans la fenêtre.
- Son centre correspond à la position verticale du doigt au moment de
  l’accrochage.
- La carte remplit l’écran tandis que les commandes restent au-dessus de la
  barre d’onglets.
- Elle exige un geste intentionnel avec résistance avant de s’ouvrir.
- La fermeture peut commencer légèrement à gauche de la rail et tolère un
  mouvement diagonal modéré sans gêner son scroll vertical.
- Le franchissement du seuil produit un unique retour haptique ferme.
- Les avatars acceptés sont affichés et défilables dans la rail noire.
- Aucun avatar ne peut dépasser du contour noir pendant le scroll.
- Le nom de l’ami sélectionné apparaît à gauche comme dans la référence.
- Un Liquid Glass natif sans teinte porte le pseudo sans former une carte
  opaque sur la carte.
- Le pseudo reste aligné verticalement avec son avatar pendant le scroll.
- L’avatar focusé s’aimante au centre sans modifier la position de la carte.
- Seul un tap explicite sur l’avatar déjà focusé centre la carte.
- La sélection centre l’ami sur la carte quand ses données le permettent.
- MapKit et l’onglet Amis existant continuent de fonctionner.

## Review notes

- Hardest decision: à compléter pendant la revue.
- Rejected alternatives: à compléter pendant la revue.
- Least certain: sensation haptique réelle, non testable dans le simulateur.

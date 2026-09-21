---
id: "060"
title: "Vérifier le rendu et les gestes des profils en bottom sheet"
status: ready
priority: P2
source: review
created: 2026-09-21
tags: [todo, ios, friends]
---

# Vérifier le rendu et les gestes des profils en bottom sheet

## Constat

La nouvelle feuille native est implémentée et compilée. Samuel a explicitement
limité la validation à la compilation. Aucun test n’a été exécuté et aucun
simulateur n’a été démarré. La hauteur mesurée, les gestes natifs et les transitions
ne sont donc pas confirmés en exécution par Codex.

La vidéo fournie par Samuel révèle un défaut P2 : l’ouverture centre d’abord la
carte puis la décale. Après un repli au centrage simple, Samuel approuve la mesure
anticipée : hauteur native préparée avant affichage et un seul mouvement vers le
pin au-dessus de la feuille. Les anciens centrages ami sont désormais délégués à
ce chemin unique. La correction visuelle reste à confirmer.

Samuel juge ensuite le cadrage satisfaisant, puis fournit une seconde vidéo
montrant la fermeture par la croix suivie du recentrage. Le correctif approuvé
lance ces deux actions ensemble et consomme le profil présenté pour éviter
un second mouvement dans `onDismiss`. Son timing reste à vérifier sur appareil.

La vidéo de 12:30 montre aussi la croix qui réagit sans fermer. Samuel précise
que les clics centrés fonctionnent et que les clics latéraux sont ignorés.
Le premier essai, un label à 44 × 44 points, a été invalidé par Samuel : le bouton
est devenu trop grand sans supprimer la zone inactive. La révision approuvée
utilise `Button(role: .close)` sans cadre imposé au label et applique la forme
interactive circulaire au bouton complet, avant la marge extérieure. Le style
Liquid Glass et la taille native `.regular` sont conservés. Le test adapté clique
une seule fois à 50 %, 10 % et 90 % de la largeur réelle, à mi-hauteur, avec une
réouverture entre chaque cas. La compilation seule ne permet pas de conclure
que la zone inactive a disparu ni de confirmer le rendu revenu à sa taille native.
La compilation finale de cette révision est réussie dans
`/tmp/wander-native-close-final-build.log`. Le libellé système est explicitement
limité à l’icône seule. La revue manuelle ciblée ne relève aucun défaut confirmé,
mais aucun résultat de clic réel n’a été observé par Codex sur cette version.

### P2 — Restauration des événements à coordonner

La revue du correctif de croix a identifié un cas non résolu : si Événements était
déployé, son retour anime le viewport et annule le recentrage immédiat via
`MapWithFogView.onViewportChange`. L’identifiant consommé interdit tout redémarrage.
Le correctif simple compile mais n’est pas terminé pour ce parcours. L’extension
de coordination avec la géométrie finale est proposée dans le plan de fermeture
et attend approbation. Aucun résultat visuel corrigé n’est revendiqué.

## Références

- `docs/plans/2026-09-21-profils-amis-bottom-sheet.md`.
- `docs/plans/2026-09-21-cadrage-ami-bottom-sheet.md`.
- `docs/plans/2026-09-21-supprimer-double-cadrage-ami.md`.
- `docs/plans/2026-09-21-cadrage-ami-mesure-anticipee.md` : comportement actuel.
- `docs/plans/2026-09-21-recentrage-fermeture-croix-ami.md` : croix sans attente.
- `docs/plans/2026-09-21-zone-tactile-croix-profil-ami.md` : clics décentrés sur la croix.
- `wander/MapFriendCameraController.swift` : recentrage de fermeture de 0,22 seconde.
- `wander/FriendProfileSheet.swift` : contenu et hauteur compacte.
- `wander/ContentView.swift` : sélection, ouverture et fermeture avant Itinéraire.
- `wander/DebugSocialMapScenario.swift` : données locales pour les différents états.
- Tests existants adaptés dans `wanderUITests/MapSocialGestureUITests.swift` et
  `wanderUITests/MotionDockUITests.swift`, compilés sans exécution.

## Critères de clôture, lors d’une validation autorisée

- [ ] Vérifier à la taille de texte standard le nom, l’avatar, les deux informations
  de position et le bouton Itinéraire visible au palier compact.
- [ ] Vérifier l’ouverture depuis un pin et la liste Amis, le changement d’ami,
  l’agrandissement natif, la croix et la fermeture par glissement.
- [ ] Vérifier la fermeture par un seul clic au centre et sur chaque côté de la
  croix, ainsi que la cohérence entre la surface réactive et le cercle Liquid Glass.
- [ ] Confirmer que la carte ne se découpe plus pour un ami et que sa portion
  exposée reste interactive au palier compact.
- [ ] Vérifier une seule trajectoire vers le pin entièrement visible au-dessus
  de la feuille, depuis la liste, un pin, un groupe et un indicateur hors champ.
  Aucun mouvement préalable au milieu de l’écran ou après fin d’ouverture.
- [ ] Vérifier que le palier initial correspond au contenu dès la première image,
  y compris avec un nom long, une position ancienne ou une position indisponible.
- [ ] Vérifier qu’agrandir ou réduire la feuille ne déplace pas la caméra.
- [ ] Avec la croix, vérifier que le recentrage commence pendant la fermeture,
  sans second mouvement à sa fin, avec le même zoom, y compris quand la liste
  d’événements revient. Répéter après agrandissement de la fiche.
- [ ] Par glissement, vérifier le recentrage après disparition complète et
  l’absence de mouvement lors d’un glissement annulé qui garde la fiche ouverte.
- [ ] Vérifier la priorité d’un geste ou d’une nouvelle sélection et l’absence
  de recentrage vers une position devenue indisponible.
- [ ] Vérifier position ancienne, mode fantôme et position indisponible.
- [ ] Confirmer la fermeture avant le choix d’application et la revalidation de
  l’amitié et de la destination, puis la restauration de la liste d’événements.
- [ ] Exécuter les tests UI pertinents sans démarrer ni créer d’autre appareil que
  celui explicitement autorisé et consigner les résultats.

Les avertissements préexistants de versions des extensions restent suivis dans
`054-ready-p2-aligner-build-extensions.md`.

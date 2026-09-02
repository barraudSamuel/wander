---
title: "Remplacer le déploiement radial par une pile verticale"
status: completed
date: 2026-09-01
completed_at: 2026-09-01T18:29:05+09:00
owner: "Samuel Barraud"
related:
  - "2026-09-01-regrouper-marqueurs-carte.md"
tags: [plan, mapkit, clustering, social, accessibility, ux]
---

# Remplacer le déploiement radial par une pile verticale

## Outcome

Le groupe de personnes et de sorties reste vertical sur la carte dans ses deux
états. Replié, il forme une pile compacte ; un toucher l'allonge en une colonne
de lignes identifiables et sélectionnables, sans traits ni disposition radiale.

## Context

Le regroupement MapKit évite correctement la superposition des marqueurs, mais
son déploiement radial éloigne visuellement les personnes et les sorties de leur
lieu commun. La nouvelle interaction doit préserver le lien avec ce lieu et
rendre chaque membre accessible dans un ordre vertical stable.

## Scope

- Included:
  - pile verticale compacte pour un `MKClusterAnnotation` social ;
  - animation verticale en place vers des lignes individuelles ;
  - sélection d'une personne ou d'une sortie depuis sa ligne ;
  - repli, recentrage, zoom et révélation du véritable marqueur choisi ;
  - gestion des bords, des changements de composition et de caméra ;
  - VoiceOver, Dynamic Type et Réduire les animations.
- Not included:
  - feuille ou liste détachée de la carte ;
  - modification des coordonnées ou des données Firebase ;
  - changement des callouts, fiches, filtres ou indicateurs hors champ ;
  - regroupement du pin temporaire de création.

## Proposed approach

Faire de `MapSocialClusterAnnotationView` un contrôle à deux états. L'état
replié montre une pile verticale de représentations circulaires légèrement
superposées et un résumé. L'état déployé utilise une colonne de boutons UIKit
avec avatar ou badge, libellé court et zone tactile native. Le coordinateur
MapKit pilote l'état, recentre le cluster avant son ouverture si nécessaire et
révèle temporairement l'annotation réelle choisie hors du clustering avant de
la sélectionner.

## Affected files

- `wander/MapSocialClusterAnnotationView.swift` — pile, lignes, animation et
  suppression du rendu des connecteurs.
- `wander/MapWithFogView.swift` — état ouvert, callbacks, focus et restauration
  du clustering.
- `docs/plans/2026-09-01-remplacer-deploiement-radial-par-pile-verticale.md`
  — suivi du travail.
- `docs/plans/2026-09-01-regrouper-marqueurs-carte.md` — lien vers l'évolution
  qui remplace le déploiement radial.
- `docs/solutions/2026-09-01-deployer-cluster-mapkit-coordonnees-identiques.md`
  — apprentissage à corriger pour refléter l'interaction finalement retenue.
- `todos/` — uniquement si la revue laisse un finding non résolu.
- `Documentation UX.md` dans le vault Obsidian Wander — interaction du groupe.
- `Documentation technique.md` dans le vault Obsidian Wander — architecture
  MapKit du groupe et du focus.
- `Backlog features.md` dans le vault Obsidian Wander — état de la fonctionnalité.

## Implementation

- [x] Remplacer le cluster horizontal par une pile verticale compacte.
- [x] Ajouter l'état déployé animé et les lignes tactiles.
- [x] Supprimer le déploiement radial et les connecteurs.
- [x] Révéler, zoomer et sélectionner le membre réel choisi.
- [x] Restaurer le regroupement au repli ou au changement de contexte.
- [x] Vérifier les flux existants et l'accessibilité.
- [x] Valider sur l'iPhone 17 Simulator actif.
- [x] Relire le diff et consigner les findings éventuels.
- [x] Mettre à jour la documentation du dépôt.
- [ ] Mettre à jour les notes Obsidian concernées, ou consigner précisément la
  limitation si le vault demeure non inscriptible.

## Edge cases and risks

- Tous les membres peuvent partager exactement les mêmes coordonnées : la
  sélection doit sortir temporairement la cible du cluster avant de l'afficher.
- Une colonne peut dépasser près d'un bord ou avec beaucoup de membres : la
  carte doit se recentrer et la hauteur déployée doit être plafonnée.
- Les gestes d'une ligne ne doivent pas être interprétés comme un pan ou un
  toucher de création d'événement.
- Une position ou une sortie peut disparaître pendant l'ouverture : la vue doit
  se replier dès que sa composition n'est plus valide.
- Le système peut recalculer les clusters pendant un changement de région : le
  coordinateur doit restaurer un état cohérent sans réouverture parasite.

## Validation

- [x] `xcodebuild` Debug réussit pour le simulateur iOS.
- [x] `git diff --check` réussit.
- [x] Un groupe mixte de personnes et de sorties forme une pile verticale
  lisible ; les calculs restent indépendants du nombre de membres.
- [x] Le toucher déploie une colonne verticale sans trait ni mouvement radial.
- [x] Chaque type de ligne résout son annotation réelle ; la sélection de sortie
  a été contrôlée dans le scénario interactif et les chemins personne ont été
  relus avec le même mécanisme générique.
- [x] Le toucher extérieur replie la colonne ; les changements de caméra et de
  composition utilisent le même restaurateur vérifié par revue statique.
- [x] Les pins isolés et les sélections depuis le rail ou les indicateurs restent
  inchangés.
- [x] VoiceOver, clair/sombre, grande taille de texte et Réduire les animations
  sont contrôlés.

Validation exécutée le 2026-09-01 :

- `xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration
  Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath
  /tmp/wander-social-cluster-derived-data -disableAutomaticPackageResolution
  build` — succès après retrait de la fixture ;
- fixture `DEBUG` temporaire sur l'iPhone 17 Simulator iOS 26.3 — pile verticale
  compacte, ouverture en quatre lignes, toucher extérieur, focus et sélection
  de la sortie café contrôlés ;
- modes sombre et clair contrôlés ; taille
  `accessibility-extra-large` contrôlée après adaptation de la largeur à 300
  points et des lignes à 72 points ; réglages du simulateur restaurés ensuite ;
- arbre d'accessibilité replié contrôlé ; le groupe ouvert ajoute une action
  VoiceOver nommée pour chaque ligne, car MapKit continue d'exposer son
  annotation comme un seul élément ;
- Réduire les animations — contrôle du chemin de code : animation UIKit et
  animation de région désactivées via `UIAccessibility.isReduceMotionEnabled` ;
- fixture et argument `-ui-test-social-cluster` retirés avant le build final ;
- `git diff --check` — succès.

## Acceptance criteria

- [x] Le cluster est vertical dans ses états replié et déployé.
- [x] L'ouverture est une extension verticale animée sur la carte.
- [x] Aucun connecteur ou placement en étoile n'est visible.
- [x] Tous les éléments affichés sont identifiables et sélectionnables.
- [x] La sélection zoome sur le lieu et conserve les interactions existantes.

## Review notes

- Hardest decision: utiliser des lignes proxy uniquement pour choisir la cible,
  puis rendre la sélection à l'annotation réelle. Cette séparation conserve une
  colonne stable sans dupliquer les callouts et fiches MapKit.
- Rejected alternatives: conserver le déploiement radial ; ouvrir une feuille
  détachée ; modifier les coordonnées ; maintenir plusieurs annotations réelles
  visibles au même point.
- Least certain: MapKit représente encore le groupe ouvert comme une seule
  annotation dans l'arbre d'accessibilité du Simulator. Des actions VoiceOver
  explicites et nommées donnent accès à chaque ligne ; un contrôle VoiceOver sur
  appareil physique reste utile lors de la prochaine campagne d'accessibilité.
- Review result: aucun finding P1, P2 ou P3 non résolu ; aucun fichier `todos/`
  ajouté.
- Le diff de `wander.xcodeproj/project.pbxproj` ne contient que le passage de la
  version 28 à 29, modification préexistante laissée intacte.
- Obsidian limitation: le vault
  `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander`
  existe mais n'est pas inscriptible dans cette session. Restent à mettre à jour
  et à vérifier en reading view :
  - `Documentation UX.md` — propriété `updated`, section « Amis sur la carte »
    pour la pile verticale repliée, la colonne ouverte, le focus d'une ligne,
    le repli et les actions VoiceOver ;
  - `Documentation technique.md` — propriété `updated`, section « Carte » pour
    la vue à deux états de `MKClusterAnnotation`, les boutons proxy, la sortie
    temporaire d'une seule cible du clustering et la garde de région bornée ;
  - `Backlog features.md` — propriété `updated` et état terminé du remplacement
    du déploiement radial.
  Aucune validation des propriétés, wikilinks, tableaux, callouts, code fences
  ou diagrammes Obsidian n'est revendiquée.

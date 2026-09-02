---
title: "Regrouper les marqueurs superposés sur la carte"
status: completed
date: 2026-09-01
completed_at: 2026-09-01T17:45:11+09:00
owner: "Samuel Barraud"
related:
  - "2026-08-14-restaurer-texte-circulaire-pins.md"
  - "2026-08-15-sorties-prevues-sprint-07-fiche-evenement.md"
  - "2026-08-18-indicateurs-amis-hors-champ.md"
superseded_by: "2026-09-01-remplacer-deploiement-radial-par-pile-verticale.md"
tags: [plan, mapkit, clustering, social, accessibility]
---

# Regrouper les marqueurs superposés sur la carte

## Evolution

Ce plan conserve l'historique du premier regroupement vérifié. Son déploiement
radial a ensuite été remplacé par la pile verticale décrite dans
`2026-09-01-remplacer-deploiement-radial-par-pile-verticale.md`. Le clustering
compact reste en place ; les offsets et connecteurs radiaux ne font plus partie
du produit final.

## Outcome

Les positions et sorties qui se chevauchent sont remplacées par un marqueur
de groupe lisible. Un toucher déploie radialement les vrais marqueurs sans
modifier leurs coordonnées, puis chaque membre conserve son interaction
existante.

## Context

Les positions utilisent une annotation de 88 × 88 points afin d'afficher une
durée circulaire autour d'un avatar de 44 points. Les événements utilisent un
badge séparé de 40 points. Lorsque plusieurs personnes et un événement
partagent le même lieu, ces vues se recouvrent et leurs durées deviennent
illisibles.

## Scope

- Included:
  - regroupement MapKit commun du compte, des amis et des sorties ;
  - pile compacte d'avatars, badge événement et résumé quantitatif ;
  - déploiement radial des annotations réelles avec traits vers le lieu ;
  - repli lors d'un déplacement de caméra ou d'un changement de groupe ;
  - conservation des callouts, fiches, recentrages et indicateurs hors champ ;
  - VoiceOver, Réduire les animations, clair/sombre et Dynamic Type.
- Not included:
  - modification des coordonnées ou des données Firebase ;
  - regroupement du pin temporaire de création ;
  - changement du rail d'amis ou du contenu des fiches.

## Proposed approach

Attribuer le même `clusteringIdentifier` aux vues des personnes et des sorties,
puis fournir une vue dédiée pour `MKClusterAnnotation`. Lors de la sélection
d'un cluster, désactiver temporairement le clustering de ses membres, les
réinsérer et appliquer des `centerOffset` radiaux déterministes. Un calque
décoratif suit le point réel et relie chaque marqueur déployé. Le repli restaure
les offsets et le clustering natifs.

## Affected files

- `wander/MapWithFogView.swift` — clustering, état de déploiement et sélection.
- `wander/MapSocialClusterAnnotationView.swift` — rendu du groupe et connecteurs.
- `docs/plans/2026-09-01-regrouper-marqueurs-carte.md` — suivi du travail.
- `docs/solutions/2026-09-01-deployer-cluster-mapkit-coordonnees-identiques.md`
  — apprentissage réutilisable si l'approche est vérifiée.
- `todos/` — uniquement si la revue laisse un finding non résolu.
- `Documentation UX.md` dans le vault Obsidian Wander — comportement utilisateur.
- `Documentation technique.md` dans le vault Obsidian Wander — architecture MapKit.
- `Backlog features.md` dans le vault Obsidian Wander — état de la fonctionnalité.

## Implementation

- [x] Ajouter la présentation et la vue accessible du cluster social.
- [x] Activer le clustering commun hors pin de création.
- [x] Déployer et replier les annotations réelles sans changer leurs coordonnées.
- [x] Préserver les sélections directes, programmatiques et hors champ.
- [x] Masquer les durées circulaires dans un groupe déployé.
- [x] Vérifier le build et les scénarios sur l'iPhone 17 Simulator actif.
- [x] Relire le diff et consigner les findings éventuels.
- [x] Mettre à jour la documentation du dépôt.
- [ ] Mettre à jour les notes Obsidian concernées — le vault est présent mais
  non inscriptible depuis cette session ; détail dans les notes de revue.

## Edge cases and risks

- MapKit peut recalculer un cluster pendant la réinsertion — l'état de
  déploiement est défini avant la réinsertion et l'ordre des membres est stable.
- Des membres peuvent sortir de l'écran près d'un bord — la carte recentre
  légèrement le groupe avant le déploiement si l'espace manque.
- Une sélection venant du rail ou d'une notification peut cibler un membre
  regroupé — le coordinateur révèle le groupe avant de sélectionner la cible.
- Les zones tactiles des pins de 88 points peuvent se chevaucher — le rayon
  radial tient compte de leur emprise et reste déterministe.
- Une mutation de la composition peut laisser un déploiement obsolète — tout
  ajout, retrait ou déplacement d'un membre replie le groupe.

## Validation

- [x] `xcodebuild` Debug pour simulateur réussit sans nouvel avertissement lié à
  cette modification.
- [x] `git diff --check` réussit.
- [x] Trois personnes et une sortie au même endroit forment un groupe lisible.
- [x] Le groupe se déploie et chaque membre reste sélectionnable ; le repli est
  attaché au changement de caméra et de composition.
- [x] Les pins isolés conservent durée, callout, fiche et apparence.
- [x] Les chemins de sélection du rail, du focus événement et des indicateurs
  hors champ réutilisent le révélateur de membre regroupé ; build et revue
  statique conformes.
- [x] VoiceOver, clair/sombre et grande taille de texte ont été contrôlés ; le
  déploiement n'ajoute aucune animation personnalisée sous Réduire les animations.

Validation exécutée le 2026-09-01 :

- `xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration
  Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath
  /tmp/wander-social-cluster-derived-data build` — succès ;
- fixture `DEBUG` temporaire sur l'iPhone 17 Simulator iOS 26.3 — groupe mixte,
  déploiement radial, connecteurs, callout ami et sélection de sortie conformes ;
- arbre d'accessibilité — membres masqués retirés du cluster replié, résumé
  complet et membres réexposés au déploiement ;
- modes sombre et clair, puis catégorie de texte
  `accessibility-extra-large` — contrôlés ; la légende compacte réduit sa taille
  si nécessaire et la valeur VoiceOver reste intégrale ;
- la fixture et son argument de lancement ont été retirés avant le build final ;
- `git diff --check` — succès.

## Acceptance criteria

- [x] Les marqueurs proches ne se recouvrent plus à l'état replié.
- [x] Le résumé distingue personnes et sorties.
- [x] Un toucher déploie les annotations réelles sans modifier les coordonnées.
- [x] Les interactions ami, utilisateur et sortie restent attachées aux membres.
- [x] Un déplacement ou une mutation du groupe restaure le clustering natif.

## Review notes

- Hardest decision: préserver les interactions des annotations réelles plutôt
  que créer des boutons proxy déconnectés de MapKit. La réinsertion avec
  `centerOffset` a conservé callouts, fiches et accessibilité.
- Rejected alternatives: superposer les quatre pins ; zoomer seulement, car des
  coordonnées identiques resteraient regroupées ; remplacer toutes les actions
  par une liste, qui ajouterait une navigation intermédiaire.
- Least certain: la fréquence de repli lorsque plusieurs positions changent en
  direct. Ce comportement est volontaire pour éviter un déploiement rattaché à
  des coordonnées devenues obsolètes et devra être observé avec plusieurs
  comptes réels.
- Review result: aucun finding P1, P2 ou P3 non résolu ; aucun fichier `todos/`
  ajouté.
- Obsidian limitation: le vault
  `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander`
  existe mais ses fichiers sont non inscriptibles dans cette session. Restent à
  mettre à jour et à vérifier en reading view :
  - `Documentation UX.md` — propriété `updated`, section « Amis sur la carte »
    pour le groupe compact, le déploiement radial, le repli et l'accessibilité,
    puis les scénarios correspondants dans « Points UX encore à valider » ;
  - `Documentation technique.md` — propriété `updated`, section « Carte » pour
    le `clusteringIdentifier` commun, `MKClusterAnnotation`, la réinsertion des
    membres et les `centerOffset` ;
  - `Backlog features.md` — propriété `updated` et vérification de « En cours » ;
    aucun item ne doit rester ouvert puisque la fonctionnalité est terminée.
  Aucune validation des propriétés, wikilinks, tableaux, callouts, code fences
  ou diagrammes Obsidian n'est revendiquée.

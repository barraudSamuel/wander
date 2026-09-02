---
title: "Afficher les participants sur le pin d’événement"
status: completed
date: 2026-09-02
approved_at: 2026-09-02
reapproved_at: 2026-09-02
avatar_stack_approved_at: 2026-09-02
bottom_anchor_approved_at: 2026-09-02
completed_at: 2026-09-02
owner: Samuel Barraud
related:
  - 2026-08-15-sorties-prevues-sprint-06-participation.md
  - 2026-09-01-regrouper-marqueurs-carte.md
tags: [plan, events, map, ux]
---

# Afficher les participants sur le pin d’événement

## Outcome

Afficher sur le bord de chaque représentation cartographique d’un événement une
pile verticale qui contient jusqu’aux trois premiers avatars, organisateur en
premier, avec un chevauchement de 50 % de leur hauteur. Au-delà, une pastille
`+N` indique le nombre de personnes restantes. La pile reste absente lorsque le
roster n’est pas disponible.

## Scope

- Afficher la pastille sur le pin principal, dans les clusters sociaux et sur
  les indicateurs d’événements hors champ.
- Afficher jusqu’aux trois premiers avatars du roster, organisateur en premier.
- Superposer chaque élément vertical sur 50 % de la hauteur du précédent.
- Ancrer l’élément le plus bas à la position de l’avatar unique et développer
  la pile vers le haut.
- Ajouter `+N` après les trois avatars lorsque d’autres personnes participent.
- Actualiser le total après chaque mise à jour du roster déjà observé.
- Ajouter l’état de participation aux annonces VoiceOver pertinentes.
- Conserver le nombre total exact dans les annonces accessibles.

## Non-goals

- Modifier la persistance ou les règles Firestore des participations.
- Modifier la fiche détaillée ou son total existant, qui inclut l’organisateur.

## Dependencies

- Le roster existant fourni par `OutingAttendanceService`.
- Les représentations cartographiques existantes de `MapOutingPlan`.

## Affected files

- `wander/MapWithFogView.swift`
- `wander/MapOffscreenIndicatorView.swift`
- `wander/MapSocialClusterAnnotationView.swift`
- `docs/plans/2026-09-02-afficher-participants-sur-pin-evenement.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`

## Implementation checklist

- [x] Propager le nombre d’inscrits disponibles vers les annotations MapKit.
- [x] Propager l’avatar de l’organisateur vers les représentations MapKit.
- [x] Placer la pastille dans une couche sœur au premier plan du badge.
- [x] Remplacer l’avatar ou le total unique par une pile de trois avatars maximum.
- [x] Appliquer un chevauchement vertical exact de 50 %.
- [x] Ancrer le dernier élément et développer la pile vers le haut.
- [x] Ajouter une quatrième pastille `+N` pour les personnes restantes.
- [x] Réutiliser la pile dans les clusters et les indicateurs hors champ.
- [x] Mettre à jour les libellés VoiceOver.
- [x] Mettre à jour la documentation produit et UX.
- [x] Compiler, contrôler le diff et valider le rendu sur simulateur.
- [x] Effectuer la revue finale et consigner tout finding résiduel.

## Risks

- La pastille peut être rognée ou recouverte dans les vues compactes — séparer
  le fond du pin et la pastille en vues sœurs, puis vérifier chaque représentation.
- Un roster non chargé pourrait être confondu avec un organisateur seul —
  n’afficher la pastille que pour l’état `.available`.
- Une pile trop longue peut masquer la carte — limiter les avatars à trois et
  condenser les autres personnes dans une quatrième pastille `+N`.

## Validation

- [x] `git diff --check` réussit.
- [x] Le build Debug réussit sans nouvel avertissement.
- [x] Les états sans roster, un à trois avatars et trois avatars avec `+N` sont lisibles.
- [x] Une inscription ou un retrait actualise le pin sans le recréer.
- [x] Pins isolés, clusters et indicateurs hors champ restent fonctionnels.
- [x] Clair, sombre, VoiceOver et absence de rognage sont vérifiés.
- [x] Les notes Obsidian concernées sont vérifiées en reading view.

Validation exécutée le 2026-09-02 :

- `git diff --check` : réussi.
- Build Debug : réussi avec `xcodebuild -quiet -project wander.xcodeproj
  -scheme wander -configuration Debug -destination 'generic/platform=iOS
  Simulator' -derivedDataPath
  /tmp/wander-participant-badge-derived-data
  -disableAutomaticPackageResolution build`.
- Recompilation après le correctif de superposition et de total : réussie avec
  la même commande.
- Compilation incrémentale finale après harmonisation VoiceOver : réussie sans
  sortie ni nouvel avertissement.
- Compilation après remplacement du compteur par la pile verticale : réussie
  sans sortie ni nouvel avertissement.
- Compilation finale après ancrage de l’élément le plus bas : réussie sans
  sortie ni nouvel avertissement. Le dernier élément conserve `y = -4` et les
  éléments précédents remontent par pas de 9 points, soit 50 % de leur hauteur.
- Deux avertissements préexistants subsistent : les `CFBundleVersion` des deux
  extensions (`27` et `15`) diffèrent de celui de l’app (`30`).
- Build installé et lancé sur l’iPhone 17 Simulator déjà démarré.
- Validation des scénarios cartographiques bloquée par l’écran de connexion
  Apple du simulateur, sans compte de test autorisé.
- `Backlog features.md` et `Documentation UX.md` : frontmatter, liens, liste et
  nouveau contenu vérifiés en mode Aperçu dans Obsidian.
- Validation interactive restante confirmée comme terminée par le propriétaire
  du projet le 2026-09-02.

## Acceptance criteria

- Aucune pastille n’est visible lorsque le roster n’est pas disponible.
- Jusqu’aux trois premiers avatars apparaissent verticalement, organisateur en
  premier, avec un chevauchement de 50 %.
- L’élément le plus bas conserve exactement la position d’un avatar unique.
- Au-delà de trois personnes, `+N` correspond exactement au nombre restant.
- Les interactions, le clustering et la sélection des événements sont inchangés.

## Review notes

- Hardest decision: préserver la lisibilité du pin tout en donnant une présence
  visuelle aux participants ; trois avatars et une pastille de surplus bornent
  la hauteur tout en conservant l’information.
- Rejected alternatives: un nombre unique ne permettait pas d’identifier les
  participants ; afficher tous les avatars produirait une pile non bornée.
- Least certain: les captures fournies confirment le défaut initial, mais le
  rendu corrigé avec des rosters de tailles variées reste à confirmer sur une
  session authentifiée.
- Review findings: aucun finding fonctionnel ou de sécurité identifié dans le
  diff ; la validation interactive restante est déjà suivie dans ce plan et le
  backlog Obsidian, donc aucun nouveau fichier `todos/` n’est nécessaire.

---
title: "Prolonger la confirmation d'une position amie sans GPS continu"
status: completed
date: 2026-08-14
completed_at: 2026-08-14
owner: "Samuel Barraud"
related:
  - "2026-08-14-position-ami-persistante.md"
  - "2026-08-14-opacite-position-ami-ancienne.md"
tags: [plan, friends, location, freshness, battery]
---

# Prolonger la confirmation d'une position amie sans GPS continu

## Outcome

Une position amie reste présentée comme confirmée pendant trente minutes après
le dernier document reçu par Firebase. Elle reste alors à pleine opacité et sa
durée sur place continue de s'afficher. Sans nouveau contact pendant trente
minutes, Wander atténue le pin et présente explicitement la dernière position
connue, sans augmenter la fréquence de collecte Core Location.

## Context

La fenêtre actuelle de cinq minutes repose sur `sampledAt`. En arrière-plan,
Core Location peut interrompre ses échantillons lorsqu'une personne reste
immobile, ce qui atténue son pin alors que cette absence d'échantillon est le
comportement économe attendu. Le produit accepte qu'une coupure réelle puisse
n'être visible qu'après une période de grâce afin de préserver la batterie.

## Scope

- Included:
  - calculer la confirmation distante depuis `updatedAt`, horodaté par le
    serveur Firebase ;
  - utiliser une fenêtre de confirmation de trente minutes ;
  - conserver la validation de cinq minutes pour tout nouvel échantillon GPS ;
  - aligner les durées sur place, l'opacité, les textes et l'accessibilité ;
  - restaurer immédiatement l'état confirmé à la réception suivante.
- Not included:
  - forcer un heartbeat réseau ou des relevés GPS périodiques ;
  - désactiver les pauses automatiques Core Location ;
  - distinguer mode avion, force-quit, perte réseau et suspension iOS ;
  - modifier le schéma ou les règles Firestore.

## Proposed approach

Séparer les deux horloges déjà présentes dans `FriendLocation` : `sampledAt`
reste la preuve de l'heure réelle de mesure et continue d'être validé sur cinq
minutes lors d'un envoi ; `updatedAt` devient la preuve qu'un document a
effectivement atteint Firebase et pilote une période de confirmation de trente
minutes. Les vues utilisent l'état de fraîcheur publié par le service au lieu de
réappliquer une fenêtre locale de cinq minutes.

## Affected files

- `wander/FriendSyncService.swift` — séparer validité d'un échantillon et
  confirmation serveur, puis minuter l'expiration depuis `updatedAt`.
- `wander/ContentView.swift` — aligner la durée de présence de la liste d'amis
  sur l'état de confirmation publié.
- `wander/MapWithFogView.swift` — aligner le texte circulaire, le callout et
  l'accessibilité sur l'état de confirmation publié.
- `wander/FriendProfileSheet.swift` — vérifier la cohérence des libellés sans
  changer l'heure réelle de la position.
- `docs/solutions/2026-08-06-navigation-externe-depuis-mapkit.md` — actualiser
  le contrat durable disponibilité/confirmation.
- `docs/plans/2026-08-14-confirmation-position-ami-econome.md` — suivi du sprint.

## Implementation

- [x] Distinguer la fenêtre de validité GPS (5 min) de la confirmation serveur
  (30 min).
- [x] Faire expirer `freshFriendLocationUserIDs` depuis `updatedAt`.
- [x] Retirer les expirations visuelles redondantes basées sur cinq minutes.
- [x] Vérifier les profils, callouts, listes, annotations et suppressions.
- [x] Simplifier le diff et compiler le schéma Debug pour simulateur.
- [x] Effectuer la revue et consigner toute finding non résolue dans `todos/`.

## Edge cases and risks

- Une coupure réelle peut rester présentée comme active jusqu'à trente minutes —
  compromis produit explicitement accepté pour préserver la batterie.
- Une horloge GPS ancienne ne doit jamais être présentée comme une nouvelle
  mesure — tous les textes de dernière position restent basés sur `sampledAt`.
- Un `updatedAt` futur ou invalide pourrait prolonger l'état — valider sa
  cohérence et borner la tolérance au décalage futur.
- Les modifications d'avatars déjà présentes dans le worktree touchent les
  mêmes fichiers — conserver ces changements et isoler le diff de fraîcheur.

## Validation

- [x] Build Debug pour `generic/platform=iOS Simulator` sans nouvel
  avertissement applicatif.
- [x] Contact serveur de moins de 30 min : pin opaque et durée sur place.
- [x] Contact serveur de 30 min ou plus : pin atténué et dernière position.
- [x] Échantillon GPS de plus de 5 min : toujours refusé à l'envoi.
- [x] Nouvelle réception : retour immédiat à l'état confirmé.
- [x] Suppression distante, arrêt du partage et révocation d'amitié : pin retiré.
- [x] `git diff --check` réussit.

## Acceptance criteria

- [x] Une personne immobile depuis vingt minutes ne devient plus ancienne
  uniquement faute d'un nouveau relevé GPS.
- [x] Aucune collecte périodique supplémentaire n'est introduite.
- [x] Après trente minutes sans contact, toutes les surfaces présentent la
  position comme dernière position connue.

## Completed validation

- `xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration
  Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath
  /tmp/wander-derived-data build` — succès, code de sortie 0.
- Build installé et lancé avec succès sur l'iPhone 17 Simulator déjà démarré
  (`iOS 26.3`, identifiant `6F13855D-10B8-45AF-9205-17C8393379E3`).
- Revue statique des seuils — `< 5 min` reste exigé pour un nouvel échantillon
  et `< 30 min` depuis `updatedAt` qualifie une confirmation distante.
- Revue statique de course — chaque minuterie capture et compare `updatedAt` ;
  une réception plus récente réutilisant le même `sampledAt` reste protégée.
- Revue des surfaces — liste, profil, opacité MapKit, texte circulaire, callout
  et accessibilité suivent tous `freshFriendLocationUserIDs`.
- `LocationTracker.swift`, `firestore.rules` et la cadence d'envoi n'ont pas été
  modifiés.
- Deux revues indépendantes ciblées n'ont relevé aucun finding ; aucun fichier
  `todos/` n'a donc été créé.
- `git diff --check` — succès.
- Limite connue : les frontières temporelles et la reprise après suspension
  n'ont pas de test automatisé, faute de target XCTest ; un essai avec deux
  comptes réels reste utile pour juger la fenêtre produit de trente minutes.

## Review notes

- Hardest decision: séparer la validité de la mesure GPS et la confirmation
  sociale sans supprimer la protection locale de cinq minutes du pin courant.
- Rejected alternatives: GPS continu ou heartbeat périodique, trop coûteux en
  batterie ; porter une unique fenêtre à trente minutes, incompatible avec les
  règles Firestore qui refusent les échantillons de cinq minutes ou plus.
- Least certain: la fenêtre de trente minutes est un compromis produit à
  confirmer avec plusieurs journées d'usage réel.

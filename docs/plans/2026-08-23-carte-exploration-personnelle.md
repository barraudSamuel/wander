---
title: "Afficher uniquement la carte d'exploration personnelle"
status: in_progress
created_at: 2026-08-23T12:17:19+09:00
approved_at: 2026-08-23T12:17:19+09:00
started_at: 2026-08-23T12:17:19+09:00
---

# Afficher uniquement la carte d'exploration personnelle

## Outcome

Wander affiche et synchronise visuellement uniquement la scratch map du compte
connecté. Les explorations des amis restent stockées dans Firestore pour de
futures vues individuelles, mixtes et comparatives, mais le client courant ne
les lit plus.

## Scope

- retirer les listeners Firestore des collections de cellules des amis ;
- retirer les modèles et états dérivés de ces explorations distantes ;
- supprimer les overlays, filtres, compteurs et progressions d'amis ;
- conserver les positions, avatars, profils, sorties et itinéraires sociaux ;
- conserver la synchronisation Firestore de l'exploration personnelle ;
- adapter les textes et la documentation produit et technique.

## Non-goals

- supprimer ou migrer les cellules déjà stockées dans Firestore ;
- modifier les règles Firestore ;
- optimiser dans ce sprint la reprise incrémentale de l'exploration personnelle ;
- construire les futures vues par ami, mixtes ou comparatives ;
- modifier le partage de position ou les événements sociaux.

## Dependencies

- Firebase Firestore et SwiftData restent inchangés ;
- MapKit continue d'afficher la scratch map personnelle, les positions et les
  sorties ;
- validation interactive sur l'iPhone 17 Simulator déjà installé.

## Affected files

- `wander/FriendSyncService.swift`
- `wander/ContentView.swift`
- `wander/FriendProfileSheet.swift`
- `wander/MapWithFogView.swift`
- `wander/OnboardingView.swift`
- `docs/plans/2026-08-23-carte-exploration-personnelle.md`
- Obsidian `Backlog features.md`
- Obsidian `Documentation technique.md`
- Obsidian `Documentation UX.md`
- Obsidian `00 - Wander.md`
- `todos/` uniquement si la revue révèle un finding actionnable
- `docs/solutions/` uniquement si la validation produit un apprentissage
  réutilisable

## Implementation checklist

- [x] Retirer les listeners et caches d'exploration des amis.
- [x] Conserver sans changement le listener et l'upload de l'exploration propre.
- [x] Retirer les données d'exploration d'amis des résumés et profils.
- [x] Afficher uniquement les cellules personnelles dans le brouillard.
- [x] Retirer les overlays et renderers de scratch maps d'amis.
- [x] Simplifier le filtre d'affichage à la heat map personnelle.
- [x] Adapter les textes devenus obsolètes.
- [x] Mettre à jour les quatre notes Obsidian et leur propriété `updated`.
- [ ] Vérifier le parcours sur l'iPhone 17 Simulator après autorisation de démarrage.
- [x] Effectuer une revue du diff et consigner les éventuels findings.

## Risks

- le centrage d'un ami sans position ne doit plus dépendre de son ancienne
  exploration ;
- la suppression des données d'exploration des callouts ne doit pas affecter
  les informations de présence et d'itinéraire ;
- l'ordre des overlays personnels, de heat map et d'événements doit rester
  stable ;
- les anciennes données Firestore doivent rester intactes pour la future
  réactivation des vues sociales.

## Validation

- `xcodebuild` Debug pour un simulateur iOS générique ;
- lancement sur l'iPhone 17 Simulator déjà disponible ;
- scratch map personnelle et heat map toujours visibles ;
- absence de scratch map, progression, compteur et filtre d'ami ;
- positions, profils, sorties et itinéraires d'amis fonctionnels ;
- recherche statique confirmant l'absence de listener de cellules d'amis ;
- revue du diff, des avertissements et de la documentation ;
- vérification des notes Obsidian en vue lecture.

## Acceptance criteria

- aucune collection `explorations/{friendId}/cells` n'est écoutée par le client ;
- seules les cellules du compte connecté contribuent au brouillard révélé ;
- aucune statistique d'exploration d'ami n'est affichée ;
- les fonctions sociales hors exploration ne régressent pas ;
- les cellules personnelles continuent d'être synchronisées dans Firestore ;
- la compilation et les vérifications ciblées réussissent.

## Validation log

- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug
  -destination 'generic/platform=iOS Simulator' build` : réussi le 23 août 2026 ;
- avertissement préexistant hors périmètre : `CFBundleVersion` de l'app `24`
  différent de celui de la Share Extension `15` ;
- recherche statique : aucun type, état, renderer ou listener d'exploration
  d'ami ne subsiste dans `wander/` ;
- les trois appels à `explorationCellsCollection(for:)` restants concernent le
  compte connecté : suppression de compte, listener propre et upload propre ;
- `git diff --check` : réussi ;
- `xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration
  Debug -destination 'generic/platform=iOS Simulator' analyze` : réussi ;
- les quatre notes Obsidian ont été ouvertes en mode Aperçu ; propriétés,
  wikilinks, listes et nouveaux passages rendus correctement ;
- validation interactive en attente : aucun iPhone 17 Simulator n'était démarré
  et son démarrage nécessite l'autorisation explicite du propriétaire.

## Review

Aucun finding nouveau lié à ce changement. L'avertissement de version de la
Share Extension est préexistant et déjà documenté dans plusieurs plans. La
séparation entre synchronisation personnelle et vues sociales est consignée
dans `docs/solutions/2026-08-23-separer-synchronisation-personnelle-et-vues-sociales.md`.

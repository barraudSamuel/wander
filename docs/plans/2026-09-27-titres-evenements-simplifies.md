---
title: Titres des événements simplifiés
status: completed
date: 2026-09-27
completed_at: 2026-09-27
owner: Samuel
---

# Titres des événements simplifiés

Samuel a validé explicitement le plan corrigé par « je valide ».

## Résultat et périmètre

Garder l'icône bleue de catégorie et le format compact. Retirer la ligne
visible « Vous organisez » des événements personnels. Le titre de chaque
carte affiche uniquement le nom du lieu, sans préfixe « Café à », « Repas à »,
« Sport à », etc. Les événements des amis conservent « Proposé par … ».
Les autres informations, actions et descriptions accessibles sont conservées.

## Fichiers concernés

- `wander/MapEventsPanelView.swift` : contenu de `invitation`.
- Ce plan de suivi.
- Coffre `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Documentation UX.md`, section Sorties prévues ; `Backlog features.md`,
  entrée Valider les cartes événements autonomes. Mettre `updated` à jour
  et préserver les wikilinks.

## Étapes

- [x] Approbation explicite du plan corrigé.
- [x] Retirer les textes redondants de la présentation visible.
- [x] Relire le delta et compiler l'app et les tests.
- [x] Mettre à jour les deux notes Obsidian.
- [x] Consigner les résultats et limites.

## Risques, validation et acceptation

Les noms longs restent multilignes. L'icône continue d'indiquer l'activité et
le résumé accessible garde catégorie et organisateur. Seul le texte visible
change ; aucun test supplémentaire pour ce changement de présentation.
Compiler avec `xcodebuild build-for-testing`, puis contrôler le diff ciblé.
Ne pas démarrer de simulateur ; le dernier inventaire de cette conversation
ne recensait aucun appareil actif. Le rendu et les tests exécutés ne seront
pas revendiqués sans preuve. Aucun test d'accessibilité dédié.

Critères : titre égal au nom du lieu, ligne personnelle retirée, icône bleue
et texte de l'organisateur ami conservés, compilation réussie, notes à jour
ou limitation d'accès documentée. Les modifications locales préexistantes
restent intactes. Aucune commande Git modificatrice.

## Validation et revue

- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build-for-testing` : code 0, `TEST BUILD SUCCEEDED`.
- Journal : `/tmp/wander-event-titles-build.log`.
- Aucun diagnostic Swift ; quatre avertissements d'extraction AppIntents déjà
  présents lors de la compilation précédente, hors périmètre de ce changement.
- `git diff --check` réussi.
- Revue manuelle et simplification ciblées sur le delta depuis la copie
  `/var/folders/82/b5lh3jvd5qd3lg9gq_2rfplw0000gn/T/wander-event-titles-83rlvcmh/MapEventsPanelView.swift`.
  Seule `invitation` change. Les icônes, les actions, le compteur et les résumés
  accessibles sont identiques. Les noms gardent leur disposition multilignes.
  Aucune anomalie retenue, aucun finding à créer.
- Changement trivial de présentation : aucun test supplémentaire ni délégation.
  App et tests compilés ; tests non exécutés, rendu non observé. Aucun simulateur
  démarré et aucun test d'accessibilité dédié.
- Les deux notes Obsidian ont été mises à jour à
  `2026-09-27T11:32:05+09:00`, avec sauvegardes dans le répertoire de référence.
  Leur texte a été relu après écriture et les wikilinks comparés avant/après.
  Obsidian n'a pas été ouvert.

Le changement retire uniquement les préfixes ajoutés par l'interface : un vrai
nom de lieu contenant « Café » reste intact. Aucune nouvelle leçon réutilisable
ne nécessite de document de solution. Aucun commit ni publication.

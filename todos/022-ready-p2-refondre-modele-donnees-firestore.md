---
id: "022"
title: "Refondre le modèle de données Firestore"
status: ready
priority: P2
source: product-owner
created: 2026-09-01
tags: [todo, firebase, firestore, architecture, migration]
---

# Refondre le modèle de données Firestore

## Finding

Le modèle Firestore a grandi au fil des fonctionnalités sans revue globale de
sa topologie. Les profils, relations, positions, explorations, événements,
participations, appareils et documents techniques utilisent aujourd’hui des
niveaux d’imbrication et des propriétaires différents. Cette organisation
complique les règles, les suppressions en cascade, les migrations et certaines
requêtes sociales.

Une refonte doit repartir du fonctionnement réel de l’application et choisir
explicitement entre migration progressive et remise à zéro contrôlée. Une
suppression complète peut être étudiée, mais ne doit jamais être exécutée sans
inventaire, export, environnement confirmé et approbation destructive dédiée.

## Evidence

- Les données principales sont réparties entre `users/{uid}`, `friendCodes`,
  `friendships`, `locations`, `explorations/{uid}/cells` et
  `users/{ownerID}/events/{eventID}/attendees`.
- Les appareils de notification et d’actualisation de position sont imbriqués
  sous le profil, alors que les dispatches et positions utilisent des
  collections racine.
- Les suppressions d’amitié, de publication et de compte nécessitent plusieurs
  nettoyages client ou backend pour traiter les documents liés.
- Avant la simplification du 1er septembre 2026, les règles approchaient 1 000
  lignes. La nouvelle matrice d'autorisation réduit la dette des règles, mais ne
  change ni la topologie, ni les nettoyages, ni les coûts du modèle actuel.
- `firestore.indexes.json` ne contient actuellement qu’un override pour la
  requête de nettoyage des événements par `publishedAt`.

## Acceptance criteria

- [ ] Inventorier chaque collection, sous-collection, champ structurant,
      propriétaire, lecteur, écrivain, listener, requête, index et politique de
      rétention utilisés par l’application et les Functions.
- [ ] Documenter les parcours réels : profil, ajout et révocation d’ami,
      localisation, exploration, événement, participation, notification et
      suppression de compte.
- [ ] Produire un schéma cible avec des frontières de propriété cohérentes et
      justifier chaque imbrication, duplication et collection racine.
- [ ] Évaluer les coûts, limites de requête, listeners, écritures en éventail,
      index nécessaires et volumes attendus du schéma cible.
- [ ] Définir les cycles de vie et nettoyages automatiques pour les relations,
      positions, événements, participations, appareils et comptes.
- [ ] Revalider la matrice d'autorisation simplifiée du finding `021` contre le
      schéma cible et documenter uniquement les nouvelles frontières requises.
- [ ] Comparer une migration progressive compatible avec une remise à zéro de
      la base, avec risques, durée, coût et impact utilisateur.
- [ ] Si une remise à zéro est retenue, prévoir export vérifié, dry-run,
      environnement et projet explicitement confirmés, restauration testée et
      approbation destructive séparée avant toute suppression.
- [ ] Fournir scripts ou outils de migration idempotents, métriques de contrôle
      et procédure de rollback ; aucune manipulation manuelle non traçable dans
      la console Firebase.
- [ ] Valider le schéma cible avec l’émulateur, les tests de règles, les tests
      Functions et des scénarios multi-comptes représentatifs.
- [ ] Planifier la migration et les changements Swift, Functions, règles et
      index en incréments déployables sans état hybride non pris en charge.
- [ ] Mettre à jour la documentation technique et consigner les décisions
      d’architecture réutilisables.

## Resolution notes

Dette explicitement demandée par le propriétaire le 2026-09-01. Ce finding ne
modifie et ne supprime aucune donnée Firebase.

La simplification tactique des règles a été réalisée séparément dans
`docs/plans/2026-09-01-simplifier-regles-firestore.md` afin de débloquer les
parcours actuels sans attendre une migration de données. Elle devient la base
d'autorisation à préserver ou adapter ; elle ne remplace aucun des travaux de
topologie, cycle de vie, coût ou migration suivis ici. La refonte doit rester
coordonnée avec `todos/020-ready-p2-refactor-codebase.md`.

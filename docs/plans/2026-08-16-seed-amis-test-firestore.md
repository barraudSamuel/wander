---
title: "Générer des amis fictifs Firestore à Séoul"
date: 2026-08-16
status: completed
started_at: 2026-08-16
completed_at: 2026-08-16
tags: [plan, firebase, friends, testing, seoul]
---

# Générer des amis fictifs Firestore à Séoul

## Outcome

Fournir un outil local et réversible qui rattache plusieurs profils fictifs au
véritable compte Wander du développeur. Les amis acceptés disposent de positions
distinctes sur des lieux publics de Séoul afin de tester la liste sociale, les
pins de carte et les demandes entrantes sans créer de comptes Apple.

## Scope

- créer des profils, codes amis, relations et positions fictifs cohérents ;
- prendre en charge les relations acceptées et les demandes entrantes ;
- proposer des commandes séparées de création, rafraîchissement des positions
  et nettoyage ;
- utiliser Firebase Admin avec un projet et un UID propriétaire explicites ;
- conserver un manifeste distant des chemins exacts possédés par l'outil ;
- exécuter une simulation en lecture seule tant que `--apply` est absent.

## Non-goals

- créer des utilisateurs Firebase Auth ou de faux comptes Apple ;
- permettre aux profils fictifs d'ouvrir l'application ;
- modifier l'application iOS, les règles Firestore ou les Cloud Functions ;
- simuler des explorations, sorties ou participations ;
- maintenir automatiquement les positions en arrière-plan.

## Dependencies

- `firebase-admin` déjà présent dans `functions/` ;
- des Application Default Credentials locales ou
  `GOOGLE_APPLICATION_CREDENTIALS`, toujours conservées hors du dépôt ;
- l'UID Firebase du profil Wander propriétaire ;
- un projet Firebase fourni explicitement à chaque commande.

## Affected files

- `functions/src/testFriendFixtures.ts` — modèle déterministe et opérations
  Firestore sécurisées ;
- `functions/src/testFriendFixturesCli.ts` — analyse des arguments et commandes ;
- `functions/src/testFriendFixtures.test.ts` — tests unitaires ;
- `functions/package.json` — scripts npm ;
- `docs/solutions/2026-08-16-seeder-amis-fictifs-firestore.md` — enseignements
  réutilisables après validation.

## Implementation checklist

- [x] Générer des UID, codes amis, pseudos, avatars et couleurs déterministes.
- [x] Répartir les profils sur des lieux publics distincts de Séoul.
- [x] Construire des relations acceptées et des demandes entrantes valides.
- [x] Exiger `--project`, `--owner-uid` et `--apply` pour toute écriture.
- [x] Exiger un consentement séparé avant de créer des demandes susceptibles
      de déclencher des notifications.
- [x] Vérifier le profil propriétaire et détecter toute collision avant écriture.
- [x] Stocker et valider un manifeste exact pour les opérations rejouables.
- [x] Rafraîchir uniquement les positions appartenant au manifeste.
- [x] Nettoyer uniquement les chemins validés du manifeste, sans glob ni
      suppression récursive.
- [x] Ne jamais journaliser l'UID propriétaire ni les chemins qui le contiennent.
- [x] Ajouter les commandes npm et leur aide intégrée.
- [x] Ajouter les tests unitaires et exécuter la validation complète.
- [x] Effectuer une revue de simplification et de sécurité.
- [x] Documenter l'utilisation et les enseignements réutilisables.

## Risks and mitigations

- **Écriture dans le mauvais projet** — aucun projet implicite ; `--project` est
  obligatoire et rappelé avant `--apply`.
- **Suppression de données réelles** — nettoyage limité aux références exactes
  d'un manifeste validé et aux UID fictifs portant le préfixe attendu.
- **Collision avec des données existantes** — prélecture de chaque cible et
  échec atomique si une cible n'appartient pas déjà au manifeste.
- **Notification push non souhaitée** — les demandes entrantes sont désactivées
  sans un drapeau de consentement dédié sur un projet distant.
- **Positions vieillissantes** — elles restent des dernières positions connues ;
  une commande explicite rafraîchit leurs horodatages.
- **Fuite de credentials ou d'identifiants** — aucun secret dans le dépôt et
  aucune valeur d'authentification dans les journaux.

## Validation

- `npm test` : compilation TypeScript stricte réussie, 23 tests réussis et le
  test d'intégration ignoré hors émulateur ;
- émulateur Firestore avec Java 25 et projet `demo-wander-fixture-lifecycle` :
  24 tests réussis, aucun échec, aucun test ignoré ;
- cycle testé : collision refusée, simulation sans écriture, création, relance
  idempotente, rafraîchissement, simulation du nettoyage et nettoyage ;
- le profil propriétaire et un document étranger restent intacts après le
  nettoyage ;
- les aides `seed`, `refresh` et `cleanup` s'exécutent sans credentials ;
- revue manuelle : aucun finding nécessitant un fichier dans `todos/` ;
- aucun déploiement ni accès au projet Firebase distant.

## Acceptance criteria

- les amis acceptés apparaissent dans Wander avec des positions distinctes à
  Séoul ;
- une demande entrante fictive peut être acceptée dans l'application ;
- relancer la création ne produit aucun doublon ;
- le rafraîchissement ne modifie que les positions du manifeste ;
- le nettoyage retire uniquement les fixtures créées par l'outil ;
- toute commande mutante exige `--apply` et un projet explicite ;
- les tests et la compilation réussissent sans avertissement pertinent.

## Approval

Plan approuvé explicitement par le propriétaire du projet le 2026-08-16.

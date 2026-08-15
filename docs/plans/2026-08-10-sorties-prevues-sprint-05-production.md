---
title: "Sorties prévues — Sprint 5 — Validation et production"
status: completed
sprint: 5
date: 2026-08-10
completed_at: "2026-08-15T15:54:23+09:00"
approved_at: "2026-08-15"
depends_on:
  - "Sprint 1 completed"
  - "Sprint 2 completed"
  - "Sprint 3 completed"
  - "Sprint 4 completed"
tags: [plan, sprint, validation, production]
---

# Sprint 5 — Durcir, valider et mettre en production

## Status

Ce sprint est `completed` pour le seul périmètre TTL défini dans la section
« Périmètre approuvé » ci-dessous. Les Sprints 1 à 4 sont `completed`. Le
propriétaire a créé manuellement la politique TTL dans Google Cloud après avoir
vérifié la cible et les conséquences de l'opération.

## Périmètre approuvé

- Vérifier l'état actuel du TTL dans le projet `wander-1954f`.
- Si la politique est absente, demander l'autorisation puis l'activer pour le
  collection group `plans`, le champ timestamp `expiresAt` et sans décalage.
- Vérifier l'état retourné par Google Cloud et documenter le résultat.
- Ne modifier aucun log, fichier Swift, règle Firestore ou Cloud Function.

Ce périmètre restreint remplace, pour cette exécution approuvée, les autres
éléments non TTL encore non cochés dans le plan initial.

## Outcome

La fonctionnalité complète est vérifiée avec des comptes et appareils réels,
les règles et fonctions sont relues, les données expirées sont nettoyées, puis
les composants approuvés sont déployés progressivement avec observation des
logs et possibilité de rollback.

## Scope

- Simplification finale du code des Sprints 1 à 4.
- Revue sécurité, confidentialité, accessibilité et performance.
- Tests automatiques et manuels de bout en bout.
- Politique TTL Firestore sur `plans.expiresAt`.
- Vérification APNs, FCM, signature Debug et Distribution.
- Déploiement séparé des règles puis de la fonction, après confirmations.
- Monitoring initial, documentation opératoire et décision de disponibilité.

## Non-goals

- Aucun ajout fonctionnel pendant le durcissement.
- Aucun nouveau schéma ou redesign.
- Aucune publication App Store automatique.
- Aucun déploiement si un critère P1 reste ouvert.
- Aucun contournement des validations de règles ou des tests à deux comptes.

## Production targets

- Projet Firebase attendu : `wander-1954f`.
- Bundle iOS attendu : `com.iterar.wander.wander`.
- Règles : `firestore.rules` via la configuration de `firebase.json`.
- Fonction : nom exact validé au Sprint 4.
- TTL : collection group `plans`, champ timestamp `expiresAt`.

## Affected files

- Tous les fichiers modifiés par les Sprints 1 à 4, uniquement pour corrections
  issues de la revue.
- `firestore.rules`, `firebase.json` et `functions/` pour la livraison backend.
- `docs/plans/` pour les résultats de validation.
- `todos/` pour toute anomalie non résolue.
- `docs/solutions/` pour les apprentissages réutilisables vérifiés.

## Implementation checklist

- [x] Vérifier que chaque sprint précédent est réellement `completed`.
- [ ] Exécuter simplification et revue de code sans élargir le périmètre.
- [ ] Exécuter le build Debug et une archive Distribution.
- [ ] Exécuter les tests de règles avec l'émulateur Firestore.
- [ ] Exécuter les tests serveur et l'audit des dépendances.
- [ ] Tester deux comptes, plusieurs appareils et révocation d'amitié.
- [ ] Vérifier permission refusée, déconnexion et suppression de compte.
- [ ] Vérifier VoiceOver, Dynamic Type, mode sombre et performances de carte.
- [x] Configurer et vérifier la politique TTL.
- [ ] Comparer les règles locales aux règles actuellement en production.
- [x] Obtenir l'autorisation explicite avant chaque déploiement.
- [ ] Surveiller les logs et métriques après livraison.

## Deployment sequence

1. Sauvegarder et comparer l'état Firebase existant.
2. Déployer uniquement les règles Firestore approuvées.
3. Rejouer les tests de lecture et d'écriture sur des comptes de test.
4. Déployer uniquement la fonction approuvée.
5. Publier une sortie de test et vérifier un dispatch unique.
6. Surveiller erreurs, refus, coûts et latence avant d'élargir l'usage.

Chaque étape de mutation externe nécessite une autorisation utilisateur au
moment concerné.

## Risks

- Un déploiement de règles remplace la version présente dans la console.
- Une mauvaise clé APNs ou équipe de signature empêche la livraison des push.
- Les suppressions TTL ne sont pas instantanées ; le client doit continuer à
  filtrer les sorties expirées.
- Les Functions nécessitent une facturation et des alertes de budget adaptées.
- Une anomalie de confidentialité impose de bloquer la mise en production.

## Validation

- [ ] Tous les builds, tests et audits automatisés réussissent.
- [ ] Matrice d'autorisation Firestore entièrement verte.
- [ ] Parcours de bout en bout réussi sur deux comptes réels.
- [ ] Une publication produit exactement les notifications attendues.
- [ ] Aucun payload visible ne contient adresse ni coordonnées.
- [ ] Annulation, expiration, révocation et suppression de compte sont vérifiées.
- [ ] Aucun finding P1 ou P2 non accepté ne reste ouvert.
- [ ] Le plan de rollback et les responsables sont identifiés.

## Completion record

Complété le 15 août 2026 sur le périmètre TTL approuvé :

- projet : `wander-1954f` ;
- base : `(default)` ;
- collection group : `plans` ;
- champ timestamp : `expiresAt` ;
- décalage d'expiration : `0 s` ;
- configuration : créée manuellement par le propriétaire dans Google Cloud ;
- état observé après création : `Création`, opération acceptée et en cours de
  propagation asynchrone côté Google Cloud.

La capture fournie par le propriétaire confirme la cible et l'état. Aucun log,
fichier Swift, règle Firestore ou Cloud Function n'a été modifié dans ce sprint.
Les éléments non TTL de la checklist initiale restent hors du périmètre approuvé
et ne conditionnent pas cette clôture.

---
title: "Sorties prévues — Sprint 5 — Validation et production"
status: proposed
sprint: 5
date: 2026-08-10
completed_at:
depends_on:
  - "Sprint 1 completed"
  - "Sprint 2 completed"
  - "Sprint 3 completed"
  - "Sprint 4 completed"
tags: [plan, sprint, validation, production]
---

# Sprint 5 — Durcir, valider et mettre en production

## Status

Ce sprint est `proposed`. Il ne doit être approuvé qu'après la complétion des
Sprints 1 à 4. L'approbation de son plan de validation ne vaut pas à elle seule
autorisation de déployer : les commandes de production doivent être confirmées
explicitement au moment de leur exécution.

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

- [ ] Vérifier que chaque sprint précédent est réellement `completed`.
- [ ] Exécuter simplification et revue de code sans élargir le périmètre.
- [ ] Exécuter le build Debug et une archive Distribution.
- [ ] Exécuter les tests de règles avec l'émulateur Firestore.
- [ ] Exécuter les tests serveur et l'audit des dépendances.
- [ ] Tester deux comptes, plusieurs appareils et révocation d'amitié.
- [ ] Vérifier permission refusée, déconnexion et suppression de compte.
- [ ] Vérifier VoiceOver, Dynamic Type, mode sombre et performances de carte.
- [ ] Configurer et vérifier la politique TTL.
- [ ] Comparer les règles locales aux règles actuellement en production.
- [ ] Obtenir l'autorisation explicite avant chaque déploiement.
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

Renseigner `completed_at`, les versions déployées, les commandes autorisées, les
résultats de monitoring et toute action de rollback. Ce sprint est le seul qui
peut conclure que la fonctionnalité est prête pour la production.

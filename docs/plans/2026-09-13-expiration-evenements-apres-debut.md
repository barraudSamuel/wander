---
title: "Supprimer les événements 12 heures après leur début"
status: completed
date: 2026-09-13
approved_at: 2026-09-13
completed_at: 2026-09-13
owner: Samuel
tags: [plan, events, firebase]
---

# Supprimer les événements 12 heures après leur début

## Résultat attendu

Le nettoyage horaire supprime les événements dont `plannedAt` est antérieur
ou égal à maintenant moins 12 heures. La disparition intervient normalement
entre 12 et 13 heures après le début prévu. Une modification sans changement
d'heure ne prolonge plus cette durée ; une reprogrammation utilise la nouvelle
heure. Exemple : début à 18 h, suppression le lendemain entre 6 h et 7 h.

## Approbation et périmètre

Samuel a explicitement approuvé le plan présenté dans la conversation le
13 septembre 2026, par « j'approuve ». Ce périmètre inclut le correctif,
les tests, la documentation, l'index puis le déploiement ciblé de la fonction.

Le cron reste horaire, la rétention reste de 12 heures et le nettoyage des
participations et refus reste confié au trigger existant. Aucun changement
Swift, de règle de sécurité, de schéma ou de migration n'est nécessaire.
Aucune commande Git mutante ne sera exécutée. Les modifications préexistantes
de l'interface et de ses plans restent hors périmètre.

## Fichiers concernés

- `functions/src/index.ts` : déléguer le nettoyage avec la date de début.
- `functions/src/eventCleanupLogic.ts` : nettoyage testable en transactions.
- `functions/src/eventCleanupLogic.test.ts` : régressions et intégration locale.
- `firestore.indexes.json` : ajouter l'index collection-group `events.plannedAt`.
- `docs/notifications-apns-configuration.md` : comportement et mise en service.
- `docs/plans/2026-09-13-expiration-evenements-apres-debut.md` : suivi et preuves.
- Dans le vault `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  - `Backlog features.md` : suivi du nettoyage automatique.
  - `Documentation technique.md` : cycle de vie, transactions et index.
  - `Documentation UX.md` : disparition après l'heure de début.
  - `00 - Wander.md` : résumé du comportement et de sa mise en service.

Les notes Obsidian conserveront leurs wikilinks et recevront une propriété
`updated` à jour. Aucun contrôle visuel dans Obsidian n'est prévu. Consigner
les éventuels constats de revue non résolus dans `todos/` avec leur priorité.

## Mise en œuvre

- [x] Enregistrer l'approbation explicite au statut `approved`.
- [x] Passer au statut `in_progress`.
- [x] Implémenter le nettoyage transactionnel.
- [x] Couvrir les limites, publications anciennes, reprogrammations et lots.
- [x] Ajouter l'index `plannedAt` en conservant `publishedAt` pour la transition.
- [x] Simplifier le changement et exécuter les validations locales.
- [x] Terminer la revue indépendante.
- [x] Déployer l'index, attendre sa disponibilité, puis déployer la fonction.
- [x] Vérifier l'état distant sans déclencher de purge manuelle supplémentaire.
- [x] Mettre à jour les cinq documents de comportement et le présent plan.

## Risques et décisions

- La sélection et la suppression d'un lot utilisent une même transaction pour
  éviter la suppression d'un événement reprogrammé entre les deux opérations.
  Les compteurs sont incrémentés uniquement après une transaction validée.
- L'index `plannedAt` doit être prêt avant l'activation de la nouvelle requête.
  L'index `publishedAt` reste disponible pour la fonction précédente.
- Le cron peut être retardé en cas d'incident ; 12 à 13 heures est le délai
  normal, pas une garantie de disponibilité du service.
- Les suppressions déjà effectuées par l'ancienne règle ne sont pas restaurées.
- Les quatre notes Obsidian sont hors des racines d'écriture par défaut :
  demander l'escalade nécessaire, déjà couverte par l'approbation du plan.
  En cas de refus, noter précisément les sections restant à mettre à jour.

## Validation et critères d'acceptation

- `npm --prefix functions test` compile le backend et exécute les tests.
- Avec le JDK 21 déjà installé, lancer l'émulateur Firestore du projet
  `demo-wander` et cette même suite pour les tests d'intégration.
- Début exactement 12 heures auparavant : supprimé ; une milliseconde plus
  récent : conservé. Une publication ancienne ne supprime pas un début futur.
- Un changement de publication ne prolonge pas un début expiré. Une
  reprogrammation confirmée vers le futur protège l'événement.
- Vérifier plusieurs propriétaires, plus de 500 événements et l'idempotence.
- Vérifier la protection transactionnelle contre une modification simultanée.
- Relire le diff et les notes, conserver la cadence horaire et le trigger des
  réponses ; vérifier l'index prêt et la version de la fonction déployée.
- Aucun test iOS n'est requis pour ce changement exclusivement backend.

## Résultats et revue

- Régression rouge observée sur Firestore Emulator avant correction : l'ancien
  filtre `publishedAt` conservait les événements expirés et supprimait les
  événements futurs malgré les attentes du test. Échec attendu, code de sortie 1.
- `npm --prefix functions run build` : compilation réussie.
- `FIRESTORE_EMULATOR_HOST=127.0.0.1:8980 node --test functions/lib/eventCleanupLogic.test.js` :
  6 tests réussis, aucun ignoré. La reprise concurrente injecte `ABORTED` après
  la lecture, effectue une vraie reprogrammation et vérifie le prochain essai.
- `FIRESTORE_EMULATOR_HOST=127.0.0.1:8980 npm --prefix functions test` :
  52 tests réussis, 0 échec, 0 ignoré ; compilation TypeScript incluse.
  Journal : `/tmp/wander-event-expiry-tests.log`.
- L'émulateur a été lancé avec le JDK 21 explicitement placé dans `PATH` et
  `JAVA_HOME`, sur le port 8980 et le projet `demo-wander`. Les tests isolent
  leurs données dans des projets locaux `demo-*`.
- `git diff --check` sur les fichiers du correctif : réussi.
- `ce-simplify-code` : trois passes, aucun changement retenu. La suggestion
  de partager la constante 500 entre modules a été écartée : elle n'enlève
  aucune logique dupliquée et ajouterait un couplage sans bénéfice fonctionnel.
- Déploiement de `firestore:indexes` réussi le 13 septembre 2026. L'ancien
  index `publishedAt` est préservé. Le nouvel index `plannedAt` est confirmé
  `READY` à 10:10:14 UTC, avant le déploiement de la fonction.
- État distant initial : fonction active, révision
  `cleanupexpiredevents-00002-jal`, dernière mise à jour le 22 août 2026 ; cron
  activé, `every 60 minutes`, UTC. Aucun document de production n'a été lu.
- `ce-code-review` terminé sans constat actionnable : deux sous-revues
  indépendantes de logique et tests, complétées par les passes locales sur
  performances, fiabilité, risques, conventions et connaissances existantes.
  Reçu : `/private/tmp/wander-event-cleanup-review-xhzs08ib`.
- Capitalisation : les tests, le commentaire transactionnel et la documentation
  décrivent déjà le raisonnement réutilisable ; aucune nouvelle note de solution
  n'est nécessaire pour cette correction.
- `firebase deploy --config firebase.json --project wander-1954f --only functions:cleanupExpiredEvents --non-interactive`
  via le CLI local : réussi, avec compilation avant déploiement.
- État distant confirmé à 10:17:00 UTC le 13 septembre : index `plannedAt`
  et `publishedAt` tous deux `READY`, fonction `ACTIVE`, révision
  `cleanupexpiredevents-00003-cil`, mise à jour à 10:16:37 UTC,
  hash `0d35a71466cf7c2e123c8a9b165620ce95435fa8`.
- Le cron reste `ENABLED`, `every 60 minutes`, UTC. La prochaine exécution
  annoncée après déploiement est le 13 septembre à 11:16 UTC, soit 20:16 à
  Séoul. Aucune purge manuelle n'a été déclenchée ; une exécution planifiée
  de cette nouvelle révision n'a pas encore été observée pendant cette tâche.
  Le contrôle distant vérifie la mise en service, les tests sur émulateur
  vérifient les suppressions et la protection des reprogrammations.
- Les quatre notes Obsidian ont été mises à jour après ces confirmations,
  avec `updated` au 13 septembre 2026. Leurs wikilinks sont inchangés et le
  contenu relu après écriture. L'escalade d'écriture autorisée a réussi ;
  aucune note n'a été dupliquée ni ouverte dans Obsidian.
- L'émulateur a été arrêté proprement après validation. Aucun test iOS,
  aucune commande Git mutante et aucun déploiement d'autre fonction effectués.
- Revue finale : critères d'acceptation remplis, aucun constat non résolu à
  ajouter à `todos/`. Les travaux iOS préexistants restent hors du correctif.

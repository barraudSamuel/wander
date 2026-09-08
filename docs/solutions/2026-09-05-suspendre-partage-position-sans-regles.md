---
title: "Suspendre le partage sans laisser passer les écritures en vol"
date: 2026-09-05
category: architecture
module: "Partage de position"
problem_type: architecture_pattern
component: service_layer
severity: high
applies_when:
  - "Plusieurs clients publient la même position avec des règles inchangées"
  - "Une préférence persistée doit survivre aux erreurs et changements de compte"
tags: [solution, privacy, firestore, concurrency, ghost-mode]
related_plan: "../plans/2026-09-05-mode-fantome.md"
---

# Suspendre le partage sans laisser passer les écritures en vol

## Context

Le mode fantôme doit retirer la position des amis tout en continuant
l'exploration locale. Masquer le marqueur ou arrêter le prochain envoi laisse
la dernière position lisible et ne neutralise pas une publication déjà lancée
par l'app ou son extension. Les cellules H3 constituent aussi une information
de déplacement, bien qu'elles servent à la sauvegarde personnelle.

## Guidance

Enregistrer le statut et supprimer la position dans une transaction. Chaque
publication relit le profil dans sa propre transaction et vérifie la révision
de partage capturée au départ. Si une activation intervient entre lecture et
commit, Firestore relance la transaction ; le nouveau statut bloque l'écriture.
Changer également la révision à la désactivation interdit à un ancien envoi
de profiter du retour à l'état visible. La date de reprise filtre les mesures
anciennes, y compris dans le cache des lecteurs.

Une intention persistée nécessite une seconde protection : son identifiant
rend une répétition idempotente, mais ne prouve pas qu'elle reste actuelle.
Conserver les révisions sur lesquelles elle pouvait s'appliquer, sans les
remplacer à la réception d'un nouveau snapshot. Une révision tierce produit un
conflit explicite. Les révisions des demandes locales précédentes restent
admises pour qu'une bascule rapide suive correctement un envoi local en vol.

Un acquittement retire l'intention même si la relecture échoue. Mémoriser le
choix acquitté pour l'interface, tout en bloquant la publication jusqu'à une
confirmation serveur du statut courant.

## Why This Matters

Le booléen seul ne distingue pas deux périodes visibles séparées par une
période invisible. L'identifiant de demande seul ne distingue pas un retry
légitime d'une vieille désactivation qui écraserait le choix d'un autre appareil.
Ces contrôles traitent deux courses différentes.

## When to Apply

- Appliquer le même contrat à tous les publishers, y compris les extensions.
- Suspendre les nouvelles cellules si elles partagent une information de lieu ;
  expliquer que leur sauvegarde distante est différée.
- Invalider l'identité de chaque listener retiré : l'existence d'un nouvel
  abonnement ne doit pas autoriser les anciens callbacks.

## Examples

Les tests `firebase-tests/tests/ghost-mode.test.mjs` provoquent de vraies
relances Firestore pour vérifier les publications et changements concurrents.
Ils exécutent une fixture JavaScript du protocole, pas les services Swift.
`wanderTests/GhostModeTests.swift` couvre l'état natif et ses politiques.
Les preuves exécutées et limites de validation figurent dans le plan lié.

La garantie reste celle des clients à jour : sans nouvelle règle serveur,
une ancienne app du propriétaire peut republier. Aucun client ne peut effacer
rétroactivement une copie déjà reçue par un ami.

## Related

- [Commit et confirmation Firestore](2026-09-01-separer-commit-et-confirmation-firestore.md)
- [Listeners après révocation](2026-08-15-revocation-listeners-firestore.md)
- [Synchronisation personnelle et vues sociales](2026-08-23-separer-synchronisation-personnelle-et-vues-sociales.md)

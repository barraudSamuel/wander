---
id: "021"
title: "Simplifier les règles Firestore autour des autorisations"
status: done
priority: P2
source: product-owner
created: 2026-09-01
resolved: 2026-09-01
tags: [todo, firebase, firestore, security, refactor]
---

# Simplifier les règles Firestore autour des autorisations

## Finding

Les règles Firestore combinaient autorisation, schéma exact, formats,
timestamps et cohérence entre documents. Une évolution légitime du payload ou
un nouveau listener pouvait ainsi provoquer `permission-denied` même lorsque
la relation sociale autorisait l'accès.

L'assouplissement devait conserver deux frontières produit : un non-ami ne voit
pas les données de carte ou les sorties d'un compte, et seul un ami accepté de
l'organisateur peut répondre à une sortie.

## Evidence

- L'ancien `firestore.rules` comptait 1 048 lignes et de nombreux prédicats de
  forme imbriqués avec les décisions d'accès.
- Les listeners personnels `attendees` et `declines` pouvaient rendre toute la
  commande « Participation indisponible » si une seule lecture était refusée.
- La validation exacte des champs obligeait à coordonner chaque évolution de
  modèle entre le client et les règles déployées.

## Acceptance criteria

- [x] Exiger une session Firebase pour tout accès client.
- [x] Refuser aux étrangers et aux relations `pending` ou `revoking` l'accès
      aux positions, explorations, sorties, groupes et réponses.
- [x] Réserver l'acceptation d'une amitié au destinataire et rendre l'identité
      de la paire immuable.
- [x] Limiter les écritures au propriétaire du chemin ou à l'auteur de la
      réponse, sans permettre d'usurper un autre UID.
- [x] Garder les tokens d'appareil privés et les documents backend interdits
      aux clients.
- [x] Permettre l'évolution des payloads sans allowlist exacte de champs,
      regex, catalogue ou comparaison de timestamps dans les règles.
- [x] Autoriser les deux listeners personnels et les listes de groupe pour les
      amis acceptés, sans filtre de publication imposé par les règles.
- [x] Refuser toute réponse rattachée à un événement absent.
- [x] Valider la matrice avec l'émulateur Firestore et documenter la décision.

## Resolution notes

Résolu localement le 2026-09-01 par
`docs/plans/2026-09-01-simplifier-regles-firestore.md` :

- les règles sont passées de 1 048 à 282 lignes et se concentrent sur
  authentification, propriété, consentement social et identité de l'auteur ;
- les validations de forme sans rôle d'autorisation ont été retirées ;
- 37/37 tests réussissent avec l'émulateur Firestore et JDK 21 ;
- le build Debug générique iOS réussit, avec seulement les avertissements de
  versions d'extensions déjà présents avant ce travail ;
- la décision réutilisable est consignée dans
  `docs/solutions/2026-09-01-separer-autorisation-et-schema-firestore.md`.

Aucune règle n'a été déployée et aucune donnée distante n'a été modifiée. La
validation sur plusieurs comptes reste à effectuer après un déploiement
séparément approuvé. Les quatre notes Obsidian listées dans le plan restent à
mettre à jour, car le vault est présent mais non inscriptible depuis cet
environnement.

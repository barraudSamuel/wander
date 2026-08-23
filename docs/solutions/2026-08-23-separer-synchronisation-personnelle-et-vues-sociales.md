---
title: "Séparer la synchronisation personnelle des vues d'exploration sociales"
date: 2026-08-23
tags: [solution, firestore, synchronization, friends, performance]
related:
  - "../plans/2026-08-23-carte-exploration-personnelle.md"
---

# Séparer la synchronisation personnelle des vues d'exploration sociales

## Problème

Attacher au démarrage un listener non borné à la collection de cellules de
chaque ami charge toutes les explorations sociales, même lorsque l'écran ne les
affiche pas. Le coût de lecture croît alors avec le nombre cumulé de cellules de
tous les amis et se répète lors de certaines nouvelles écoutes ou reconnexions.

## Solution retenue

Conserver deux responsabilités distinctes :

- la synchronisation de l'exploration du compte connecté reste permanente afin
  de restaurer sa scratch map et d'envoyer ses nouvelles cellules ;
- aucune exploration d'ami n'est observée par le socle social tant qu'aucune vue
  produit explicite ne la demande.

La carte, les profils et les résumés d'amis ne transportent donc plus de modèle,
de progression ou de compteur de cellules sociales. Les profils, positions,
sorties et itinéraires restent indépendants et continuent de fonctionner.

## Pourquoi cette séparation fonctionne

- La carte principale ne dépend que de données personnelles déjà nécessaires.
- Le nombre d'amis n'augmente plus le coût de lecture des cellules au démarrage.
- Les données Firestore existantes restent intactes pour de futures vues par ami
  ou mixtes.
- Une future vue sociale pourra définir sa propre stratégie de chargement,
  d'expiration et de cache sans alourdir le bootstrap global.

## Garde-fous

- Ne pas réintroduire un listener de cellules dans la réconciliation globale des
  amitiés.
- Déclencher les futures lectures sociales uniquement depuis une vue explicite,
  puis retirer son listener à la fermeture.
- Conserver un état de chargement propre à chaque vue sociale au lieu de le
  publier globalement dans `FriendSyncService`.
- Mesurer séparément le premier chargement, les mises à jour et les reconnexions
  avant de choisir entre listener temps réel, requête ponctuelle ou cache local.

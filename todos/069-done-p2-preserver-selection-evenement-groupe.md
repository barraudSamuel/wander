---
id: "069"
title: Préserver la sélection d'un événement depuis un groupe
status: done
priority: P2
source: review
created: 2026-09-27
tags: [todo, map, events]
---

# Préserver la sélection d'un événement depuis un groupe

## Finding

La première implémentation du recentrage depuis la liste supprimait le callback
de sélection pour tout événement en attente. Or l'appui sur un membre d'un
groupe passe aussi par `center(on:)` puis `select`. Il aurait perdu l'ouverture
et le défilement de sa carte dans la liste.

## Résolution

`select` accepte une intention `silently`, désactivée par défaut. Les demandes
provenant de la sélection externe et du recentrage de la liste sont explicitement
silencieuses ; les appuis de groupe et indicateurs gardent le callback habituel.
Le coordinateur vérifie `isSilentPendingSelection` avant de relayer le callback
vers `ContentView`. Une demande utilisateur pour le même événement en attente
remplace l'intention silencieuse.

- [x] Sélection silencieuse explicitement limitée au chemin prévu.
- [x] Demande utilisateur par `center(on:)` non silencieuse.
- [x] Test de régression ajouté au contrôleur.

Plan : [Recentrage depuis la liste](../docs/plans/2026-09-27-recentrage-depuis-liste-evenements.md).
Revue initiale : `/tmp/wander-list-center-review/review.json`.
L'exécution des tests reste non vérifiée sans simulateur actif ; compilation
et revue finale sont consignées dans le plan.

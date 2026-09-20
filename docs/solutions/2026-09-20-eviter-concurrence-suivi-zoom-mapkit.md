---
title: Éviter le dézoom puis rezoom au recentrage MapKit
date: 2026-09-20
category: architecture
tags: [solution, mapkit, camera]
related_plan: ../plans/2026-09-20-recentrage-zoom-carte.md
---

# Éviter le dézoom puis rezoom au recentrage MapKit

## Symptôme et diagnostic

Le second appui sur le recentrage dézoomait avant de revenir au zoom voulu.
Le parcours combinait `setUserTrackingMode(.follow, ...)` et `setRegion`.
Deux politiques pouvaient donc modifier la caméra. Ajouter des gardes autour
de `.follow` n’a pas suffi : Samuel a reproduit le problème après ce correctif.
Le détail des transitions internes de MapKit n’a pas été instrumenté.

## Résolution

`MapUserCameraController`, dans `wander/MapWithFogView.swift`, possède le
recentrage et le suivi utilisateur. Un appui applique une région de 800 mètres ;
les positions suivantes déplacent seulement le centre. Ce parcours n’active
plus le suivi natif MapKit. Les appuis redondants sont ignorés, les positions
reçues pendant l’animation sont regroupées, et un geste ou un cadrage social
arrête le suivi. Le suivi suit la cadence existante de `LocationTracker`.

## Preuves et limites

- Application et six tests MapKit compilés avec `build-for-testing`.
- Samuel a refusé le démarrage du simulateur et préféré son iPhone.
- Après les deux tentatives invalidées, il confirme la dernière version avec
  « c good mtn », le 20 septembre 2026.
- Les tests automatisés n’ont pas été exécutés et les scénarios secondaires
  ne sont pas confirmés individuellement.

## Prévention

Pour un zoom imposé par le produit, conserver un seul propriétaire des
commandes de caméra. Comparer le cadrage avant toute mutation. Vérifier le
second appui en exécution : une compilation ne prouve pas l’absence d’un
mouvement intermédiaire. Les tests de `MapUserCameraControllerTests` couvrent
ces commandes et l’absence de réactivation du suivi natif.

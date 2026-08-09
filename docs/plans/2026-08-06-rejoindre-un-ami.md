---
title: "Rejoindre un ami avec une application de navigation"
status: completed
date: 2026-08-06
owner: "Codex"
related: []
tags: [plan, map, friends, navigation]
---

# Rejoindre un ami avec une application de navigation

## Outcome

Depuis la carte, toucher le marqueur d’un ami permet d’utiliser une action
« Rejoindre » qui ouvre un itinéraire vers sa dernière position connue dans
Google Maps ou, lorsque disponible en Corée, dans Naver Map.

Le parcours est réussi lorsque l’action reste native et accessible, conserve
la copie d’adresse existante, ne demande aucune clé d’API cartographique et
navigue uniquement vers la coordonnée affichée dans la callout.

## Context

- `wander/MapWithFogView.swift` construit les annotations d’amis, leur callout
  et contient déjà la coordonnée et l’horodatage de la dernière position.
- `wander/ContentView.swift` possède l’état SwiftUI approprié pour présenter un
  `confirmationDialog` natif au-dessus de la carte.
- Google Maps fournit des URLs universelles d’itinéraire ; Naver Map fournit le
  schéma `nmap://` et limite ses coordonnées documentées à la Corée.

## Scope

- Included:
  - bouton « Rejoindre » dans la callout des amis seulement ;
  - choix Google Maps et Naver Map dans un dialogue natif ;
  - itinéraire Google depuis la position courante vers l’ami ;
  - itinéraire à pied Naver lorsque l’application est installée et la
    destination appartient à sa zone de coordonnées documentée ;
  - mention explicite de la date de la dernière position ;
  - détection du schéma Naver via `Info.plist`.
- Not included:
  - calcul ou affichage de l’itinéraire à l’intérieur de Wander ;
  - ajout d’une API Google/Naver ou d’une clé payante ;
  - suivi prédictif d’un ami en déplacement ;
  - modification du partage Firebase ou des règles Firestore.

## Proposed approach

La vue d’annotation conserve la responsabilité de rendre la callout et expose
une fermeture d’action uniquement pour les annotations d’amis. Le coordinateur
MapKit transforme la callout en une destination immuable (nom, coordonnée,
horodatage), puis remonte cette destination à `ContentView`.

`ContentView` présente ensuite un `confirmationDialog`. L’URL Google est
construite avec `URLComponents` et l’URL Naver avec ses paramètres officiels.
Le schéma universel Google fournit un repli navigateur automatique. Naver est
masqué si `canOpenURL` échoue ou si la destination est hors de Corée.

## Affected files

- `wander/MapWithFogView.swift` — bouton, destination et propagation de
  l’action depuis MapKit.
- `wander/ContentView.swift` — dialogue et ouverture des applications.
- `wander/Info.plist` — autorisation de vérifier le schéma `nmap`.
- `docs/plans/2026-08-06-rejoindre-un-ami.md` — suivi et validation.

## Implementation

- [x] Ajouter le bouton accessible à la callout des amis sans modifier celle de
      l’utilisateur.
- [x] Remonter une copie de la dernière destination sélectionnée à SwiftUI.
- [x] Construire et ouvrir les URLs Google Maps et Naver Map.
- [x] Déclarer `nmap` parmi les schémas interrogeables.
- [x] Compiler et relire le diff selon les risques UI, confidentialité et
      accessibilité.

## Edge cases and risks

- L’ami bouge après le toucher — conserver et annoncer l’horodatage de la
  coordonnée utilisée, sans prétendre suivre une destination dynamique.
- Naver n’est pas installé — masquer son action plutôt que rediriger
  involontairement vers l’App Store.
- Destination hors de Corée — masquer Naver car ses plages de coordonnées
  officielles sont limitées.
- Google Maps n’est pas installé — utiliser son URL universelle, qui se replie
  sur le navigateur.
- Coordonnée invalide — ne pas rendre l’action « Rejoindre ».

## Validation

- [x] Le build simulateur Debug réussit sans nouvelle erreur ni avertissement.
- [x] Une inspection confirme que l’utilisateur local n’obtient pas le bouton.
- [x] Une inspection confirme que la copie d’adresse reste disponible.
- [x] Les URLs encodent correctement les coordonnées, le nom et le bundle ID.
- [x] Le dialogue décrit clairement qu’il s’agit de la dernière position connue.
- [x] L’apparence native, l’accessibilité et Dynamic Type sont préservés par les
      contrôles système.

## Review notes

- Hardest decision: Naver ne documente pas de route générique laissant choisir
  le mode après ouverture. Le trajet à pied correspond le mieux à l’exploration
  Wander et son libellé rend ce choix explicite.
- Rejected alternatives: intégrer un moteur d’itinéraire dans Wander aurait
  ajouté des clés, coûts et responsabilités inutiles ; un schéma Google privé
  aurait supprimé le repli navigateur ; afficher Naver hors couverture ou sans
  installation aurait présenté une action vouée à échouer.
- Least certain: le passage inter-app Naver ne peut être exercé complètement
  sans appareil disposant de Naver Map et d’un ami actif en Corée. Sa structure
  d’URL, son encodage, sa déclaration dans le plist et le build ont été validés.

La revue n’a relevé aucun problème restant à enregistrer dans `todos/`. Aucun
identifiant d’authentification ni aucune coordonnée n’est journalisé, et les
données Firebase ainsi que les règles Firestore ne sont pas modifiées.

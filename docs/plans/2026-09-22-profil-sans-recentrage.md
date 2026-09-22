---
title: Ouvrir le profil depuis le bouton sans déplacer la carte
status: completed
completed_at: 2026-09-22T14:18:36+09:00
date: 2026-09-22
---

Samuel a explicitement approuvé le plan présenté dans la conversation.

## Périmètre

Distinguer le bouton profil du pin personnel. Le bouton ouvre la même fiche
sans recentrage à l’ouverture ou à la fermeture. Le pin conserve son comportement.
Fichiers : ContentView.swift, DebugSocialMapScenario.swift, MotionDockUITests.swift
et ce plan ; note Obsidian `wander/Documentation UX.md` dans le vault existant.
Conserver les gardes des actions du compte et les fiches amis.

## Étapes

- [x] Distinguer la source d’ouverture et conditionner les deux demandes caméra.
- [x] Couvrir la conservation de la position de la carte dans le test de navigation.
- [x] Actualiser la note UX.
- [x] Compiler app/tests et revoir le diff isolé.

## Validation et risques

Vérifier ouverture/fermeture depuis le bouton après déplacement manuel de la carte,
et préserver le recentrage du pin. Attention à la réutilisation de l’état entre
plusieurs ouvertures. Compiler avec build-for-testing. Validation en exécution
uniquement sur l’iPhone 17 déjà démarré ; ne démarrer aucun autre appareil.

## Résultat, revue et validation

Le bouton passe `focusOnMap: false`, le pin `true`. La même valeur conditionne
la préparation de la caméra et le recentrage après fermeture. Une nouvelle ouverture
réinitialise explicitement cette valeur. La garde de sélection empêche le rappel
MapKit d’une sélection programmée de modifier le choix pendant la fiche.
Les gardes du compte et les demandes caméra des amis restent en place.

Revue locale du diff isolé : ouverture, fermeture, réouverture et rappel MapKit
inspectés ; simplification sans abstraction supplémentaire. Aucun finding restant.
Le test existant déplace la carte puis observe un marqueur pendant une seconde
à l’ouverture et après fermeture pour détecter un recentrage différé.

`xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build-for-testing` : **TEST BUILD SUCCEEDED**.
Journal : `/tmp/wander-profile-no-focus-build.log`. `git diff --check` réussi.
Tests UI compilés mais non exécutés : seul l’iPhone 16e est démarré, pas l’iPhone 17.
Aucun appareil démarré ou application installée. Note UX Obsidian mise à jour.
Messages de build hors correctif : extraction AppIntents et, lorsqu’émis,
versions des extensions différentes de celle de l’app. Aucun fichier de version modifié ici.

Point à retenir : ouvrir une fiche peut sélectionner son annotation dans MapKit,
qui rappelle ensuite le gestionnaire du pin. Celui-ci doit être idempotent pour
préserver l’intention de l’ouverture en cours. Cette garde est documentée dans le code.

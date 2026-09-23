---
id: "061"
title: "Valider les invitations depuis le profil personnel"
status: ready
priority: P2
source: review
created: 2026-09-22
tags: [todo, profile, friends, validation]
---

## Constat

Les sections « Ton code ami » et « Ajouter un ami » ont été déplacées d’Amis
vers le profil personnel. L’application et les deux cibles de tests compilent.
Les tests UI ont été adaptés mais ne sont pas exécutés : seul un iPhone 16e
est démarré, alors que les instructions du projet autorisent l’iPhone 17.

Le scénario local valide uniquement la navigation, les contrôles et la saisie.
Il ne remplace pas une validation avec un compte réel pour les états Firebase.

## Critères d’acceptation

- [ ] Sur l’iPhone 17, exécuter le test existant adapté
  `MotionDockUITests/testFriendInvitationsLiveInProfileAndDraftSurvivesClosing`.
- [ ] Vérifier depuis le bouton et le pin personnels : expansion, défilement,
  clavier, fermeture et réouverture sans perte de saisie.
- [ ] Vérifier la copie et l’ouverture de la feuille de partage du code personnel.
- [ ] Avec des comptes de test, vérifier succès, code invalide ou introuvable,
  profil en préparation, code indisponible et nouvelle tentative.
- [ ] Vérifier l’absence des deux sections dans Amis, tout en conservant les
  demandes reçues, les invitations en attente et les amis acceptés.

## Références

- Plan : `docs/plans/2026-09-22-code-ami-profil.md`.
- Compilation : `/tmp/wander-friend-profile-build.log`, `TEST BUILD SUCCEEDED`.

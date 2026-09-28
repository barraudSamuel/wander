---
id: "061"
title: "Valider les invitations depuis le profil personnel"
status: ready
priority: P2
source: review
created: 2026-09-22
updated: 2026-09-28
tags: [todo, profile, friends, validation]
---

## Constat

Les sections « Ton code ami » et « Ajouter un ami » se trouvent dans le profil.
Depuis le 27 septembre, elles suivent aussi les demandes reçues, les amis et
les demandes envoyées. L’application et les tests compilent. Le test de saisie
et de conservation du brouillon a réussi sur l’iPhone 17 déjà démarré.

Le scénario local valide uniquement la navigation, les contrôles et la saisie.
Il ne remplace pas une validation avec un compte réel pour les états Firebase.

## Critères d’acceptation

- [x] Sur l’iPhone 17, exécuter le test existant adapté
  `MotionDockUITests/testFriendInvitationsLiveInProfileAndDraftSurvivesClosing`.
- [ ] Vérifier depuis le bouton et le pin personnels : expansion, défilement,
  clavier, fermeture et réouverture sans perte de saisie.
- [ ] Vérifier la copie et l’ouverture de la feuille de partage du code personnel.
- [ ] Avec des comptes de test, vérifier succès, code invalide ou introuvable,
  profil en préparation, code indisponible et nouvelle tentative.
- [x] Réunir demandes, amis, code et ajout dans le profil ; supprimer le bouton Amis.

## Références

- Plan : `docs/plans/2026-09-22-code-ami-profil.md`.
- Plan actuel : `docs/plans/2026-09-27-amis-dans-profil.md`.
- Parcours du brouillon : `/tmp/wander-friends-profile-final-tests.log`.
- Compilation : `/tmp/wander-friend-profile-build.log`, `TEST BUILD SUCCEEDED`.

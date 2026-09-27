---
title: "Ouvrir les réglages depuis l'encart du profil"
status: completed
date: 2026-09-27
completed_at: 2026-09-27T16:51:31+09:00
owner: Samuel
tags: [plan, profile, ux, settings]
---

# Ouvrir les réglages depuis l'encart du profil

## Outcome

Le profil personnel affiche une roue dans un encart intégré en haut à gauche de la carte d'identité, dans le même langage visuel que l'encart du pseudo. Un appui ouvre une bottom sheet native « Réglages » ; sa fermeture revient au profil. Les réglages actuels quittent le formulaire principal, tandis que le code ami et l'ajout d'ami y restent.

## Scope

- Inclus : encart et action sur le seul profil personnel, déplacement des sections Carte, Identité, Visibilité, Localisation, Notifications et Compte dans une feuille native, confirmations de compte, scénario local, tests ciblés, documentation UX et backlog.
- Exclus : profil ami, règles métier et persistance des réglages, catalogue d'avatars, nouveau système de navigation.
- Dépendances : `MapProfileIdentityView`, `OwnProfileSheet`, `ProfilePanelView` et le sélecteur d'avatar déjà présent.

## Affected files

- `wander/FriendProfileSheet.swift` : encart de la roue dans l'identité partagée, facultatif et absent du profil ami.
- `wander/OwnProfileSheet.swift` : état et action d'ouverture de la feuille de réglages.
- `wander/ProfilePanelView.swift` : déplacement des sections existantes dans la feuille et conservation des actions de compte.
- `wander/ContentView.swift` : passage de la liaison de présentation au formulaire personnel.
- `wander/DebugSocialMapScenario.swift` : scénario local équivalent pour validation visuelle et fonctionnelle.
- `wanderUITests/MapSocialGestureUITests.swift` : parcours ciblé d'ouverture, fermeture et contenu des réglages.
- Ce plan et, uniquement si un défaut résiduel est confirmé, un fichier priorisé dans `todos/`.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md` : état de la fonctionnalité.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md` : parcours et emplacement des réglages.

## Implementation

- [x] Ajouter l'encart supérieur gauche avec SF Symbol, cible tactile native et action facultative dans l'identité du profil.
- [x] Présenter la feuille « Réglages » et déplacer les sections sans dupliquer leur logique.
- [x] Conserver les alertes et la feuille d'autorisation de suppression au-dessus des réglages, avec protection contre une fermeture pendant les opérations de compte.
- [x] Adapter le scénario local et le test UI ciblé.
- [x] Mettre à jour les deux notes Obsidian concernées et leur propriété `updated`.
- [x] Compiler, vérifier sur l'iPhone 17 déjà démarré, exécuter les tests ciblés, relire le diff et consigner les résultats.

## Risks

- La feuille de réglages est présentée depuis un contenu hébergé dans la feuille de profil ; vérifier sa superposition, son retour et l'absence de fermeture du profil.
- Les confirmations et l'autorisation Apple de suppression doivent rester au premier plan et bloquer les dismissals concurrents.
- L'encart doit rester lisible sur l'image, ne pas masquer l'avatar et ne pas modifier le palier compact de manière inattendue.
- Les fiches d'amis conservent une identité non interactive.

## Validation and acceptance

- Compilation Debug et des tests sans nouveau diagnostic Swift ; `git diff --check`.
- Sur l'iPhone 17 déjà démarré : ouverture depuis le bouton carte et le pin, roue visible et cliquable, feuille « Réglages » native, sections présentes, fermeture vers le profil et feuille d'avatar toujours indépendante. Vérifier palier compact, palier agrandi et bas de la feuille.
- Test UI ciblé d'ouverture, fermeture et réouverture des réglages ; test existant de l'avatar ; contrôle des actions et confirmations de compte sans les exécuter jusqu'à suppression réelle.
- Aucun autre simulateur démarré. Ne pas lancer de tests d'accessibilité dédiés.

## Review notes

- Plan présenté dans la conversation et approuvé explicitement par Samuel le 27 septembre 2026 : « je vlaide ».
- Les compétences Compound Engineering mentionnées par `AGENTS.md` ne sont pas disponibles ; appliquer Plan → Work → Review → Compound manuellement.
- Choix de portée : la feuille séparée devient le lieu des réglages déjà présents ; le code ami et l'ajout d'ami restent dans le profil.
- `xcodebuild ... build-for-testing` : réussite le 27 septembre 2026, sans nouveau diagnostic Swift. Avertissements existants d'extraction AppIntents et de versions d'extensions.
- Trois tests UI ciblés exécutés sur l'iPhone 17 déjà démarré : réglages, avatar et profil d'ami ; 3 réussites, 0 échec. `git diff --check` réussi.
- Scénario local observé en modes sombre et clair : encart et roue, palier compact et grand palier, bas de la feuille, ouverture et fermeture des réglages, confirmation de test et fermeture désactivée pendant la confirmation. Apparence sombre initiale rétablie.
- Les deux notes Obsidian prévues sont mises à jour avec leur propriété `updated`. Aucun défaut résiduel confirmé lors de cette revue, donc aucun fichier `todos/` ajouté.
- Limite : le scénario local ne couvre pas la synchronisation avec un compte connecté ni les opérations réelles de déconnexion et de suppression Apple ; ces parcours restent dans le backlog de validation.

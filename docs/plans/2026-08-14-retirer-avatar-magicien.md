---
title: "Retirer l'avatar magicien"
status: completed
date: 2026-08-14
completed_at: 2026-08-14
owner: "Samuel Barraud"
related:
  - "2026-08-14-avatars-predéfinis.md"
tags: [plan, profile, avatars, firestore]
---

# Retirer l'avatar magicien

## Outcome

Le magicien ne fait plus partie des avatars proposés. Le catalogue contient 12
avatars et un compte qui avait sélectionné `wizard` reçoit automatiquement un
autre avatar valide lors de sa prochaine synchronisation.

## Scope

- Included:
  - suppression de l'imageset du magicien ;
  - retrait de l'identifiant Swift et de la liste autorisée Firestore ;
  - adaptation des tests et de la documentation ;
  - migration par le mécanisme existant des identifiants inconnus.
- Not included:
  - modification des 12 autres images ;
  - déploiement des règles Firestore.

## Affected files

- `wander/Assets.xcassets/AvatarWizard.imageset` — suppression.
- `wander/ProfileAvatar.swift` — retrait du cas `wizard`.
- `firestore.rules` — retrait de l'identifiant autorisé.
- `firebase-tests/tests/profile-avatar.rules.test.mjs` — nouvel avatar valide.
- `docs/solutions/2026-08-14-synchroniser-avatars-embarques.md` — catalogue à
  12 éléments.
- `todos/004-done-p2-sync-profile-avatar.md` — nombre actuel d'avatars.

## Implementation

- [x] Supprimer l'asset et le cas Swift.
- [x] Retirer `wizard` des règles et adapter les tests.
- [x] Vérifier la migration vers un avatar valide.
- [x] Construire, tester et relire le diff.

## Risks

- Profil distant existant avec `wizard` — le traiter comme identifiant inconnu,
  conserver la valeur aléatoire générée localement et la synchroniser.
- Ancienne version de l'app — ses tentatives de sélectionner `wizard` seront
  refusées après le déploiement des nouvelles règles.

## Validation

- [x] Le catalogue et la grille contiennent exactement 12 avatars.
- [x] `wizard` et `AvatarWizard` ne subsistent dans aucun code ou règle actif.
- [x] Les tests Firestore réussissent.
- [x] Le build Debug pour simulateur réussit.
- [x] `git diff --check` réussit.

## Acceptance criteria

- [x] Le magicien n'est plus visible ni sélectionnable.
- [x] Un ancien profil `wizard` converge vers un identifiant valide.
- [x] Les 12 autres avatars restent inchangés.

## Completed validation

- Build Debug silencieux pour le simulateur — succès, code de sortie 0.
- Suite Firestore — 22 tests réussis, aucun échec ; `wizard` est explicitement
  refusé par le test de création de profil.
- Recherche statique — 12 imagesets, aucun `wizard`, `AvatarWizard` ou
  `Magicien` dans le code et les règles actifs.
- Migration — `ProfileAvatar.normalizedID` rejette désormais `wizard` ; le flux
  d'hydratation conserve alors l'identifiant aléatoire valide du compte, marque
  `hasPendingAvatarChange` et le synchronise avec Firestore.
- iPhone 17 Simulator — 12 boutons d'avatar exposés à l'accessibilité et aucune
  entrée « Magicien ».
- Les 12 autres imagesets n'ont pas été modifiés.
- `git diff --check` et validation JSON des 12 imagesets — succès.

## Review notes

- Hardest decision: conserver une migration sûre pour un profil distant qui
  référence encore l'identifiant supprimé.
- Rejected alternatives: masquer seulement le magicien dans la grille, car son
  identifiant serait resté valide et synchronisable.
- Least certain: le déploiement des règles reste volontairement hors périmètre.

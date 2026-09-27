---
title: "Choisir son avatar depuis le profil personnel"
status: completed
completed_at: 2026-09-27T14:28:27+09:00
date: 2026-09-27
owner: Samuel
tags: [plan, profile, ux]
---

# Choisir son avatar depuis le profil personnel

## Outcome

Un appui sur l'avatar du profil personnel ouvre une feuille native de sélection. Le formulaire principal ne contient plus la grille des avatars. Le choix est appliqué et la feuille de sélection se ferme, tandis que le profil reste ouvert.

## Scope

- Inclus : profil personnel depuis le bouton carte et le pin, scénario local, sélection existante, présentation et documentation UX.
- Exclu : profil ami, catalogue d'avatars, modèle de données et synchronisation Firebase.
- Dépendances : fiche native existante et `ProfileAvatarPicker`.

## Affected files

- `wander/OwnProfileSheet.swift` : état et présentation de la feuille, sélection.
- `wander/FriendProfileSheet.swift` : action facultative sur l'avatar dans l'identité partagée.
- `wander/ProfilePanelView.swift` : retrait de la section Avatar.
- `wander/ContentView.swift` : binding de l'avatar à la fiche personnelle.
- `wander/DebugSocialMapScenario.swift` : comportement équivalent dans le scénario local.
- `wanderUITests/MapSocialGestureUITests.swift` : parcours fonctionnel de sélection.
- Ce plan et, seulement en cas de défaut restant, un fichier priorisé dans `todos/`.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md` : état et accès à la sélection dans le profil.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md` : parcours et comportement de la nouvelle feuille.

## Implementation

- [x] Ajouter l'action facultative sur le seul avatar personnel.
- [x] Présenter une feuille native avec le sélecteur existant, fermeture explicite et fermeture après choix.
- [x] Retirer la grille du formulaire et adapter les deux points d'entrée de la fiche.
- [x] Mettre à jour le scénario et un test UI fonctionnel.
- [x] Mettre à jour les notes Obsidian concernées et leur propriété `updated`.
- [x] Compiler, vérifier le parcours disponible, simplifier et relire le diff.

## Risks

- La fiche utilise un contrôleur de présentation UIKit : vérifier que la seconde feuille apparaît et revient à la fiche sans fermer celle-ci.
- Le composant d'identité est partagé : le profil ami doit rester non interactif.
- La sélection doit continuer de déclencher la persistance et la synchronisation déjà reliées à `avatarID`.

## Validation and acceptance

- Compilation Debug et des tests sans nouveau diagnostic Swift.
- Sur l'iPhone 17 déjà démarré, si accessible : ouverture du profil, appui sur l'avatar, sélection, retour au profil et réouverture ; contrôle que le profil ami ne propose pas l'édition.
- Aucun autre simulateur ne sera démarré. Si l'iPhone 17 ou le service Simulator est inaccessible, consigner précisément la limite et ne pas présenter les tests runtime comme exécutés.
- Vérifier la suppression de la section du formulaire, la disponibilité du bouton et la mise à jour des notes.

## Review notes

- Plan approuvé par Samuel dans la conversation le 27 septembre 2026 : « je valide ».
- Les compétences Compound Engineering demandées par `AGENTS.md` ne sont pas installées ; suivre leurs étapes manuellement.
- Avant implémentation, `xcrun simctl list devices booted` échoue car CoreSimulatorService est inaccessible dans ce contexte. Nouvelle vérification lors de la validation.

## Validation et revue

- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build-for-testing` : `TEST BUILD SUCCEEDED` après correction du binding utilisé par la suppression de compte. Journal : `/tmp/wander-avatar-sheet-build-final.log`.
- Aucun nouveau diagnostic Swift. Avertissements AppIntents et `CFBundleVersion` des extensions déjà présents lors des compilations précédentes.
- `git diff --check` : réussi. Lecture du diff : seule l'identité personnelle reçoit une action ; le profil ami conserve sa présentation sans action. Le formulaire conserve son binding `avatarID` pour l'effacement local lors de la suppression du compte.
- `xcrun simctl list devices booted` avec accès au service Simulator : aucun appareil démarré. Le test UI ajouté a été compilé, mais n'a pas été exécuté. Aucun simulateur n'a été démarré.
- `Backlog features.md` et `Documentation UX.md` mis à jour directement dans le vault, avec `updated` actualisé et wikilinks préservés. Obsidian n'a pas été ouvert.
- Décision principale : rattacher la seconde feuille à la fiche personnelle et réutiliser `ProfileAvatarPicker` pour conserver la sélection existante.
- Alternative écartée : rendre le composant partagé toujours cliquable, ce qui aurait ajouté une action aux profils d'amis.
- Incertitude restante : rendu et interaction des deux feuilles en exécution, faute d'iPhone 17 déjà démarré. Aucun défaut confirmé à consigner dans `todos/`, ni leçon réutilisable vérifiée à ajouter à `docs/solutions/`.

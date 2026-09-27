---
title: "Supprimer la bande blanche fixe au bas du profil"
status: completed
date: 2026-09-27
completed_at: 2026-09-27T16:25:12+09:00
owner: Samuel
tags: [plan, profile, ux, fix]
---

# Supprimer la bande blanche fixe au bas du profil

## Outcome

Le formulaire du profil personnel remplit la feuille jusqu'à son bord inférieur. La bande blanche fixe visible sous le fond gris disparaît ; le dernier contenu conserve un espace de fin dans la zone défilante.

## Context

Deux captures de Samuel montrent la même bande blanche au bas de la feuille à des positions de défilement différentes. Les deux extensions SwiftUI précédentes n'ont pas corrigé le rendu. Une reproduction dans le simulateur iPhone 17 confirme une bande fixe au bas du profil personnel, tandis que la feuille native de choix d'avatar remplit son bas correctement.

## Scope

- Inclus : configuration de la safe area du `UIHostingController` visible et de son `UIViewControllerRepresentable` dans la feuille SwiftUI, retrait du modifier SwiftUI devenu inutile, marge de fin défilante si nécessaire, validation visuelle sur le simulateur iPhone 17 déjà lancé, documentation UX.
- Exclus : choix d'avatar, contenu et actions des profils, changement des paliers de la feuille, autre appareil ou simulateur.

## Affected files

- `wander/FriendProfileSheet.swift` : configuration du contrôleur d'hébergement visible et retrait de l'extension SwiftUI inefficace.
- `wander/OwnProfileSheet.swift` : extension du representable jusqu'au bord de la feuille personnelle.
- `wander/ProfilePanelView.swift` : ajustement éventuel de la marge de fin du formulaire selon les captures.
- Ce plan et, seulement si un défaut est confirmé, un fichier priorisé dans `todos/`.
- `docs/solutions/2026-09-27-safe-area-representable-dans-feuille.md` : cause observée, correctif et validation réutilisables.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md` : description de la bande supprimée et de l'espace de fin ; propriété `updated`.

## Implementation

- [x] Configurer la safe area du `UIHostingController` visible et étendre le representable dans les deux fiches jusqu'au bord de la feuille, en conservant la gestion du clavier.
- [x] Retirer le modifier SwiftUI inefficace et conserver la marge de fin défilante.
- [x] Compiler, lancer le scénario de profil personnel sur l'iPhone 17 déjà démarré et comparer le haut et le bas avec la feuille d'avatar.
- [x] Mettre à jour la note UX et sa propriété `updated` d'après le rendu constaté.
- [x] Vérifier le diff, relever les éventuels défauts restants et consigner le résultat exact.

## Risks

- Le contenu ne doit pas passer sous les éléments système ; la marge de fin doit rester dans la surface défilante.
- L'extension ne doit pas déplacer le haut de la feuille, le palier compact ni le clavier.
- Une compilation ne prouve pas le rendu ; ne pas annoncer une correction visuelle vérifiée sans capture après changement.

## Validation and acceptance

- Compilation Debug de l'app et des tests sans nouveau diagnostic Swift ; `git diff --check` et revue ciblée.
- Captures sur l'iPhone 17 déjà lancé : en haut et tout en bas du profil personnel, la surface de la feuille continue jusqu'au bord arrondi sans bande fixe distincte ; le dernier contenu reste accessible ; le haut, le palier compact et la feuille d'avatar restent utilisables.

## Review notes

- Approche révisée explicitement approuvée par Samuel le 27 septembre 2026 : « je valide » après sa demande d'utiliser le simulateur et de viser la safe area native.
- Les compétences Compound Engineering mentionnées dans `AGENTS.md` ne sont pas installées ; suivre l'équivalent manuellement.
- Les changements locaux des plans précédents sont conservés.

## Validation et revue

- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build-for-testing` : `TEST BUILD SUCCEEDED`. Journal : `/tmp/wander-profile-sheet-root-bottom-build.log`.
- Aucun nouveau diagnostic Swift ; avertissements AppIntents préexistants.
- `git diff --check` : réussi. La racine `AnyView` du contenu visible ignore seulement la zone sûre inférieure du conteneur ; les deux vues filles ne le font plus séparément. Le `Form` personnel et le `ScrollView` ami conservent une marge de contenu de 16 points. La mesure compacte reste distincte et inchangée.
- `Documentation UX.md` mise à jour dans le vault avec `updated` actualisé et wikilinks préservés. Obsidian n'a pas été ouvert.
- Cette validation portait sur l'ancienne approche, qui s'est révélée inefficace. Le simulateur iPhone 17 a ensuite reproduit la bande fixe du profil personnel et montré que la feuille d'avatar remplit correctement son bas.
- Décision principale : appliquer l'extension au-dessus du `NavigationStack`, à la racine visible du contrôleur d'hébergement. Alternative écartée : colorer la safe area ou ignorer seulement la zone sûre du `Form`, deux approches déjà insuffisantes sur les captures fournies.
- Aucun défaut résiduel confirmé au-delà du rendu non vérifié ; pas de nouveau `todos/` ni de note `docs/solutions/`.

## Validation finale de l'approche révisée

- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build-for-testing` : `TEST BUILD SUCCEEDED` après la correction de la frontière SwiftUI/UIKit. Journaux : `/tmp/wander-profile-native-safe-area-build.log` et `/tmp/wander-profile-representable-safe-area-build.log`.
- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'platform=iOS Simulator,id=6F13855D-10B8-45AF-9205-17C8393379E3' -parallel-testing-enabled NO -disableAutomaticPackageResolution -only-testing:wanderUITests/MapSocialGestureUITests/testOwnAvatarSelectionOpensSeparateSheetAndReturnsToProfile -only-testing:wanderUITests/MapSocialGestureUITests/testOwnProfileFromGroupThenFriendProfile test` : 2 tests réussis, 0 échec. Journal : `/tmp/wander-profile-native-safe-area-tests.log`.
- iPhone 17 simulé déjà démarré : le profil personnel agrandi est observé en modes clair et sombre en haut et après défilement jusqu'au dernier bloc. Le fond du formulaire atteint le bord inférieur arrondi, sans bande fixe distincte ; le dernier bloc reste entier et accessible. Le palier compact et la feuille d'avatar ont été comparés et restent utilisables. Capture claire du bas : `/tmp/wander-profile-native-bottom-verified.png`.
- La note `Documentation UX.md` du vault a été mise à jour avec sa propriété `updated`, sans ouvrir Obsidian. `git diff --check` réussit. Aucun défaut résiduel confirmé ; pas de nouveau `todos/`.
- Décision la plus difficile : placer l'extension sur le representable présenté, puis limiter le contrôleur d'hébergement visible à la région de clavier. Les extensions du `Form`, de sa racine hébergée et le seul réglage interne du contrôleur ont échoué visuellement. Le clavier logiciel a été affiché sur le champ « Code ami » : le champ reste visible au-dessus du clavier. Les réglages initiaux du simulateur (apparence sombre, clavier matériel connecté) ont été rétablis. Le mécanisme et les captures sont consignés dans `docs/solutions/2026-09-27-safe-area-representable-dans-feuille.md`.

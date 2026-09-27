---
title: "Unifier le fond au bas des fiches Profil"
status: completed
completed_at: 2026-09-27T15:15:00+09:00
date: 2026-09-27
owner: Samuel
tags: [plan, profile, ux]
---

# Unifier le fond au bas des fiches Profil

## Outcome

Le fond des fiches Profil couvre la zone sûre inférieure. Cette zone reste un espace sous les contenus et les contrôles, sans bande visuellement distincte.

## Scope

- Inclus : fiches personnelle et ami, feuille de choix d'avatar, fonds et espacements inférieurs.
- Exclus : contenu des profils, navigation, persistance, hauteur du palier compact et simulateur.
- Dépendance : présentation UIKit et contenus SwiftUI existants.

## Affected files

- `wander/FriendProfileSheet.swift` : fond du contenu hébergé dans la feuille partagée.
- `wander/OwnProfileSheet.swift` : fond de la fiche personnelle et de la feuille d'avatar si nécessaire.
- `wander/ProfilePanelView.swift` : fond et marge du formulaire si nécessaire.
- Ce plan et, seulement si la revue révèle un défaut restant, un fichier priorisé dans `todos/`.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md` : comportement du fond et de l'espacement au bas des fiches ; propriété `updated`.

## Implementation

- [x] Donner au contenu visible un fond natif cohérent qui couvre la zone inférieure de la fiche.
- [x] Garder les contrôles dans la zone sûre et conserver un espacement de contenu en bas.
- [x] Harmoniser la feuille d'avatar avec les fiches.
- [x] Mettre à jour la note UX et sa propriété `updated`.
- [x] Compiler l'app et les tests, simplifier et relire le diff.

## Risks

- Un fond appliqué au mauvais niveau peut recouvrir les coins arrondis ou changer l'apparence du formulaire.
- Changer l'inset du contenu peut masquer le dernier contrôle ou déplacer le palier compact ; préserver les insets existants autant que possible.
- Le clavier du profil personnel doit garder son comportement natif.

## Validation and acceptance

- Compilation Debug et des tests sans nouveau diagnostic Swift ; `git diff --check` et lecture des vues concernées.
- Aucun essai, lancement, capture ou vérification sur l'iPhone 17 ni sur un autre simulateur, conformément à la consigne de Samuel. Le rendu réel reste non vérifié.
- Les fiches personnelle et ami conservent leurs contrôles et leur défilement ; la documentation décrit le fond continu et l'espacement inférieur.

## Review notes

- Plan présenté, puis révisé pour exclure toute vérification sur l'iPhone 17 ; Samuel a répondu « je valide » le 27 septembre 2026.
- Les compétences Compound Engineering citées dans `AGENTS.md` ne sont pas installées ; suivre leurs étapes manuellement.
- Les modifications locales du choix d'avatar, issues du plan précédent, sont conservées.

## Validation et revue

- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build-for-testing` : `TEST BUILD SUCCEEDED`. Journal : `/tmp/wander-profile-bottom-background-build-final.log`.
- Aucun nouveau diagnostic Swift. Avertissement AppIntents préexistant. Le premier essai de compilation a révélé deux appels de test au contrôleur ; un argument par défaut conserve cette API. La compilation suivante a réussi.
- `git diff --check` : réussi. Le contenu visible reçoit le fond système de sa fiche, tandis que les marges du contenu, la mesure compacte, le défilement et les comportements du clavier restent inchangés dans le code.
- `Documentation UX.md` mise à jour dans le vault avec `updated` actualisé ; Obsidian n'a pas été ouvert.
- Aucun simulateur ni appareil lancé ou vérifié. Le fond continu, les gestes et le défilement ne sont pas validés visuellement.
- Décision principale : colorer le fond du contrôleur qui héberge le contenu visible, y compris derrière son inset inférieur, sans toucher à la mesure ou aux safe areas SwiftUI.
- Alternative écartée : ignorer la safe area pour tout le contenu, ce qui risquerait de recouvrir les contrôles et de changer le comportement du clavier.
- Incertitude restante : correspondance visuelle exacte des couleurs système avec le formulaire dans les modes clair et sombre. Aucun défaut confirmé à consigner dans `todos/`, ni leçon vérifiée à ajouter à `docs/solutions/`.

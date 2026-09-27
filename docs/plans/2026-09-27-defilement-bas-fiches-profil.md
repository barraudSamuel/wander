---
title: "Étendre le défilement des fiches Profil jusqu'en bas"
status: completed
completed_at: 2026-09-27T15:24:43+09:00
date: 2026-09-27
owner: Samuel
tags: [plan, profile, ux, fix]
---

# Étendre le défilement des fiches Profil jusqu'en bas

## Outcome

Le contenu des fiches Profil défile jusqu'au bord inférieur de la feuille. La zone sûre inférieure sert d'espace après le contenu, sans masquer une ligne ou un contrôle.

## Context

La capture fournie par Samuel montre la section « Ajouter un ami » coupée par la bande inférieure blanche du profil personnel. La feuille de choix d'avatar présente le comportement attendu. Le précédent changement a coloré le fond de la bande sans modifier la zone de défilement.

## Scope

- Inclus : défilement inférieur de la fiche personnelle et de la fiche ami ; retrait du correctif de fond précédent devenu inutile.
- Exclus : contenu des profils, choix d'avatar, mesure du palier compact, navigation et vérification sur simulateur.

## Affected files

- `wander/ProfilePanelView.swift` : extension du formulaire personnel au bas de la feuille et marge de contenu inférieure.
- `wander/FriendProfileSheet.swift` : extension du défilement ami et retrait du fond du contrôleur d'hébergement.
- `wander/OwnProfileSheet.swift` : retrait du paramétrage du fond de la fiche personnelle devenu inutile.
- Ce plan et, uniquement si un défaut est confirmé à la revue, un fichier priorisé dans `todos/`.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md` : corriger la description du comportement inférieur ; propriété `updated`.

## Implementation

- [x] Étendre le formulaire personnel au bas de la feuille et garder une marge après les dernières lignes.
- [x] Appliquer le même principe au défilement du profil ami.
- [x] Retirer le fond artificiel ajouté dans le correctif précédent.
- [x] Corriger la note UX et sa propriété `updated`.
- [x] Compiler l'app et les tests, relire le diff et documenter la limite de validation visuelle.

## Risks

- La dernière ligne ne doit pas passer sous le bord inférieur ou un indicateur système.
- Le clavier et les gestes de défilement doivent conserver leur comportement natif.
- Le palier compact et la préparation du cadrage de la carte ne doivent pas changer.

## Validation and acceptance

- Compilation Debug de l'app et des tests sans nouveau diagnostic Swift ; `git diff --check` et revue des modifications.
- Aucun essai, lancement ni capture sur l'iPhone 17 ou un autre simulateur, selon la consigne de Samuel. Le rendu réel et les gestes resteront non vérifiés.
- Le formulaire et le défilement ami couvrent le bas de la feuille dans le code ; une marge est réservée après le contenu plutôt qu'une bande qui le recouvre.

## Review notes

- Plan corrigé explicitement approuvé par Samuel le 27 septembre 2026 : « je valide ».
- Les compétences Compound Engineering mentionnées par `AGENTS.md` ne sont pas installées ; suivre l'équivalent manuellement.
- Les changements locaux des deux plans précédents sont conservés hors retrait du correctif de fond erroné.

## Validation et revue

- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build-for-testing` : `TEST BUILD SUCCEEDED`. Journal : `/tmp/wander-profile-scroll-bottom-build.log`.
- Aucun nouveau diagnostic Swift. Avertissements AppIntents préexistants.
- `git diff --check` : réussi. La revue du code confirme que le formulaire personnel et le `ScrollView` ami ignorent seulement la zone sûre du conteneur au bord inférieur, avec une marge de contenu de 16 points. La mesure du palier compact et la gestion du clavier ne changent pas.
- Le paramètre et la couleur du contrôleur d'hébergement ajoutés dans le correctif précédent ont été retirés. La feuille de choix d'avatar reste inchangée.
- `Documentation UX.md` corrigée dans le vault avec `updated` actualisé et wikilinks préservés. Obsidian n'a pas été ouvert.
- Aucun simulateur ni appareil lancé ou vérifié, conformément à la demande de Samuel. La disparition effective de la coupure et les gestes restent à confirmer visuellement par lui.
- Décision principale : étendre les surfaces défilantes plutôt que de colorer l'espace hors défilement. Alternative écartée : modifier toute la safe area du contrôleur, qui aurait changé le haut de la feuille et le clavier.
- Aucun défaut résiduel confirmé à consigner dans `todos/`, ni nouvelle leçon vérifiée à ajouter à `docs/solutions/`.

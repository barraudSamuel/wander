---
title: Bouton SwiftUI commun au profil et aux événements
status: completed
completed_at: 2026-09-22T14:50:42+09:00
date: 2026-09-22
---

Samuel approuve le composant SwiftUI commun par « faisons ça ».

## Périmètre

Créer `wander/MapImageButton.swift`, bouton natif en verre, diamètre 54 pt,
image originale 36 pt, cercle entier interactif. Réutiliser dans ContentView.swift,
DebugSocialMapScenario.swift et NativeMapTabView.swift. Ce dernier conserve le
conteneur UIKit de navigation et héberge uniquement le nouveau bouton SwiftUI.
Préserver sélection des événements, placement/clavier, libellés et identifiants,
et ouverture du profil sans recentrage. Couvrir les appuis sur le bord dans
MotionDockUITests.swift. Mettre à jour les notes Obsidian Documentation UX.md
et Documentation technique.md dans le vault Wander existant.

## Étapes

- [x] Créer et intégrer le bouton commun, supprimer le bouton événements UIKit.
- [x] Ajouter le test d’appui sur l’anneau des deux boutons.
- [x] Actualiser les notes UX et technique.
- [x] Compiler app/tests, revoir le diff et vérifier sur iPhone 17 si démarré.

## Risques et validation

Préserver le cycle de vie du contrôleur hôte, éviter une rétention du parent,
conserver le traitement clavier et les états sélectionnés. Utiliser le style
natif du bouton, pas un verre décoratif ajouté après le contrôle. La géométrie
et le hit-testing doivent être vérifiés en exécution sur l’iPhone 17 déjà démarré.
Ne pas démarrer d’autre simulateur. Compilation build-for-testing et diff --check.

## Résultat et validation

`MapImageButton` centralise les deux contrôles et leurs dimensions. Le verre est
fourni par `.buttonStyle(.glass)` / `.glassProminent`, avec une forme circulaire.
Le profil appelle toujours `presentOwnProfile(focusOnMap: false)` ; les événements
utilisent leur action et état existants. Le contrôleur UIKit ne fait plus que
placer un hôte SwiftUI pour le bouton événements. Son callback capture faiblement
le parent, ses zones sûres internes sont désactivées et le cycle enfant est complet.

Revue et simplification locales : suppression du code de miniature/configuration
UIButton, vérification des identifiants, traits de sélection, actions, géométrie
et gestion du clavier conservée. Aucun finding de code restant. Diff isolé dans
`/tmp/wander-shared-button.diff`, nouveau composant dans `wander/MapImageButton.swift`.

Validation : `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build-for-testing`
→ **TEST BUILD SUCCEEDED**, journal `/tmp/wander-shared-button-build.log`.
Messages AppIntents seulement ; `git diff --check` réussi.
Le test ajouté compare les diamètres puis touche les deux bords, à 4,3 points
du bord du cadre et hors de l’image, pour ouvrir/fermer chaque fiche.
Les tests sont compilés mais non exécutés : seul l’iPhone 16e est démarré.
Le diamètre réellement affiché et les appuis sur l’anneau restent à confirmer
sur l’iPhone 17. Aucun simulateur démarré, aucune application installée.
Notes UX et technique Obsidian mises à jour avec leur propriété `updated`.
Aucun diagnostic de cause racine du hit-testing n’est présenté comme vérifié
sans exécution ; l’assemblage précédent est remplacé par le contrôle natif commun.

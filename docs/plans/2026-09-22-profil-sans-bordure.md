---
title: Portrait de profil sans contour en verre
status: completed
completed_at: 2026-09-22T15:23:25+09:00
date: 2026-09-22
---

Samuel a validé le retrait du contour en verre du profil, avec conservation de
la zone cliquable de 54 pt et du bouton événements existant.

Périmètre : `MapImageButton.swift`, usages profil dans `ContentView.swift` et
`DebugSocialMapScenario.swift`, ce plan et les descriptions correspondantes des
notes Obsidian UX et technique dans le vault Wander existant.

- [x] Ajouter une variante sans verre au bouton partagé et l’utiliser pour le profil.
- [x] Correction explicite de Samuel : portrait lui-même de 54 × 54 pt, sans bordure ni marge, et action sans recentrage.
- [x] Actualiser la documentation, compiler app/tests et vérifier le diff.

Risque : préserver le cadre et la forme tactile même sans fond visible. Le test
existant couvre le bord du portrait et les appuis hors image des événements. Validation en exécution uniquement
sur l’iPhone 17 déjà démarré ; compilation et revue dans le cas contraire.

## Validation et revue

Variante `showsGlass: false` appliquée aux deux usages du profil ; événements
inchangés avec la valeur par défaut. Revue locale : image, cadre tactile, libellés,
actions et protection contre le recentrage conservés. Aucun finding restant.
Aucun apprentissage nouveau nécessitant une note de solution.

Compilation app et tests : `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build-for-testing` : **TEST BUILD SUCCEEDED**.
Journal : `/tmp/wander-profile-borderless-build.log`. `git diff --check` réussi.
Messages AppIntents seulement. Tests compilés mais non exécutés ; seul l’iPhone 16e
est démarré. Rendu et appuis hors image restent à vérifier sur l’iPhone 17.
Notes Obsidian UX et technique actualisées, propriété `updated` comprise.

## Correction de compréhension

Samuel précise que l’image doit elle-même faire 54 × 54 pt, sans anneau autour.
La précédente affirmation d’une zone périphérique cliquable n’avait pas été
vérifiée en exécution et est retirée. La variante sans verre remplit maintenant
le cadre avec le portrait de 54 pt. Les événements conservent leur image de 36 pt.

Validation de la correction 54 pt : **TEST BUILD SUCCEEDED**, même commande
build-for-testing, journal `/tmp/wander-profile-54-build.log`. `git diff --check`
réussi. Revue : seuls le diamètre du portrait sans verre et le libellé du test
changent ; aucune modification de l’action ou du bouton événements. Rendu et
appuis en exécution non vérifiés sur l’iPhone 17.

## Ajustement de taille demandé

Samuel trouve le portrait 54 pt trop grand et demande de le réduire. Portrait et
bouton sans verre passent à 44 × 44 pt, sans bordure ni marge ; événements inchangés.
Les assertions des dimensions du profil sont adaptées à 44 pt.

Validation 44 pt : **TEST BUILD SUCCEEDED**, journal `/tmp/wander-profile-44-build.log`,
même commande build-for-testing. `git diff --check` réussi. Revue locale : dimensions
image et contrôle identiques, configuration événements conservée. Notes mises à jour.
Tests compilés ; rendu et appuis non vérifiés en exécution sur l’iPhone 17.

## Même apparence pour les événements

Samuel demande d’appliquer aussi aux événements le bouton image de 44 × 44 pt
sans bordure ni marge. Supprimer la variante en verre devenue inutilisée dans
MapImageButton, adapter les usages et tests, conserver le centre du bouton événements
près de la barre native et son action/état sélectionné. Actualiser les notes existantes.

Validation événements 44 pt : **TEST BUILD SUCCEEDED**, journal
`/tmp/wander-events-44-build.log`, même commande build-for-testing.
`git diff --check` réussi. Revue : les deux images remplissent leur contrôle 44 pt,
aucune variante de verre restante, callbacks et identifiants conservés, centre du
bouton événements conservé. Notes UX et technique actualisées. Tests compilés,
mais rendu et appuis non vérifiés en exécution sur l’iPhone 17.

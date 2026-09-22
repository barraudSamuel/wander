---
title: "Bouton de profil persistant avec le portrait d’origine"
status: completed
completed_at: 2026-09-22T05:01:18.269832+00:00
date: 2026-09-22
owner: Samuel
---

# Bouton de profil persistant

## Approbation et résultat

Samuel approuve explicitement le plan proposé par « je valide », après avoir
fourni le portrait bleu de référence. Le bouton en haut à droite ne doit plus
être retiré lors de l’ouverture d’une fiche et reprend l’image de l’ancien onglet.

## Périmètre et fichiers

- `wander/ContentView.swift` : retirer la condition de masquage et utiliser
  `TabIconProfile` en couleurs originales dans le bouton natif.
- `wander/DebugSocialMapScenario.swift` : même affichage pour le scénario local.
- `wanderUITests/MotionDockUITests.swift` : assertions de présence et géométrie
  du bouton avant, pendant et après ouverture de la fiche compacte.
- Ce plan.
- Notes Obsidian dans `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Documentation UX.md`, `Documentation technique.md`, `Backlog features.md`.
  Mettre à jour leur propriété `updated` et préserver leurs wikilinks.

Le portrait fourni correspond à l’asset existant, vérifié visuellement. Aucun
nouvel asset ni traitement d’image nécessaire. Réutiliser la feuille unique et
les protections du compte. Aucune commande Git mutante. Les changements
préexistants restent en place ; le diff de cette correction est isolé par copie
des trois fichiers avant édition sous `/tmp/wander-profile-button-review/before`.

## Étapes

- [x] Afficher le portrait original et supprimer le masquage dans les deux vues.
- [x] Adapter les assertions de navigation et compiler app/tests.
- [x] Simplifier et revoir uniquement le diff de cette correction.
- [x] Actualiser les trois notes Obsidian et consigner la validation.

## Risques et validation

Conserver la position et le libellé accessibles, l’ouverture de la même feuille
et les gardes du compte. La feuille native agrandie peut naturellement recouvrir
la carte ; le bouton reste monté, sans être dessiné par-dessus une présentation
modale. Tester sa présence et sa position dans la feuille compacte.

Compiler app et tests avec `build-for-testing`, contrôler `git diff --check`.
Parcours UI uniquement sur l’iPhone 17 s’il est déjà démarré ; ne pas démarrer
d’appareil ni utiliser l’iPhone 16e sans autorisation. La validation UI absente
reste explicitement signalée.

## Validation et revue finales

- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build-for-testing` : **TEST BUILD SUCCEEDED**, journal `/tmp/wander-profile-button-build.log`.
- Aucun nouveau diagnostic Swift ; messages AppIntents préexistants uniquement.
- `git diff --check` : réussi.
- Tests UI compilés, mais non exécutés : seul l’iPhone 16e est démarré. Aucun appareil supplémentaire démarré et aucune installation effectuée.
- Simplification : trois lectures ciblées (qualité, réutilisation, efficacité), aucun changement nécessaire. Conservation de `renderingMode(.original)` pour exprimer localement le rendu attendu, même si l’asset le déclare déjà.
- Revue de code légère du diff isolé : aucune anomalie constatée. Reçu : `/tmp/wander-profile-button-review/ce-code-review/profile-button/review.json`. Aucun finding nécessitant un fichier dans `todos/`.
- Les trois notes Obsidian prévues ont été actualisées, avec leur propriété `updated` et leurs wikilinks préservés.
- Les critères d’implémentation sont remplis ; la présence et la géométrie en exécution restent à vérifier sur l’iPhone 17. Une feuille native agrandie peut couvrir le bouton.

Aucun apprentissage réutilisable nouveau ne justifie une note de solution supplémentaire pour ce correctif local.

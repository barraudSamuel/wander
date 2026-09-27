---
status: completed
date: 2026-09-26
completed_at: 2026-09-26
---

# Actions compactes des événements

Samuel a approuvé explicitement le plan présenté dans la conversation.

## Résultat et périmètre

Sur chaque carte autonome, afficher les participants à gauche et les actions uniquement en icônes à droite, sur une même ligne. Conserver les actions et autorisations existantes, les libellés accessibles et les contrôles natifs. Aucun changement de navigation, données ou gestes.

## Fichiers concernés

- `wander/MapEventsPanelView.swift`
- Ce plan de suivi.
- Coffre `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` : `Documentation UX.md` et `Backlog features.md`.

## Étapes

- [x] Regrouper participants et actions dans un pied de carte horizontal.
- [x] Remplacer les textes visibles des actions par leurs symboles, avec leurs libellés accessibles.
- [x] Compacter les états vide, chargement et indisponible pour préserver la ligne.
- [x] Mettre à jour les deux notes Obsidian et leur propriété `updated`.
- [x] Compiler et relire le changement.

## Risques et validation

Le pied de carte doit tenir avec trois actions sur petit écran. Utiliser un compteur court et limiter les avatars à trois. Préserver les libellés des boutons utilisés par les tests existants ainsi que leur désactivation pendant l'envoi. Compilation avec `xcodebuild build-for-testing`, sans exécution des tests ni lancement du simulateur conformément à la suspension existante.

## Critères d'acceptation

Une seule ligne, participants à gauche, actions en icônes à droite pour les deux rôles. Compilation réussie et revue sans défaut bloquant. Le rendu sur appareil demeure non vérifié.

## Revue et choix

Le compteur visible est numérique, avec trois avatars au maximum. Les états vide, chargement et indisponible restent compacts ; les libellés accessibles détaillés sont conservés. L'indicateur d'envoi est déplacé dans la description pour ne pas ajouter de largeur au pied de carte. Le style secondaire des participants ne s'applique pas aux boutons.

`ce-simplify-code` : réutilisation et qualité revues par deux agents ; efficacité relue dans le contexte principal après refus de lancement du troisième agent pour limite de capacité. Aucun problème d'efficacité relevé. La formulation singulière du compteur accessible a été corrigée. La suppression suggérée du libellé accessible explicite a été écartée pour conserver cette garantie.

Les tests existants de `MapSocialGestureUITests.swift` retrouvent les boutons par leurs libellés, conservés. Aucun test nouveau pour ce changement de présentation ; validation par compilation et revue, sans exécution UI. Aucun changement Git ni publication. Aucune nouvelle leçon réutilisable justifiant une note de solution.

## Validation finale

- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build-for-testing` : code 0, `TEST BUILD SUCCEEDED`. Journal : `/tmp/wander-event-footer-build.log`.
- Première tentative limitée par le sandbox aux caches Xcode ; relance autorisée avec les caches existants réussie. Aucun lancement de simulateur.
- Aucun diagnostic Swift. Deux avertissements d'extraction AppIntents préexistants au dernier passage.
- `git diff --check` réussi.
- `ce-code-review`, périmètre limité au delta du pied de carte : terminé, `Ready to merge`, aucune anomalie retenue. Reçu : `/tmp/compound-engineering-501/ce-code-review/footer-20260926-065312/review.json`.
- Finding de formulation corrigé : `todos/066-done-p3-singulier-compteur-participants.md`.
- Notes Obsidian mises à jour, propriété `updated` actualisée et wikilinks préservés.
- Limite : disposition et gestes non observés sur simulateur ou appareil, conformément à la suspension approuvée.

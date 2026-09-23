---
title: Supprimer la bande fixe au-dessus des listes
status: completed
approved_at: 2026-09-22
completed_at: 2026-09-22
---

## Résultat et périmètre approuvés

Samuel a validé la suppression de la marge supérieure fixe de 12 points dans
le conteneur commun des listes Amis et Événements. Le contenu doit rejoindre
le bord arrondi ; conserver la poignée et sa zone tactile de 44 points.

Fichiers concernés : `wander/MapDetailSplitView.swift`, ce plan et la note
`Documentation UX.md` du vault
`/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander`.
Préserver les modifications approuvées précédentes. Aucun changement Git mutatif.

## Travail

- [x] Retirer l’espace extérieur fixe et restituer sa hauteur à la liste.
- [x] Relire le placement et la zone tactile de la poignée.
- [x] Compiler ; vérifier le rendu si l’iPhone 17 est déjà démarré.
- [x] Mettre à jour la note UX et consigner les limites de validation.

## Risques et validation

La poignée déborde de 12 points sur la liste : contrôler la première ligne et
les gestes après suppression de la marge. Les arrondis, la taille du panneau
et le cadre natif de la carte restent régis par la géométrie existante.
Pas de nouveau test pour ce réglage visuel ; compiler les cibles existantes.

Au début du travail, `xcrun simctl list devices booted` ne retourne que
l’iPhone 16e. L’iPhone 17 autorisé n’est pas démarré ; aucune exécution UI
sur un autre simulateur et aucun démarrage ne sont autorisés.

## Revue et résultat

Correction limitée à trois lignes de géométrie : suppression de `listTopInset`,
hauteur de liste complète et padding supérieur nul. La hauteur totale du
panneau et la position de la poignée ne changent pas. Relecture et
simplification manuelles proportionnées à ce réglage visuel ; aucun défaut
supplémentaire identifié.

Le choix principal était de conserver la cible tactile native de 44 points.
La réduire à la bande visible aurait rendu la poignée plus difficile à saisir.
L’interaction près du bord de la première ligne reste la partie non vérifiée.
La validation fonctionnelle existante est suivie dans
`todos/062-ready-p2-valider-amis-sous-carte.md`.

Commande exécutée :

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build-for-testing
```

Résultat : `TEST BUILD SUCCEEDED`, sortie 0. Journal :
`/tmp/wander-list-top-inset-build.log`. `git diff --check` passe.
Aucun test exécuté ni rendu visuel validé : l’iPhone 17 n’est pas démarré.
La note Obsidian `Documentation UX.md` et sa propriété `updated` ont été mises
à jour. Pas de nouvelle note de solution pour ce réglage courant.

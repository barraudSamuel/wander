---
title: Annuler l'affichage progressif des adresses
date: 2026-10-11
status: completed
completed_at: 2026-10-11T11:37:04+09:00
approved_at: 2026-10-11
---

# Résultat approuvé

Samuel a validé le retour à toutes les icônes visibles sans sélection par densité.
Les noms et types apparaissent à zoom 16 et disparaissent sous 15,7 comme avant.
Les symboles de catégorie, le rond Liquid Glass clear, les favoris et l'import
restent conservés. Les superpositions sont de nouveau possibles et acceptées.

## Périmètre

- `wander/MapWithFogView.swift`, `wander/MapAnnotations.swift`,
  `wander/SavedPlaceAnnotation.swift` : retirer sélection et visibilité progressives.
- `wanderTests/SavedPlaceAnnotationTests.swift`,
  `wanderUITests/NaverImportUITests.swift`, scénario existant
  `wander/DebugSocialMapScenario.swift` : vérifier le retour au comportement initial.
- Ce plan et le plan historique `2026-10-11-adresses-progressives.md`.
- Notes du coffre Obsidian existant : `Documentation UX.md`,
  `Documentation technique.md`, `Backlog features.md`, propriété `updated` comprise.

## Exécution et validation

- [x] Retirer le moteur de densité et rétablir les libellés au seuil commun.
- [x] Adapter les tests, vérifier toutes les adresses d'une zone dense dès l'import.
- [x] Compiler et tester import, zoom/dézoom, fiche et annotations sociales sur
  le simulateur iPhone 17 Pro déjà démarré, sans en créer ni démarrer un autre.
- [x] Simplifier, relire la différence de cet incrément, actualiser la documentation.

Comparaison à la copie antérieure `/tmp/wander-density-before` et sauvegarde
de l'état de départ dans `/tmp/wander-revert-density-before`. Le retour mécanique
au code précédemment vérifié utilise les tests de seuil restaurés et les tests UI
existants ; pas de nouveau cycle rouge préalable pour cette restauration.
Le scénario dense est conservé uniquement pour vérifier l'absence de filtrage.
Exécution native locale, une seule unité couplée. Aucun Git mutateur, commit,
publication, changement de stockage ou appel réseau supplémentaire. L'autorisation
de modifier le travail en cours vient du retour en arrière explicitement approuvé.

## Risques et limites

Les icônes et les textes proches peuvent se chevaucher. Aucun changement des
catégories, de Firebase ou des données enregistrées. Vérification synthétique sur
simulateur ; pas de test sur iPhone physique ni de test d'accessibilité dédié.

## Résultats

Les trois fichiers de production et les tests d'annotation ont été restaurés
à l'identique depuis la copie antérieure vérifiée. La fixture dense est conservée
sans changement ; son test attend maintenant les 36 icônes compactes dès l'import.
Aucun moteur de densité ni appel à son ancien masque de visibilité ne subsiste.

Simplification : restauration mécanique et petit ajustement du scénario UI ;
aucune abstraction ni modification supplémentaire nécessaire. Revue indépendante
locale du seul incrément : aucun constat actionnable. Reçu :
`/tmp/wander-revert-density-review.json`. Le helper de portée ce-code-review
renvoie `invalid base endpoint` pour une copie de fichiers ; revue manuelle
équivalente avec comparaison `/tmp/wander-revert-density.diff` au lieu de
réexaminer tout le travail Naver non committé. Aucun transfert externe.
XcodeBuildMCP absent ; validation équivalente par xcodebuild sur le simulateur
existant. Aucun nouveau simulateur ni commande Git mutatrice.

Les notes Obsidian UX, technique et backlog ont été actualisées, propriété
`updated` comprise, sans ouvrir Obsidian. L'ancien plan conserve ses résultats
historiques et indique le retour en arrière. Aucune nouvelle note de solution :
ce retour au comportement précédent n'apporte pas de leçon non documentée.

Validation PASS : compilation Debug et 42 tests réussis, sans échec :
3 tests d'annotation, 34 tests du contrôleur social et 5 parcours UI Naver.

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' -disableAutomaticPackageResolution -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1 -only-testing:wanderTests/SavedPlaceAnnotationTests -only-testing:wanderTests/MapSocialProximityControllerTests -only-testing:wanderUITests/NaverImportUITests test
```

Journal : `/tmp/wander-revert-density-tests.log`. Résultat :
`/Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx/Logs/Test/Test-wander-2026.10.11_11-33-51-+0900.xcresult`.
Pas d'avertissement Swift ; seuls avertissements de métadonnées AppIntents
préexistants. Aucun échec ni crash des parcours testés. `git diff --check` passe.

Captures exportées dans `/tmp/wander-revert-density-screens/` et relues :
- `EF54C75B-F72D-4834-B193-B38438CD8B45.png` : icônes de la grille dense
  présentes immédiatement, avec les superpositions acceptées.
- `1C6D3759-3EC4-4A12-B152-4F7BB1BF5ED6.png` : tasse, verre clear, nom et type
  après zoom. Le scénario vérifie aussi leur masquage au dézoom et la fiche.

L'import, le réimport sans doublons, les erreurs, la fermeture et le collage
sont couverts par les autres scénarios. Aucun constat de revue à ajouter dans
`todos/`. Pas de vérification sur appareil physique.

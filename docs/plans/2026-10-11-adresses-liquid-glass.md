---
title: Rond Liquid Glass derrière les adresses
date: 2026-10-11
status: completed
completed_at: 2026-10-11T10:17:17+09:00
approved_at: 2026-10-11
---

# Résultat approuvé

Samuel a validé un rond Liquid Glass natif de 36 pt derrière le symbole de
20 pt, avec cible tactile de 44 pt. Le nom et le type restent à droite au zoom.

## Périmètre

- `wander/SavedPlaceAnnotation.swift` : ajouter le fond circulaire natif.
- Ce plan.
- Coffre Obsidian existant : `Documentation UX.md` et `Backlog features.md`.

## Étapes et acceptation

- [x] Ajouter le verre centré sur l'icône, sans modifier l'ancrage ni les gestes.
- [x] Compiler, exécuter les tests existants d'annotation et zoom/dézoom,
  vérifier visuellement le cercle et ouvrir la fiche sur l'iPhone 17 Pro existant.
- [x] Relire et simplifier le changement ; mettre à jour les deux notes Obsidian.

## Risques et validation

Vérifier la lisibilité sur la carte et que le fond n'intercepte pas les appuis.
Le rendu est une modification de style : aucune nouvelle logique ni test dédié,
les tests existants et les captures UI servent de validation. Aucun changement
de données, de synchronisation ou de seuils de zoom. Pas de test d'accessibilité
dédié ni de nouvel appareil. Pas de commit ni commande Git modificatrice.
L'implémentation reste locale dans le fichier déjà approuvé et non committé.
XcodeBuildMCP est absent : validation par l'équivalent CLI autorisé par AGENTS.md.

## Validation et revue

PASS sur `wander.xcodeproj`, schéma `wander`, Debug, simulateur existant iPhone
17 Pro `C0DADF07-7E14-4D5E-AE4B-B17844A9C454`.
Commande : `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug
-destination 'id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454'
-disableAutomaticPackageResolution -parallel-testing-enabled NO
-maximum-concurrent-test-simulator-destinations 1
-only-testing:wanderTests/SavedPlaceAnnotationTests
-only-testing:wanderUITests/NaverImportUITests/testMapLabelsAppearOnZoomAndDisappearOnZoomOut test`.

- Compilation réussie ; 3 tests d'annotation et 1 scénario UI réussis.
- Le parcours UI vérifie zoom, dézoom par le bord, puis ouverture de la fiche.
- Captures relues : cercle visible, symbole centré, texte à droite au zoom,
  texte masqué au dézoom. Taille de texte standard.
- Aucun avertissement Swift. Message d'outillage AppIntents préexistant uniquement.
- `git diff --check` réussit.
- Journal : `/tmp/wander-glass-tests.log`.
- Résultat : `/Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx/Logs/Test/Test-wander-2026.10.11_10-15-07-+0900.xcresult`.
- Captures : `/tmp/wander-glass-screens/705C4C72-83E8-4DAB-9C0C-19296BA8C4A6.png`
  au zoom, `789E1724-4EBD-4EB9-966A-D8D7DE6630DC.png` au dézoom dans le même dossier.

Les trois lectures de simplification n'ont relevé aucun changement utile.
Le helper ce-code-review n'accepte pas la copie avant modification comme base ;
revue locale équivalente du seul delta, sans transfert externe ni modification Git.
Reçu `/tmp/wander-glass-review.json`, aucun constat à ajouter à `todos/`.
La géométrie, l'ordre des sous-vues et les appuis restent inchangés. Le verre est
créé une seule fois par annotation, sans recalcul lors des mouvements de caméra.
Pas de leçon nouvelle à ajouter à `docs/solutions/` pour cet ajout de style.

Les deux notes Obsidian prévues sont actualisées, propriété `updated` comprise.
Pas de test sur iPhone physique ni de mesure de performances avec une carte dense.

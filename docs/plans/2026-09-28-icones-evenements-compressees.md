---
title: Remplacer et alléger les icônes événements
status: completed
date: 2026-09-28
approved_at: 2026-09-28
completed_at: 2026-09-28
---

# Résultat

Plan explicitement approuvé par Samuel dans la conversation. Utiliser les deux
PNG fournis pour le calendrier et la fermeture de la liste. Renommer les copies
importées et les redimensionner en PNG 56, 112 et 168 pixels, pour le bouton
existant de 56 points et les densités 1x, 2x et 3x. Préserver les originaux.

## Fichiers et périmètre

- `wander/Assets.xcassets/TabIconEvents.imageset/` : trois PNG et Contents.json.
- `wander/Assets.xcassets/TabIconEventsClose.imageset/` : trois PNG et Contents.json.
- Le présent plan.
- Notes du coffre `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Backlog features.md`, `Documentation UX.md`, `Documentation technique.md`.
  Actualiser `updated` et préserver les wikiliens.

Conserver le code Swift, la taille, le centrage, le cadrage circulaire et le
retour haptique existants. Aucune commande Git mutante. Préserver les modifications
de participation déjà présentes dans le dépôt.

## Travail et validation

- [x] Plan approuvé.
- [x] Générer et intégrer les copies renommées aux trois tailles.
- [x] Mesurer le poids et vérifier dimensions, manifestes et originaux.
- [x] Compiler et exécuter le test existant d'ouverture/fermeture sur l'iPhone 17 déjà démarré.
- [x] Inspecter les captures du calendrier et de la croix dans leur cercle.
- [x] Relire les changements et actualiser les trois notes Obsidian.

Le principal risque est une perte de lisibilité après réduction ou un dessin
coupé par le cercle. Vérifier les captures réelles. Réutiliser
`MotionDockUITests/testEventsButtonStaysCenteredAcrossRepeatedListToggles` sans
ajouter de test pour les fichiers d'image. Aucun test d'accessibilité dédié.
XcodeBuildMCP absent : validation équivalente avec xcodebuild et simctl.
Traitement déterministe des fichiers fournis, sans génération ou retouche créative.

## Résultats

Les deux sources 1024 × 1024 totalisent 1 734 785 octets. Les six variantes
totalisent 151 442 octets, soit une réduction de 91,27 % : calendrier 74 903,
croix 76 539 octets. Traitement avec `sips -z`, directement depuis chaque original.
Chaque manifeste référence les bonnes dimensions et conserve le rendu original
des couleurs. Les empreintes SHA-256 des sources sont inchangées.

Les deux PNG 3x ont été inspectés : dessins entiers, texture et couleurs
conservées. Vérification finale dans le cercle réussie sur le simulateur.
Rapport détaillé : `/private/tmp/wander-event-icons-size-report.json`.

## Validation et revue

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'platform=iOS Simulator,id=6F13855D-10B8-45AF-9205-17C8393379E3' -parallel-testing-enabled NO -disableAutomaticPackageResolution -resultBundlePath /private/tmp/wander-event-icons-tests.xcresult -only-testing:wanderUITests/MotionDockUITests/testEventsButtonStaysCenteredAcrossRepeatedListToggles test
```

- **TEST SUCCEEDED** : 1 test, 0 échec, 33,905 secondes, quatre cycles.
- Compilation réussie ; aucun avertissement ni erreur dans le journal de ce passage.
- Journal : `/private/tmp/wander-event-icons-tests.log`.
- Captures inspectées sous `/private/tmp/wander-event-icons-evidence/` :
  `365951A2-2B09-4399-8B1E-819E38C16422.png` pour le calendrier et
  `F2F4A7DA-374D-4EE8-A376-0543A80178F2.png` pour la croix.
  Dessins nets, entiers dans le cercle, centrage et diamètre conservés.
- Les signatures PNG et dimensions de chaque variante ont été vérifiées.
  Le manifeste du calendrier était déjà correct et reste inchangé ; celui
  de la croix référence désormais explicitement les trois densités.
- Relecture des assets et manifestes sans anomalie. Aucun changement Swift dans
  ce travail ; les changements de participation antérieurs sont préservés.
- Simplification : aucun code à simplifier, uniquement des assets générés.
  Code review: skipped (mechanical diff). Remplacement de PNG et déclaration
  des densités, vérifiés par inspection visuelle, manifestes et test existant.
- Trois notes Obsidian actualisées, `updated` modifié, wikiliens préservés.
  Obsidian n'a pas été ouvert.
- Aucun nouveau constat dans `todos/` ni apprentissage nécessitant une note
  supplémentaire dans `docs/solutions/`. Les noms et tailles suivent le
  catalogue existant ; aucune nouvelle règle ni technique n'est introduite.
- Résultat iOS : PASS. Surface vérifiée : bouton événements ouvert/fermé.
  Erreurs de console attribuables au changement : 0. Vérification humaine
  demandée : 0. Échec résiduel : 0. Le ressenti haptique physique n'est pas
  vérifié au simulateur ; son code reste inchangé.

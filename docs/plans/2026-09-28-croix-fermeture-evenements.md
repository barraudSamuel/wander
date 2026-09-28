---
title: Croix de fermeture des événements
status: completed
completed_at: 2026-09-28
date: 2026-09-28
---

# Résultat et périmètre

Plan présenté dans la conversation puis explicitement approuvé par Samuel.
Afficher l'image de croix fournie lorsque les événements sont ouverts, puis
le calendrier quand ils sont fermés. Conserver les 56 points, le cadrage
circulaire, le centrage et l'impact haptique léger à chaque appui.

## Fichiers concernés

- `wander/Assets.xcassets/TabIconEventsClose.imageset/Contents.json` et
  `TabIconEventsClose.png` : import sans modification du PNG fourni.
- `wander/NativeMapTabView.swift` : choix de l'asset selon `isEventsPresented`.
- `wanderUITests/MotionDockUITests.swift` : captures des états ouvert et fermé
  dans le test de bascules existant.
- Le présent plan.
- Dans `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Documentation UX.md`, `Documentation technique.md`, `Backlog features.md`,
  `00 - Wander.md`. Actualiser `updated` et conserver les wikiliens.

## Mise en œuvre

- [x] Importer le PNG fourni et sélectionner l'asset selon l'état existant.
- [x] Ajouter les captures dans le test existant, sans nouveau test dédié.
- [x] Relire et simplifier le delta.
- [x] Compiler et vérifier les bascules sur l'iPhone 17 déjà démarré.
- [x] Inspecter les captures pour vérifier le cadrage et les deux images.
- [x] Actualiser les quatre notes Obsidian et consigner les résultats.

## Risques, validation et limites

Le cadrage circulaire pourrait couper la croix : vérifier les captures réelles.
La source est un PNG carré 1024 × 1024, importé tel quel et affiché avec le
composant existant. Vérifier l'inclusion de l'asset, l'ouverture et la fermeture
répétées, le centrage stable et le retour au calendrier.

Utiliser `MotionDockUITests/testEventsButtonStaysCenteredAcrossRepeatedListToggles`.
Pas de capture attendue artificielle ni de test qui recopie le choix d'asset :
les assertions existantes vérifient le parcours, les captures le rendu.
Le ressenti haptique sur appareil réel reste une limite déjà signalée.

## Contraintes

Conserver les travaux précédents. Aucune commande Git mutante.
Pas de nouveau simulateur ni de tests d'accessibilité dédiés.
XcodeBuildMCP absent dans cette session : validation CLI équivalente.
L'illustration fournie est explicitement demandée par Samuel.
Pas de nouvelle note de solution attendue pour ce changement courant.

## Validation et revue

- Commande : `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'platform=iOS Simulator,id=6F13855D-10B8-45AF-9205-17C8393379E3' -parallel-testing-enabled NO -disableAutomaticPackageResolution -only-testing:wanderUITests/MotionDockUITests/testEventsButtonStaysCenteredAcrossRepeatedListToggles test`.
- Résultat : **TEST SUCCEEDED**, 1 test, 0 échec, quatre cycles ouverture/fermeture.
  Source et tests recompilés. Avertissements AppIntents préexistants uniquement.
- Journal : `/private/tmp/wander-events-close-tests.log`.
- Résultats : `/Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx/Logs/Test/Test-wander-2026.09.28_11-51-23-+0900.xcresult`.
- Captures inspectées :
  `/private/tmp/wander-events-close-evidence/4C837786-EF57-4F9E-B5DA-33DDDA716A65.png`
  pour la croix, et
  `/private/tmp/wander-events-close-evidence/785ABFB7-A2ED-4F86-8DA2-C39E886EA34A.png`
  pour le retour au calendrier. Croix entière dans le cercle, centrage conservé.
- PNG importé identique à la source par SHA-256, 904129 octets. Aucun traitement
  de l'image nécessaire ; affichage par le composant SwiftUI existant.
- Simplification : réutilisation et qualité revues par les agents, aucun constat.
  La limite de threads a empêché la troisième relance ; revue efficacité effectuée
  localement avec le même rubric, sans constat. Le choix d'asset utilise l'état
  existant, sans nouvelle observation ni traitement par image.
- Revue de code légère sans anomalie :
  `/private/tmp/compound-engineering-501/ce-code-review/events-close-20260928/review.json`.
- Décision : choisir l'image depuis `isEventsPresented` pour éviter un second
  état à synchroniser. Les transitions existantes pilotent à la fois la sélection
  et l'illustration. Aucun changement d'action, de taille ou de retour haptique.
- Quatre notes Obsidian mises à jour, `updated` actualisé, wikiliens conservés.
- `git diff --check` réussi. Aucun nouveau constat ou apprentissage à consigner.
  Le ressenti haptique physique reste non vérifié, comme avant ce changement.

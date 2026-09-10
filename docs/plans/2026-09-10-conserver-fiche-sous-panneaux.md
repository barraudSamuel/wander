---
title: "Conserver la fiche et la carte sous les panneaux de navigation"
status: completed
date: 2026-09-10
approved_at: 2026-09-10
completed_at: 2026-09-10
owner: Samuel
tags: [plan, ios, navigation]
---

# Superposer les panneaux sans fermer la fiche

Samuel a validé le plan présenté dans la conversation par « je valide ».

## Résultat

Amis et Profil s’ouvrent par-dessus la carte et sa fiche éventuelle. Fermer le
panneau restitue la même fiche, sa hauteur et la même caméra. Le rendu et les
gestes de la barre native sont conservés. Cette décision remplace la fermeture
automatique de fiche prévue par le premier plan du 10 septembre.

## Périmètre et fichiers

- `wander/ContentView.swift` : retirer la fermeture de la fiche au changement de
  panneau et conserver l’observation de la sortie sélectionnée en dessous.
- `wanderUITests/MapSocialGestureUITests.swift` : tester une fiche redimensionnée,
  les changements Amis/Profil et les différentes fermetures du panneau.
- `wander/DebugSocialMapScenario.swift` seulement si le scénario doit être adapté.
- Ce plan, les plans antérieurs concernés et le constat dans `todos/`.
- Vault `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Backlog features.md`, `Documentation technique.md`, `Documentation UX.md`,
  `00 - Wander.md`, avec `updated` et les wikilinks conservés.

Aucun changement de barre, d’assets, de données Firebase, de modèle ou de règle.
Aucune commande Git mutante. Pas de nouvelle présentation ni de nouveau service.

## Diagnostic

La vidéo `ScreenRecording_09-10-2026 14-09-38_1.MP4` montre la fiche de sortie qui
disparaît dès l’ouverture d’Amis. Le `onChange(of: dockSelection)` de ContentView
affecte explicitement `nil` à `selectedMapDetail`, ce qui ferme MapDetailSplitView
et modifie la portion de carte visible. L’observation du détail est aussi coupée
quand le panneau est ouvert. Le scénario DEBUG n’exécute pas ce gestionnaire de
ContentView ; ses tests précédents ne pouvaient pas détecter cette fermeture.

## Étapes

- [x] Enregistrer l’approbation et le diagnostic de la vidéo.
- [x] Ajouter le parcours UI de conservation d’une fiche redimensionnée.
- [x] Retirer la fermeture automatique et garder l’observation du détail.
- [x] Vérifier sur l’iPhone 17 existant, relire le code et les captures.
- [x] Actualiser les quatre notes, les plans et le constat.

## Risques et validation

Le panneau bloque les interactions sous-jacentes ; un toucher extérieur doit
fermer seulement le panneau. La fermeture volontaire de fiche, les nouvelles
sélections carte et les actions « afficher sur la carte » restent possibles.
Une sortie supprimée ou un ami devenu inaccessible doivent toujours être réconciliés.

Vérifier la caméra et la hauteur de fiche après Explorer, second appui et toucher
extérieur, ainsi que le passage Amis vers Profil. Rejouer le test natif
d’appui maintenu/glissement et le test de clavier. La vidéo et le gestionnaire de
production constituent la preuve initiale ; le scénario local vérifie la
superposition mais ne prétend pas exécuter les routes Firebase de ContentView.

Simulateur autorisé : iPhone 17, `6F13855D-10B8-45AF-9205-17C8393379E3`.

## Relecture ciblée

La modification de production retire uniquement le gestionnaire qui fermait la
fiche au changement de panneau et la condition de sélection liée au dock dans
l’observation des participants. Les fermetures volontaires et la réconciliation
d’une sortie disparue ou d’une amitié supprimée sont toujours présentes.

Conformément au parcours `ce-debug` pour un checkout contenant des modifications
antérieures, simplification de fichiers entiers écartée et revue manuelle limitée
au diff de ce correctif. Aucun défaut supplémentaire relevé. Le scénario DEBUG
conserve son montage existant et la limite de couverture décrite plus haut.

## Validation finale

- Build Debug réussi et 3 tests UI réussis sur l’iPhone 17 autorisé :
  `MapSocialGestureUITests/testDockPanelsPreserveResizedMapDetail`,
  `MotionDockUITests/testKeyboardAndDraftSurvivePanelSwitch` et
  `MotionDockUITests/testUsesNativeTabBarAndSupportsPressThenSlide`.
- Le nouveau parcours agrandit la fiche par glissement, ouvre Amis puis Profil,
  ferme via Explorer, second appui et toucher extérieur. Il vérifie à chaque
  retour le titre, la hauteur et l’origine de fiche, les dimensions de la portion
  de carte visible et la position de l’annotation utilisateur. La fermeture
  volontaire de la fiche est encore possible ensuite.
- Journal : `/tmp/wander-preserve-detail-tests.log`. Résultat Xcode :
  `Test-wander-2026.09.10_14-15-15-+0900.xcresult`, dans Logs/Test du DerivedData Wander.
- Les captures Amis, Profil et après fermeture dans
  `/tmp/wander-preserve-detail-captures` confirment la fiche conservée en arrière-plan.
  Extrait vidéo : `/tmp/wander-preserve-detail-preview.mp4`.
- Les quatre notes Obsidian ont été actualisées et les anciens plans renvoient
  à cette décision. Aucun lancement d’Obsidian. Constat consigné dans le todo 046.
- `git diff --check` réussi. Aucun nouvel avertissement Swift ; seul l’avertissement
  préexistant d’extraction AppIntents apparaît dans le build.
- Pas de nouvelle fiche `ce-compound` : la cause, le retrait du gestionnaire et
  la limite du scénario sont déjà explicités par ce plan et le constat ciblé.

Les routes authentifiées et l’observation Firebase réelle restent vérifiées par
lecture du diff et des gardes du service ; le test UI utilise les données locales.

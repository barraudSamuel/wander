---
title: Retour haptique du bouton événements
status: completed
completed_at: 2026-09-28
date: 2026-09-28
---

# Résultat et périmètre

Plan présenté dans la conversation et explicitement approuvé par Samuel.
Émettre un impact léger à chaque appui sur le bouton événements, à l'ouverture
comme à la fermeture, selon le motif UIKit déjà utilisé dans l'app.

## Fichiers concernés

- `wander/NativeMapTabView.swift` : action du bouton événements.
- Le présent plan.
- Dans `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Documentation UX.md`, `Documentation technique.md`, `Backlog features.md`.
  Actualiser `updated` et préserver les wikiliens.

## Mise en œuvre

- [x] Ajouter `UIImpactFeedbackGenerator(style: .light).impactOccurred()` dans
  l'action existante du bouton, avant son callback.
- [x] Relire et simplifier le changement dans son périmètre.
- [x] Compiler et exécuter le test existant de bascules répétées sur l'iPhone 17.
- [x] Mettre à jour les trois notes Obsidian et consigner les résultats.

## Risques et validation

Un seul impact par activation, pas de déclenchement pendant les mises à jour
d'état ni depuis le bouton profil. L'action et les gardes existantes restent
inchangées. Vérifier le site d'appel et utiliser le test existant
`MotionDockUITests/testEventsButtonStaysCenteredAcrossRepeatedListToggles`.
Pas de test qui simule le générateur ou recopie l'implémentation : le simulateur
ne permet pas d'évaluer la sensation physique. Le ressenti sur iPhone réel sera
signalé comme non vérifié, sans prétendre qu'un test UI valide la vibration.

## Contraintes

Conserver les travaux précédents. Aucune commande Git mutante.
Utiliser uniquement l'iPhone 17 déjà démarré, sans test d'accessibilité dédié.
Exécution native locale, pas de changement Firebase ou d'autre contrôle.
XcodeBuildMCP absent dans cette session : workflow CLI équivalent selon AGENTS.md.
Pas de nouvelle note de solution attendue pour cet ajout courant.

## Validation et revue

- Commande : `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'platform=iOS Simulator,id=6F13855D-10B8-45AF-9205-17C8393379E3' -parallel-testing-enabled NO -disableAutomaticPackageResolution -only-testing:wanderUITests/MotionDockUITests/testEventsButtonStaysCenteredAcrossRepeatedListToggles test`.
- Résultat : **TEST SUCCEEDED**, 1 test, 0 échec. Quatre bascules répétées
  ouverture/fermeture conservent le centrage et le comportement du panneau.
- Journal : `/private/tmp/wander-events-haptic-tests.log`.
- Résultats : `/Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx/Logs/Test/Test-wander-2026.09.28_11-23-59-+0900.xcresult`.
- Source recompilée et application liée pendant cette exécution. Avertissement
  AppIntents préexistant sans dépendance au framework ; aucun nouveau diagnostic
  Swift dans la source modifiée. `git diff --check` réussi.
- Simplification : revues réutilisation, qualité et efficacité terminées,
  aucune correction nécessaire. Revue de code légère sans constat actionnable :
  `/private/tmp/compound-engineering-501/ce-code-review/events-haptic-20260928/review.json`.
- Décision : déclencher l'impact dans l'action du bouton, pas sur le changement
  d'état du panneau, pour éviter un retour lors de mises à jour programmatiques.
  Le composant partagé et le profil ne changent pas.
- Les trois notes Obsidian approuvées sont mises à jour, `updated` actualisé,
  wikiliens conservés. Aucun nouveau constat ni apprentissage à consigner.
- Limite : le ressenti haptique physique n'a pas été vérifié sur appareil réel.
  Le succès du test UI valide le parcours, pas la vibration.

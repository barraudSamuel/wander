---
title: Supprimer le rail d’amis
status: completed
completed_at: 2026-09-20
approved_at: 2026-09-20
---

## Objectif et périmètre

Supprimer la roue d’amis et son geste de bord droit, conformément au plan
approuvé par Samuel (« je valide »). Conserver les accès aux amis depuis
l’onglet Amis et les annotations de carte. Aucun changement Firebase.

## Fichiers concernés

- `wander/ContentView.swift`
- `wander/DebugSocialMapScenario.swift`
- `wander/FriendEdgeRailView.swift` et `wander/RightEdgePanGestureView.swift` : suppression.
- Ce plan et `todos/` si une validation reste bloquée.
- Vault `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/` :
  `Backlog features.md`, `Documentation UX.md`, `Documentation technique.md`, `00 - Wander.md`.

## Étapes

- [x] Retirer les intégrations et les deux composants dédiés.
- [x] Mettre à jour les quatre notes et leur propriété `updated`.
- [x] Compiler et vérifier l’absence de références Swift résiduelles.
- [ ] Vérifier la carte sur l’iPhone 17 déjà démarré.
- [x] Relire le diff et consigner les limites de validation.

## Risques et validation

Le retrait du conteneur peut affecter la disposition des commandes ou les gestes
MapKit. Conserver le ZStack et ses modificateurs. Vérifier avec `git diff --check`,
une compilation Debug iOS Simulator et le simulateur existant, sans démarrer
ni créer de simulateur. Aucun test d’accessibilité dédié.

## Critères d’acceptation

La roue et son capteur de geste sont retirés des cartes de production et de debug.
L’application compile. La documentation décrit la suppression. Toute validation
interactive indisponible est explicitement consignée.

## Résultats et revue

- Compilation Debug réussie, code de sortie 0, puis confirmation incrémentale
  après le retrait du paramètre `friendSummaries` devenu inutile dans `exploreTab`.
- Commande : `xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/wander-derived-data -disableAutomaticPackageResolution build`.
- Journaux : `/tmp/wander-remove-rail-build.log` et `/tmp/wander-remove-rail-build-final.log`.
- Deux avertissements préexistants de CFBundleVersion : extensions 15 et 27,
  application 42. Suivi dans `todos/054-ready-p2-aligner-build-extensions.md`.
- `git diff --check` réussi. Aucune référence aux types supprimés dans les
  sources Swift ou le projet Xcode. Diff relu : contenu de carte et commandes conservés.
- Quatre notes Obsidian mises à jour, propriété `updated` actualisée,
  wikilinks conservés. Obsidian n’a pas été ouvert.
- Test interactif non réalisé : aucun appareil démarré selon
  `xcrun simctl list devices booted`. Aucun simulateur démarré ou créé.
  Suivi dans `todos/053-ready-p3-valider-suppression-rail-amis.md`.
- Décision principale : retirer le conteneur en conservant ses enfants et
  leurs modificateurs. Masquer simplement la roue aurait laissé du code mort.
- Incertitude restante : validation fonctionnelle du panoramique et du
  placement des commandes sur simulateur. Aucun défaut lié au changement identifié.
- Changement courant, sans leçon nouvelle justifiant une note `docs/solutions/`.

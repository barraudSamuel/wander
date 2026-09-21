---
title: "Aligner la zone tactile et le bouton de fermeture du profil ami"
status: in_progress
date: 2026-09-21
approved_at: 2026-09-21
approval: "je valide après le plan révisé : rôle close, taille native et forme tactile sur le bouton complet"
---

# Résultat attendu

Un clic au centre ou légèrement sur les côtés de la croix ferme la fiche.
Le bouton retrouve sa taille native initiale et garde le style Liquid Glass
circulaire. Samuel a invalidé le correctif de label à 44 × 44 points après essai :
il a agrandi le contrôle sans supprimer la zone inactive.

## Révision approuvée le 21 septembre

- [x] Dans `wander/FriendProfileSheet.swift`, utiliser
  `Button(role: .close, action: content.onClose)` avec son label système
  explicitement affiché en icône seule via `.labelStyle(.iconOnly)`.
- [x] Supprimer le cadre du label ; conserver `.glass`, `.circle` et
  `.controlSize(.regular)`. Appliquer `contentShape(.interaction, Circle())`
  au bouton complet, avant la marge extérieure `.padding(16)`.
- [x] Conserver le libellé accessible et le callback unique de fermeture.
- [x] Dans `wanderUITests/MapSocialGestureUITests.swift`, adapter le test existant
  aux positions horizontales 50 %, 10 % et 90 %, à mi-hauteur. Retirer les
  décalages fixes et le minimum de 44 points. Un seul clic par ouverture.
- [x] Revoir et simplifier ce seul incrément, puis compiler l’app et les tests.
- [x] Actualiser ce plan, le suivi 060, `Documentation UX.md` et
  `Backlog features.md`, avec leurs propriétés `updated`.
- [ ] Confirmer sur appareil le rendu compact et la fermeture après un seul clic
  au centre et près des bords. Aucune exécution autorisée dans cet incrément.

La cause exacte du clic perdu reste non démontrée en exécution. Le callback ne
dépend pas du point touché. Le cadre précédent dimensionnait le label avant le
style, pas le diamètre final du bouton. L’approche approuvée utilise le label
système et définit la forme tactile sur le contrôle complet. La compilation
seule ne prouvera ni la taille rendue ni la fiabilité des clics. Aucun simulateur
ne sera démarré et aucun test ne sera exécuté ; le suivi 060 restera ouvert pour
la validation sur appareil.

Références Apple consultées :

- [Button init(role:action:)](https://developer.apple.com/documentation/swiftui/button/init(role:action:)) et [ButtonRole.close](https://developer.apple.com/documentation/swiftui/buttonrole/close) : label système de fermeture depuis iOS 26.
- [ContentShapeKinds.interaction](https://developer.apple.com/documentation/swiftui/contentshapekinds/interaction) : forme utilisée pour le hit-testing.
- [GlassButtonStyle](https://developer.apple.com/documentation/swiftui/glassbuttonstyle) : style natif du contrôle.
- [Signalement Apple](https://developer.apple.com/forums/thread/800099) : animation sans action avec certains labels image ; cela ne prouve pas la cause dans Wander.

HEAD au début de cette révision : `7e7c6a783fa3fae1608df8fe64b717be1ebf1d2e`.
Les changements préexistants de fermeture et de recentrage sont conservés.

## Résultat de la révision approuvée

L’implémentation et la validation autorisée sont terminées. Le statut reste
`in_progress` jusqu’à confirmation du résultat tactile ; l’absence d’erreur de
compilation n’est pas une preuve de disparition de la zone inactive.

- Bouton système `.close`, icône seule, taille `.regular` sans cadre forcé.
  Forme interactive sur le bouton avant la marge de 16 points. Aucun autre
  contrôle, geste, callback ou changement de caméra ajouté.
- Test existant adapté aux coordonnées normalisées du bouton, un seul clic
  par ouverture. Aucun test ni simulateur exécuté conformément à la consigne.
- Simplification `ce-simplify-code` : trois passes indépendantes de réutilisation,
  qualité et efficacité ; aucun finding retenu, aucune modification supplémentaire.
- Code review: skipped (ce-code-review unavailable). L’invocation ciblée a échoué
  car le résolveur de scope exige des endpoints Git/PR et ne sait pas isoler les
  snapshots de cet incrément. Revue de correction indépendante réalisée
  manuellement : aucun défaut confirmé. Son conseil de conserver explicitement
  `.labelStyle(.iconOnly)` a été appliqué et recompilé. Rapport :
  `/tmp/wander-native-close-review.json`. Le diff final a été relu localement.
- Compilation finale réussie : `xcodebuild -project wander.xcodeproj -scheme wander
  -configuration Debug -destination 'generic/platform=iOS Simulator'
  -disableAutomaticPackageResolution -skipPackageUpdates CODE_SIGNING_ALLOWED=NO
  build-for-testing`. Résultat `TEST BUILD SUCCEEDED` dans
  `/tmp/wander-native-close-final-build.log`, code de sortie 0. Aucune erreur ni
  avertissement Swift ; deux avis App Intents indiquent une extraction de
  métadonnées ignorée faute de dépendance `AppIntents.framework`.
- `git diff --check` réussi. Snapshots avant révision :
  `/tmp/wander-native-close-before/` ; diff isolé : `/tmp/wander-native-close.diff`.
- `Documentation UX.md` et `Backlog features.md` mises à jour dans le vault
  prévu, avec `updated: 2026-09-21T13:27:11+09:00`, wikilinks préservés.
- Aucun enseignement fonctionnel présenté comme confirmé : le premier essai
  ayant échoué malgré une compilation réussie, le suivi 060 reste ouvert.

## Portée approuvée

- `wander/FriendProfileSheet.swift` : label système, taille native et forme interactive.
- `wanderUITests/MapSocialGestureUITests.swift` : clic au centre, à gauche, à droite.
- Ce plan et `todos/060-ready-p2-valider-profils-bottom-sheet.md`.
- Vault `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Documentation UX.md` et `Backlog features.md`, avec leur propriété `updated`.

L’extension de coordination du viewport proposée dans le plan de recentrage
reste non approuvée. Cette approbation porte sur le bouton. Les modifications
précédentes du même travail sont conservées ; aucun Git mutable, commit ou envoi.

## Historique du premier essai, invalidé sur appareil

Le premier essai imposait un label `Image` de 44 × 44 points et une forme
interactive circulaire à l’intérieur du label. Le test cliquait au centre et à
±16 points. L’app et les tests avaient compilé dans
`/tmp/wander-close-hit-build.log`, et la revue statique n’avait pas relevé de
défaut concret. Aucun test n’avait été exécuté. Samuel a ensuite confirmé sur
appareil que ce changement agrandissait le bouton sans corriger la zone inactive.
Cet essai ne constitue donc pas une solution validée et la présente révision
remplace son implémentation.

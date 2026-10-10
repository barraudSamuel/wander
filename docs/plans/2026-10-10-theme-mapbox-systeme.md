---
title: Synchroniser Clair pastel avec le thème iOS
status: completed
completed_at: 2026-10-10T09:43:15+09:00
date: 2026-10-10
approved_at: 2026-10-10
owner: Samuel
---

# Synchroniser Clair pastel avec le thème iOS

Plan présenté dans la conversation et explicitement approuvé par Samuel.

## Résultat et périmètre

Conserver Clair pastel en mode clair et intégrer une variante sombre anthracite,
routes ardoise, parcs vert profond et eau bleu discret. Suivre l'apparence iOS
au lancement, lors d'une bascule et au retour au premier plan. Garder caméra,
repères, interactions et cellules explorées. Aucun sélecteur supplémentaire.

## Fichiers concernés

- `wander/MapboxConfiguration.swift`
- `wander/MapWithFogView.swift`
- `wanderTests/MapboxAppearanceTests.swift`
- `docs/README.md`
- Ce plan.
- Coffre `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Backlog features.md`, `Documentation technique.md`, `Documentation UX.md`.
  Actualiser leur propriété `updated` sans ouvrir Obsidian.

## Exécution

Travail natif inline dans le checkout actuel. Les modifications préexistantes
sont celles des thèmes précédents de cette conversation et sont conservées.
Aucune commande Git mutante, branche, commit ou publication.

- [x] Approbation explicite.
- [x] Palettes et propagation de l'apparence iOS.
- [x] Tests ciblés, compilation et vérification visuelle.
- [x] Simplification et revue.
- [x] Documentation et captures.

## Risques et validation

Vérifier le dernier thème demandé pendant le chargement Mapbox, l'absence de
recentrage, le rétablissement du brouillard et les repères. La maquette générée
est une direction de couleurs, pas une référence pixel par pixel.

Utiliser uniquement le simulateur iPhone 17 Pro déjà démarré
`C0DADF07-7E14-4D5E-AE4B-B17844A9C454`. Compiler Debug, tester les bascules et
les tests existants du renderer, inspecter clair/sombre et retour au premier plan.
Pas de tests d'accessibilité dédiés. Les nouvelles vérifications d'apparence
portent sur la carte native et sa caméra plutôt que sur les constantes de couleur.
Les captures précédentes caractérisent le comportement clair existant.

## Acceptation

- [x] Le thème suit iOS au démarrage et à chaud dans les deux sens.
- [x] Caméra, repères et exploration conservés.
- [x] Validation et revue documentées.
- [x] Notes Obsidian mises à jour ou limitation exacte signalée.

## Ajustement du rendu et simplification

La première inspection montre que le preset `night` assombrit une seconde fois
les couleurs sombres explicites. Le preset reste donc `day` pour les deux
palettes ; c'est la palette elle-même qui suit le thème iOS. Cela garde la
lisibilité de l'anneau exploré et correspond à la direction de la maquette.

`ce-simplify-code` : trois lectures indépendantes terminées (réutilisation,
qualité, efficacité). Aucune correction nécessaire. Une suggestion de variables
locales pour les couleurs répétées n'a pas été retenue : le mapping explicite
reste court et permet de lire chaque option avec ses deux valeurs. Aucun
nouveau wrapper ou contrôleur supplémentaire.

Les tests d'apparence exercent le vrai style configuré avec le jeton local.
Ils sont ignorés explicitement si aucun jeton public n'est configuré. Les tests
existants de brouillard restent indépendants des tuiles. Pas de preuve rouge
avant modification : la référence claire a été caractérisée par les captures
précédentes, puis la nouvelle propagation est vérifiée sur la carte native et
par une bascule réelle du système, sans test de constantes de couleurs.

Référence API : https://docs.mapbox.com/ios/maps/guides/styles/set-a-style/

## Validation finale

Projet `wander.xcodeproj`, scheme `wander`, Debug, iPhone 17 Pro existant,
iOS 26.3. Compilation réussie. Une surface carte testée.

| Flux | Résultat | Preuve |
| --- | --- | --- |
| Démarrage sombre | PASS | Test natif et capture `02-dark.png` |
| Dernier thème demandé pendant chargement | PASS | `testLastAppearanceWinsDuringInitialLoading` |
| Aller-retour sans perte de caméra ni brouillard | PASS | `testSwitchingBothWaysPreservesCameraAndFog` |
| Renderer, cellules et rechargement | PASS | 4 tests `MapboxFogRendererTests` |
| Pan, pinch et double tap | PASS | 2 tests UI, première passe |
| Bascule système à chaud dans les deux sens | PASS | Captures 03 et 04 |
| Retour depuis l'arrière-plan | PASS | Capture 05, cadrage et repères conservés |

9 tests distincts passent dans la première validation. Après l'ajustement de
lumière, recompilation puis les 7 tests natifs repassent ; les deux tests de
gestes ne sont pas répétés pour ce seul changement de couleur. Aucun test
ignoré sur cette machine. Aucun nouveau warning Swift ; avertissements
AppIntents préexistants, 4 dans la compilation initiale puis 2 dans l'incrémentale.

Console : 0 erreur capturée dans les stdout/stderr du scénario visuel final,
les deux fichiers sont vides. Les tests natifs émettent les messages Mapbox
`Invalid size ... fallback ... {64, 64}` lors de la construction initiale à
`.zero`, comportement préexistant de la factory ; leurs tailles sont ensuite
fixées et les vérifications réussissent. Aucun crash ni échec de test.
Vérifications humaines requises : 0. Échecs restants : 0. Résultat : **PASS**.
Pas de validation sur appareil physique ni de nouveaux échanges Firebase.
Le scénario utilise des données synthétiques et de vraies tuiles.

### Commandes et preuves

Options communes Xcode :

```bash
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'platform=iOS Simulator,id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' -derivedDataPath /Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx -disableAutomaticPackageResolution -skipPackageUpdates -parallel-testing-enabled NO build-for-testing
```

Validation initiale : mêmes options, `test-without-building`,
`-only-testing:wanderTests/MapboxAppearanceTests`,
`-only-testing:wanderTests/MapboxFogRendererTests`,
`-only-testing:wanderUITests/MapSocialGestureUITests/testNativePanClosesGroupAndMovesMap`,
`-only-testing:wanderUITests/MapSocialGestureUITests/testNativePinchAndDoubleTapZoom`,
`-resultBundlePath /tmp/wander-system-theme-validation.xcresult`.
La deuxième validation conserve seulement les deux groupes natifs et écrit
`/tmp/wander-system-theme-validation-2.xcresult`.

Logs : `/tmp/wander-system-theme-build.log`,
`/tmp/wander-system-theme-build-2.log`,
`/tmp/wander-system-theme-validation.log`,
`/tmp/wander-system-theme-validation-2.log`,
`/tmp/wander-system-theme-final-stdout.log`,
`/tmp/wander-system-theme-final-stderr.log`.
Les deux derniers sont copiés depuis le répertoire `data/tmp` du simulateur.

Captures : `/Users/samuelbarraud/.codex/visualizations/2026/10/09/01a122f5-3532-75a0-8b63-e8eca3c2d3a5/system-theme/` :
`01-light.png`, `02-dark.png`, `03-light-after-switch.png`,
`04-dark-after-switch.png`, `05-dark-after-background.png`.
Le simulateur reste démarré ; l'apparence claire initiale est restaurée.

## Revue et documentation

`ce-code-review mode:agent base:HEAD` : terminé, aucun constat retenu.
Reçu : `/tmp/compound-engineering-501/ce-code-review/20261010-system-theme-5120975d/review.json`.
Revue lite inline du diff suivi ; les nouveaux tests non suivis sont inspectés
et exécutés séparément lors de la validation. Aucun constat à ajouter à `todos/`.
Le README et les trois notes Obsidian sont actualisés avec leur propriété
`updated` et leurs wikilinks préservés. Aucun commit ni opération Git mutante.

Décision principale : conserver l'éclairage `day` pour les couleurs sombres
explicites. Le preset `night` testé noircissait excessivement le fond.
La maquette générée n'est pas reproduite pixel par pixel : le style Standard
conserve ses halos de labels et certains détails cartographiques.

`ce-compound` : **Documentation skipped**. Le choix de lumière est expliqué
dans le code, le README et ce plan. Une note de solution supplémentaire ne
conserverait pas de raisonnement absent de ces sources.


## Retour au clair uniquement, approuvé le 10 octobre 2026

Samuel a demandé de supprimer la version sombre puis a validé le plan de retrait.
Ce changement remplace le comportement livré ci-dessus ; les preuves restent
historiques. Retirer les couleurs sombres et la propagation iOS dans
`MapboxConfiguration.swift` et `MapWithFogView.swift`, supprimer
`wanderTests/MapboxAppearanceTests.swift`, actualiser ce plan, `docs/README.md`
et les notes Obsidian `Backlog features.md`, `Documentation technique.md`,
`Documentation UX.md` du coffre existant. Conserver leurs wikilinks et actualiser
`updated`. Aucun changement Git, aucune nouvelle interface ou donnée.

- [x] Retirer le mode sombre et ses tests spécifiques.
- [x] Compiler et vérifier le brouillard et les repères avec iOS sombre.
- [x] Revoir le retrait et mettre à jour la documentation.

Risque : laisser un appel à l'ancienne API de thème ou une description obsolète.
Validation : compilation, tests existants du renderer, bascule iOS sur le seul
simulateur déjà démarré, inspection de la carte claire. Aucun test dédié
supplémentaire pour ce retrait simple. Les contrôles iOS gardent leur comportement
natif ; seule la cartographie reste claire.


### Validation du retrait

Résultat **PASS**. Projet `wander.xcodeproj`, scheme `wander`, Debug,
iPhone 17 Pro existant, iOS 26.3. Compilation réussie et 4 tests
`MapboxFogRendererTests` réussis. Une surface carte inspectée : carte claire
après passage iOS en sombre, brouillard et repères présents. Les commandes
natives suivent toujours iOS. Réglage clair initial du simulateur restauré.
Vérification humaine requise : 0. Échec restant : 0.

Commandes : options Xcode communes décrites plus haut, `build-for-testing`,
puis `test-without-building -only-testing:wanderTests/MapboxFogRendererTests`
avec `-resultBundlePath /tmp/wander-light-only-validation.xcresult`.
Logs : `/tmp/wander-light-only-build.log`, `/tmp/wander-light-only-validation.log`.
Les 4 avertissements AppIntents préexistants restent ; aucun nouveau warning
Swift. Les stdout/stderr du scénario sont copiés depuis `data/tmp` du simulateur
vers `/tmp/wander-light-only-stdout.log` et `/tmp/wander-light-only-stderr.log`.
Ils sont vides : zéro erreur capturée dans ce périmètre.

Capture : `/Users/samuelbarraud/.codex/visualizations/2026/10/09/01a122f5-3532-75a0-8b63-e8eca3c2d3a5/light-only/clair-pastel-ios-sombre.png`.

Simplification : trois lectures réutilisation, qualité et efficacité, aucun
constat. Revue `ce-code-review` lite terminée, aucun constat, reçu :
/tmp/compound-engineering-501/ce-code-review/20261010-light-only-7a7032f5/review.json.
Le README et les trois notes Obsidian sont à jour ; `updated` est actualisé,
les wikilinks préservés. Aucun constat à ajouter à `todos/`.
`ce-compound` : Documentation skipped, retrait simple sans nouvel enseignement.
Aucune opération Git mutante ni commit.

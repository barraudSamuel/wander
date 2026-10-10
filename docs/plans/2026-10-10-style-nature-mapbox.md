---
title: "Appliquer le style Nature à la carte Mapbox"
status: completed
date: 2026-10-10
approved_at: 2026-10-10
started_at: 2026-10-10
completed_at: 2026-10-10T08:34:00+09:00
owner: Samuel
tags: [plan, map, mapbox, design]
---

# Appliquer le style Nature à la carte Mapbox

## Outcome

La carte principale reprend l'ambiance 06 choisie par Samuel : verts mousse,
tons terre, eau bleu lac et routes claires. Le rendu final est une carte
vectorielle Mapbox réelle, inspirée de la maquette générée, avec les données
géographiques, le brouillard H3 et les marqueurs existants.

Le plan a été présenté dans la conversation en statut `proposed`. Samuel l'a
explicitement approuvé avec « je valide » le 10 octobre 2026.

## Scope and approach

- Remplacer Streets par Mapbox Standard personnalisé avec le SDK 11.32.0
  déjà installé. Configurer la palette au chargement de la carte.
- Conserver une projection plane, un fond 2D et une lumière de jour stable.
- Préserver le masque d'exploration, les marqueurs, les gestes et les
  contrôles iOS. Adapter uniquement le rendu du brouillard si Standard
  requiert un réglage d'éclairage ou d'ordre des couches.
- Vérifier le rendu réel et les interactions sur l'iPhone 17 Pro déjà démarré.
- Documenter la configuration et les validations dans le dépôt et les trois
  notes Obsidian identifiées avant approbation.

## Non-goals

Pas de sélecteur de thèmes, de mode nuit supplémentaire, de terrain 3D,
de texture satellite, de nouveau SDK ou de modification des données,
de Firebase, des permissions ou de l'interface autour de la carte.
Aucune opération Git mutante, aucun commit, aucune publication.

## Dependencies and affected files

- `wander/MapboxConfiguration.swift`
- `wander/MapboxFogRenderer.swift`, seulement si une adaptation est nécessaire
- `wanderTests/MapboxFogRendererTests.swift`, seulement si le contrat change
- `docs/README.md`
- `docs/plans/2026-10-10-style-nature-mapbox.md`
- Constats de revue éventuels dans `todos/`, enseignement vérifié éventuel
  dans `docs/solutions/`, suivant les règles du dépôt.
- Coffre Obsidian existant, dossier `sam/wander` :
  - `Backlog features.md` : statut du style Nature.
  - `Documentation technique.md` : tableau d'architecture et Moteur Mapbox.
  - `Documentation UX.md` : Carte et progression.
  Mettre à jour `updated` et préserver les wikilinks. Une autorisation
  technique ciblée est nécessaire pour écrire hors du dépôt ; ne pas créer
  de coffre de substitution si cet accès est indisponible.

## Implementation checklist

- [x] Lire le code, le SDK installé et les recommandations officielles.
- [x] Obtenir l'approbation explicite et enregistrer le plan approuvé.
- [x] Configurer la palette Nature et la carte plane en 2D.
- [x] Vérifier et adapter si nécessaire le brouillard.
- [x] Simplifier les changements et compiler l'app et les tests.
- [x] Exécuter les tests concernés et vérifier les vraies tuiles en simulateur.
- [x] Effectuer la revue du diff et traiter ses constats.
- [x] Actualiser le README et les trois notes Obsidian.
- [x] Enregistrer les preuves, limites et captures, puis clôturer le plan.

## Risks and validation

- Une maquette générée ne correspond pas exactement à la cartographie réelle.
  Vérifier la palette sur des rues, des bâtiments, des espaces verts et de l'eau.
- Standard utilise des imports et un éclairage différent de Streets :
  contrôler l'ordre du masque, sa teinte, les cellules révélées et la présence
  des marqueurs, y compris après déplacement et changement de zoom.
- Utiliser les tests existants de `MapboxFogRendererTests`,
  `MapboxFogGeometryTests`, `MapViewportViewTests` et les scénarios ciblés de
  `MapSocialGestureUITests`. Pas de test qui ne ferait que répéter les couleurs
  configurées ; la palette est vérifiée sur une capture réelle.
- Build Debug et tests ciblés à taille de texte standard, sur le seul
  simulateur déjà démarré. Ne pas créer, télécharger ni démarrer de simulateur.
- Vérifier recentrage, déplacement, zoom, sélection d'un marqueur et mentions
  Mapbox. Aucun test d'accessibilité dédié.
- XcodeBuildMCP n'est pas exposé par cette session. Appliquer l'équivalent
  manuel autorisé par AGENTS.md avec Xcode CLI et l'outil de contrôle UI.

## Acceptance criteria

- [x] Le fond réel présente la palette Nature en 2D.
- [x] Le brouillard conserve les zones explorées et les marqueurs restent utilisables.
- [x] Compilation et tests ciblés réussis ; captures inspectées.
- [x] Documentation et notes Obsidian actualisées, ou limitation exacte signalée.

## Validation and review notes

L'état initial du dépôt est propre. Travail local sur le checkout existant,
sans modification des refs Git. La configuration du jeton reste intacte.
Le simulateur existant est l'iPhone 17 Pro, iOS 26.3,
`C0DADF07-7E14-4D5E-AE4B-B17844A9C454`.

La configuration est un import JSON local de Standard, avec projection Mercator
et palette au premier chargement. Le brouillard garde une couche sans slot,
au-dessus du fond, et une force émissive de 1 pour stabiliser sa teinte.
La passe `ce-simplify-code` ne trouve pas de logique à factoriser : le diff est
une configuration de style et un réglage de rendu, sans abstraction nouvelle.
Les tests existants restent inchangés ; des assertions sur les codes couleur
répéteraient la configuration sans vérifier le résultat visuel.

### Résultats du 10 octobre 2026

Projet `wander.xcodeproj`, scheme `wander`, configuration Debug :
`build-for-testing` réussi, puis 25 tests ciblés réussis, sans échec.
Les deux commandes utilisent les options communes suivantes, sans téléchargement
de paquet ni création de simulateur :

```bash
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'platform=iOS Simulator,id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' \
  -derivedDataPath /Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx \
  -disableAutomaticPackageResolution -skipPackageUpdates \
  -parallel-testing-enabled NO build-for-testing

xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'platform=iOS Simulator,id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' \
  -derivedDataPath /Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx \
  -disableAutomaticPackageResolution -skipPackageUpdates \
  -parallel-testing-enabled NO test-without-building \
  -only-testing:wanderTests/MapboxFogRendererTests \
  -only-testing:wanderTests/MapboxFogGeometryTests \
  -only-testing:wanderTests/MapViewportViewTests \
  -only-testing:wanderUITests/MapSocialGestureUITests/testNativePanClosesGroupAndMovesMap \
  -only-testing:wanderUITests/MapSocialGestureUITests/testNativePinchAndDoubleTapZoom \
  -only-testing:wanderUITests/MapSocialGestureUITests/testOwnAvatarOpensSheetWithoutCalloutAndReopensAfterDismissal \
  -only-testing:wanderUITests/MapSocialGestureUITests/testCardBodyRecentersAfterMapPanAndRepeatedTap \
  -resultBundlePath /tmp/wander-nature-validation.xcresult
```

| Vérification | Résultat |
| --- | --- |
| Viewport (7), géométrie H3 (10), renderer (4) | 21 tests réussis |
| Déplacement, pinch/double tap, profil, recentrage | 4 tests UI réussis |
| Palette sur bâtiments, routes, parcs et cours d'eau de Séoul | Inspectée sur les vraies tuiles |
| Masquer puis réafficher les zones explorées | Masque uniforme puis anneau révélé restauré ; îlot central préservé |
| Marqueurs et attribution Mapbox | Visibles au-dessus du fond ; interactions couvertes par les tests UI |
| Revue `ce-code-review`, diff local contre `HEAD` | Aucun constat, aucun fichier de correction dans `todos/` nécessaire |
| README et trois notes Obsidian approuvées | Actualisés ; frontmatter `updated` et wikilinks conservés |

Preuves locales :

- Compilation : `/tmp/wander-nature-build.log`.
- Tests : `/tmp/wander-nature-validation.log` et
  `/tmp/wander-nature-validation.xcresult`.
- Revue : `/tmp/compound-engineering-501/ce-code-review/20261010-082825-82e6da48/review.json`.
- [Zones explorées et palette réelle](/Users/samuelbarraud/.codex/visualizations/2026/10/09/01a122f5-3532-75a0-8b63-e8eca3c2d3a5/nature-map/01-nature-zones-explorees.png).
- [Brouillard uniforme après masquage](/Users/samuelbarraud/.codex/visualizations/2026/10/09/01a122f5-3532-75a0-8b63-e8eca3c2d3a5/nature-map/02-nature-brouillard.png).

La compilation n'ajoute aucun avertissement Swift dans les fichiers modifiés.
Quatre avertissements AppIntents préexistants restent présents. Les 14 messages
Mapbox de taille invalide proviennent des fixtures des tests natifs, comme dans
la validation précédente (`/tmp/wander-hide-compass.log`). La session visuelle
ne produit aucun message sur stdout/stderr ; cela ne remplace pas un audit
complet des logs système. Le résultat fonctionnel est validé par les tests et
l'inspection de l'écran.

La validation visuelle utilise `-debug-social-map -debug-social-map-fullscreen
-debug-social-map-fog`, donc de vraies tuiles Mapbox avec des données locales
synthétiques. Le bouton de bascule des zones est propre à ce scénario Debug.
Pas de validation d'échanges Firebase, de performance sur appareil physique
ou de test d'accessibilité dédié dans ce changement. Le simulateur existant
reste affiché avec le style Nature.

### Compound

Documentation skipped pour `ce-compound` : aucun nouvel enseignement non évident
ne justifie une note supplémentaire dans `docs/solutions/`. La configuration
locale, la projection et la teinte du brouillard sont expliquées dans le code,
le README et la documentation technique Obsidian.

## References

- [Mapbox Standard configuration](https://docs.mapbox.com/map-styles/reference/standard/)
- [Migration Mapbox validée](2026-10-09-remplacer-mapkit-par-mapbox.md)

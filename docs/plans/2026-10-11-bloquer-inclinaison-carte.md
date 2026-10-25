---
status: completed
date: 2026-10-11
completed_at: 2026-10-11
---

# Bloquer l'inclinaison de la carte

Plan approuvé par Samuel le 2026-10-11 dans le chat, « je vlaide ».

## Résultat et périmètre

Conserver la carte vue du dessus en désactivant le geste d'inclinaison Mapbox.
Le zoom, le déplacement et la rotation à plat restent disponibles.
Aucun changement de données, de style ou de navigation.

## Fichiers concernés

- `wander/MapboxConfiguration.swift` : désactiver le geste à la création de la carte.
- `docs/plans/2026-10-11-bloquer-inclinaison-carte.md` : suivi et validation.
- Vault `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md` : comportement de la carte et propriété `updated`.
- Même vault, `Backlog features.md` : livraison du verrouillage et propriété `updated`.

## Checklist

- [x] Approbation explicite.
- [x] Désactiver l'inclinaison dans la configuration partagée.
- [x] Mettre à jour les deux notes Obsidian.
- [x] Compiler pour le simulateur.
- [x] Vérifier déplacement et zoom sur le simulateur déjà ouvert ; limites ci-dessous.
- [x] Relire le diff et consigner les résultats.

## Risques et validation

Risque principal : gêner les autres gestes. Utiliser uniquement l'option native
d'inclinaison et vérifier zoom, déplacement et rotation. Aucun nouveau simulateur
ne sera démarré. Aucun test d'accessibilité dédié.

Les skills Compound Engineering sont indisponibles ; suivi manuel du workflow.
Pas de note de solution pour ce réglage courant, sauf découverte réutilisable.

## Résultats et revue

La création partagée conserve `pitch: 0` et désactive uniquement
`mapView.gestures.options.pitchEnabled`. L'interface du SDK installé confirme
que cette option est indépendante de `rotateEnabled`, `panEnabled` et du zoom.
Les autres écritures de caméra dans l'app imposent zéro ou conservent le pitch
initial. Aucune autre modification de code nécessaire.

Compilation et deux tests UI réussis sur l'iPhone 17 Pro déjà ouvert,
UUID `C0DADF07-7E14-4D5E-AE4B-B17844A9C454`, iOS 26.3 :

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'platform=iOS Simulator,id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' -disableAutomaticPackageResolution -parallel-testing-enabled NO -only-testing:wanderUITests/MapSocialGestureUITests/testNativePanClosesGroupAndMovesMap -only-testing:wanderUITests/MapSocialGestureUITests/testNativePinchAndDoubleTapZoom test
```

Résultat : 2 tests, 0 échec. Journal : `/tmp/wander-flat-map-tests.log`.
`git diff --check` réussit. Aucun avertissement du compilateur Swift ; l'outil
AppIntents signale une extraction de métadonnées ignorée faute de dépendance
AppIntents. La première tentative confinée a échoué faute d'accès aux caches
Xcode ; la validation avec les permissions adaptées a réussi.

Les deux notes Obsidian et leurs propriétés `updated` ont été mises à jour,
sans ouvrir Obsidian. Aucun constat de code à consigner dans `todos/`.

Décision : employer le réglage natif le plus étroit. Un intercepteur de gestes
ou des corrections répétées de caméra ajouteraient du code inutile.
Limite : l'inclinaison bloquée et la rotation conservée sont vérifiées par
relecture du réglage et des écritures de caméra, sans geste manuel dédié.
Les tests UI couvrent le déplacement, le pincement et le double toucher.

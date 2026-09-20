---
id: "057"
title: Vérifier la largeur et la hauteur de la barre native
status: ready
priority: P2
source: review
created: 2026-09-20
tags: [ios, navigation, validation]
---

## Constat

La capture utilisateur après le premier essai confirme l’absence de changement
visible avec `itemWidth = 64` et `itemSpacing = 8`. Ces réglages ont été retirés.

Le correctif suivant héberge la vraie barre dans un contrôleur enfant dont le
conteneur est centré, limité à 75 % de la largeur sûre et plafonné à 320 points.
La carte et les panneaux restent dans un hosting plein écran distinct. Un
filtre de touchers laisse passer les gestes hors barre vers ce contenu.
La réserve inférieure vient du guide public du contrôleur d’onglets et le
conteneur suit le haut du clavier.

Samuel approuve ensuite une réduction uniforme supplémentaire de 10 % en
largeur et en hauteur, icônes comprises. Une transformation 0,9 du conteneur
conserve le bord inférieur par translation. La largeur apparente du conteneur
est de 67,5 % de la zone sûre, plafonnée à 288 points. Les réserves des panneaux
sont converties après application de la transformation.

La compilation réussit. Le rendu et les interactions de cette nouvelle
composition restent non vérifiés : Samuel a demandé une compilation seule.

## Preuves

- `wander/NativeMapTabView.swift`.
- `docs/plans/2026-09-20-barre-navigation-compacte.md`.
- `/tmp/wander-compact-tab-container-build.log` : BUILD SUCCEEDED, code 0.
- `/tmp/wander-compact-tab-scale-build.log` : BUILD SUCCEEDED, code 0, après réduction uniforme.

## Critères de validation ultérieure

- [ ] Le fond de la barre est centré, 10 % moins large et moins haut que la
  version au conteneur réduit, en conservant l’ancrage inférieur.
- [ ] Les icônes suivent la même réduction de 10 %, sans déformation ; les
  zones tactiles restent confortables.
- [ ] Explorer, Amis et Profil répondent au toucher, au second appui et au
  maintien suivi du glissement ; les panneaux restent correctement positionnés.
- [ ] Le panoramique reste possible à gauche, au centre et à droite de la
  carte ; les champs des panneaux répondent au toucher sous le conteneur transparent.
- [ ] Le clavier garde les trois onglets accessibles et les panneaux utilisables.

Vérifier sur appareil à taille de texte standard avant de considérer le
résultat visuel comme validé. Ne pas démarrer de simulateur sans nouvel accord.

---
title: "Redimensionner les fiches carte en continu"
status: completed
date: 2026-09-08
approved_at: 2026-09-08
completed_at: 2026-09-08
owner: Samuel
---

# Redimensionner les fiches carte en continu

## Résultat approuvé

Samuel approuve une ouverture autour du tiers de l'écran, adaptée aux limites
du téléphone, et un résumé qui grandit avec le panneau pour utiliser la place
disponible. Texte, emojis et avatars suivent le geste et le calage au relâchement.
Le titre, la fermeture et les actions restent fixes. Le défilement intervient
si la taille minimale lisible ne tient plus. Aucun test ni build ne sera lancé,
conformément à sa consigne maintenue ; validation par relecture seulement.

## Constat

L'enregistrement fourni montre des mots qui se chevauchent pendant le resize.
Le panneau anime sa position tandis que GestureState réinitialise séparément
la translation et que le texte riche hérite de l'animation. Sa taille est aussi
plafonnée à 21 points, indépendamment du contenu, ce qui laisse un grand vide.
Les tests existants observent les positions finales, pas les images intermédiaires.

## Mise en œuvre

- [x] Remplacer la somme position/translation par une hauteur pilotée en continu,
  interpolée une seule fois pour toute la disposition.
- [x] Ouvrir à un tiers et adapter les intitulés des positions accessibles.
- [x] Mesurer le texte riche avec le même rendu natif qui l'affiche, puis choisir
  la plus grande taille tenant dans le rectangle disponible, sans plafond de 21 pt.
- [x] Conserver les avatars intégrés, emphases, emojis, états, boutons et callbacks.
- [x] Adapter les attentes UI liées aux anciennes positions, sans les exécuter.
- [x] Relire, simplifier et mettre à jour les notes produit et techniques.

## Fichiers concernés

- `wander/MapDetailSplitView.swift` : geste, disposition animable, ouverture à 33 %.
- `wander/MapDetailFittingText.swift` : aide native de mesure et de rendu du résumé.
- `wander/OutingPlanDetailCardView.swift` et `wander/FriendProfileSheet.swift` :
  contenu riche et états des deux panneaux.
- `wanderUITests/MapSocialGestureUITests.swift` : attentes de positions existantes.
- Ce plan et éventuels constats de revue sous `todos/`.
- Coffre Obsidian `sam/wander` : `Backlog features.md`, `Documentation UX.md`,
  `Documentation technique.md` et `00 - Wander.md`. Mettre à jour `updated` et
  préserver les liens, sans ouvrir Obsidian.

## Contraintes et risques

La surface native MapKit doit conserver ses dimensions plein écran. Le doigt,
le relâchement, l'annulation du geste, la rotation et Réduire les animations
doivent partager le même calcul borné. Le rendu natif UILabel mesure les mêmes
attributs et images que ceux affichés ; les mesures et images sont réutilisées
pour limiter le travail pendant le geste. Les changements de lignes restent
naturels, sans interpolation indépendante de la position des mots.

Dynamic Type fixe la taille minimale, et le contenu long reste intégralement
accessible par défilement. Les noms des participants restent disponibles pour
VoiceOver. Les positions relatives des amis continuent à se rafraîchir.

## Validation prévue

Relecture du diff, cohérence des références et `git diff --check` uniquement.
Aucun Git mutateur, test, compilation, lancement du simulateur ou validation
visuelle revendiquée. La fluidité sur iPhone restera à confirmer manuellement.

## Résultat et revue

La hauteur affichée pilote le geste et l'animation de calage. L'ouverture utilise
un tiers de la hauteur utile dans les limites du téléphone. La position agrandie
rejoint la limite haute tout en conservant la portion minimale de carte.
MapDetailArrangement conserve le slot et les dimensions natives de MapKit.

MapDetailFittingText mesure et affiche les mêmes attributs UIKit. Les mesures
récentes réduisent la recherche pendant le geste, avec un cache borné à
64 entrées. Le nombre d'avatars reste stable pendant la recherche de police.
Le texte long garde sa hauteur minimale et défile ; les états natifs et actions
gardent leur espace. Les durées des amis continuent de se rafraîchir, avec le
rafraîchissement suspendu pour les états sans position utilisable.

Les trois relectures de simplification ont couvert réutilisation, qualité et
efficacité. Les constats sur les mesures répétées et le rafraîchissement des
états statiques sont corrigés puis relus. Le constat sur Augmenter le contraste
est corrigé en transmettant aussi ce réglage et en l'incluant dans les caches.
Voir `todos/038-done-p2-reutiliser-mesures-pendant-redimensionnement.md` et
`todos/039-done-p2-preserver-contraste-du-texte-mesure.md`.

La revue de correction SwiftUI/UIKit est effectuée manuellement sur les fichiers
complets et le diff de cette itération. Le pipeline automatique ce-code-review
exclut les nouveaux fichiers non suivis ; son périmètre ne convient pas ici et
aucun staging Git n'est autorisé. Le nouveau fichier est donc inclus dans la
relecture manuelle. Aucun autre défaut concret n'est relevé dans le geste,
les limites, le débordement minimal et la conservation de la carte native.

## Validation effectuée et limites

- Relecture des deux panneaux, des appels au composant partagé, des réglages
  d'accessibilité et des attentes de positions UI adaptées.
- `git diff --check` sans erreur. Les autres changements déjà présents dans
  le dépôt, dont AGENTS.md, sont conservés.
- Les quatre notes Obsidian prévues sont mises à jour. Propriétés `updated`,
  cibles des wikilinks et blocs Markdown vérifiés dans les fichiers seulement.
  Obsidian n'a pas été ouvert, aucun rendu n'est revendiqué.
- Aucun test, build, compilation ni lancement du simulateur. Les résultats
  des itérations précédentes ne valident pas ce nouveau rendu.

L'implémentation approuvée et la relecture sont terminées. La fluidité pendant
le geste, au relâchement et lors de son interruption, ainsi que l'occupation
du panneau agrandi, restent à confirmer sur iPhone. Aucune nouvelle solution
réutilisable n'est publiée dans docs/solutions sans cette validation réelle.

## Reprise après retour Xcode

La capture de Samuel révèle huit diagnostics de syntaxe sur les deux appels
à MapDetailPanel. La première closure placée après les parenthèses portait
incorrectement le label `supporting:`. Ce label est retiré dans les fiches
événement et joueur ; la closure suivante conserve `actions:`. Le contenu
et les callbacks restent identiques.

La relecture précédente avait manqué cette erreur. Correction relue et
`git diff --check` vérifié, sans test ni build. La compilation complète reste
non vérifiée. Constat : `todos/040-done-p1-corriger-syntaxe-appels-fiches.md`.

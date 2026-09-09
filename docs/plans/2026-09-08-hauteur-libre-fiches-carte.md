---
title: "Choisir librement la hauteur des fiches carte"
status: completed
date: 2026-09-08
approved_at: 2026-09-08
completed_at: 2026-09-08
owner: Samuel
---

# Choisir librement la hauteur des fiches carte

## Résultat approuvé

Après le plan proposé dans la conversation, Samuel précise le comportement
voulu : minimum actuel, maximum de 85 %, toutes les positions intermédiaires
libres. Le palier de secours à 50 % n'est pas nécessaire, le conteneur accepte
déjà une hauteur continue. L'ouverture reste autour du tiers de la hauteur utile.

## Portée

Retirer le calage et la projection de vitesse au relâchement. Conserver la
proportion choisie à la rotation, bornée aux dimensions et à Dynamic Type.
Les raccourcis au toucher restent disponibles ; VoiceOver peut ajuster la
hauteur personnalisée et annonce sa valeur. Aucun changement au contenu,
aux actions métier, à la mesure du texte ni au rendu natif MapKit.

## Fichiers concernés

- `wander/MapDetailSplitView.swift`.
- `wanderUITests/MapSocialGestureUITests.swift`, attentes du geste existant.
- Ce plan et éventuels constats de revue dans `todos/`.
- Coffre Obsidian `sam/wander` : `Documentation UX.md`,
  `Documentation technique.md`, `Backlog features.md`, `00 - Wander.md`.
  Mettre à jour `updated` et les passages sur les paliers. Ne pas ouvrir Obsidian.

## Mise en œuvre

- [x] Conserver une hauteur personnalisée dans l'état du panneau, sans calage
  au relâchement ni à l'annulation du geste.
- [x] Garder le minimum existant et borner le maximum à 85 % de la hauteur utile.
- [x] Conserver la proportion personnalisée après rotation et une ouverture à 33 %.
- [x] Adapter le toucher et VoiceOver aux hauteurs intermédiaires.
- [x] Adapter les attentes UI existantes sans exécution.
- [x] Relire les changements et actualiser les quatre notes Obsidian.

## Risques et validation

Relâchement, annulation, interruption d'un raccourci animé et changement de
dimensions ne doivent pas ajouter la translation deux fois. Les limites
protègent les commandes fixes et la portion visible de carte. La taille native
MapKit reste indépendante du geste.

La consigne de Samuel reste active : aucun test, build, compilation ou lancement
de simulateur. Relecture des sources et du diff, `git diff --check`, contrôle
des propriétés et liens des notes sur disque. La validation sur appareil reste
à faire. Aucun Git mutateur ni publication.

## Résultat et revue

Position.custom contient la fraction choisie ; l'état de fraction séparé a été
retiré. onEnded utilise la translation réelle, et l'annulation conserve la
dernière hauteur affichée. Les raccourcis au toucher sont conservés. VoiceOver
annonce le pourcentage personnalisé et l'ajuste par pas de cinq points.

Le minimum reste 140 points suivant Dynamic Type plus 80 points réservés,
borné à l'espace disponible. Le maximum vaut désormais exactement 85 % de
la hauteur utile, également sur les grandes fenêtres. La mesure du texte,
les actions métier et le rendu natif de la carte ne changent pas.

Les trois relectures de simplification couvrent réutilisation, qualité et
efficacité. La revue de correction couvre aussi la syntaxe Swift, les fins
de geste et la rotation. Le repère du geste est conservé avec son origine,
puis rejeté s'il devient obsolète. Les mises à jour sans effet aux limites
sont évitées. Voir `todos/041-done-p2-ignorer-translation-apres-rotation.md`.

Le test de glissement existant attend une hauteur intermédiaire correspondant
à un déplacement de 137 points ; il n'attend plus un palier. Il n'a pas été
exécuté. Les autres attentes de raccourcis restent inchangées.

## Validation effectuée

- Diff de cette itération et références relus ; `git diff --check` sans erreur.
- Les quatre notes Obsidian sont actualisées sur disque avec leur propriété
  updated. Les cibles des wikilinks et les blocs Markdown sont contrôlés.
  Obsidian n'a pas été ouvert.
- Aucun test, build, compilation, simulateur ou contrôle sur appareil lancé.
  La fluidité et les hauteurs réelles restent à confirmer manuellement.
- Les modifications préexistantes, dont AGENTS.md et le projet Xcode, sont
  conservées. Aucun Git mutateur ni publication.

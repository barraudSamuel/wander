---
id: "038"
title: "Réutiliser les mesures pendant le redimensionnement"
status: done
priority: P2
source: code-review
created: 2026-09-08
tags: [todo, map, performance, swiftui]
---

# Réutiliser les mesures pendant le redimensionnement

## Constat de revue

La première version du texte ajusté ne réutilisait que la dernière proposition
exacte. Chaque hauteur différente pendant un geste ou son calage pouvait donc
reconstruire et mesurer le texte jusqu'à treize fois. Le profil actualisait
également sa vue chaque seconde en mode fantôme ou sans position, alors que
son contenu ne dépendait pas du temps.

## Résolution

- [x] Conserver au plus 64 mesures de tailles de police pour la largeur courante.
- [x] Invalider ce cache lorsque le contenu, la largeur, l'apparence ou la taille
  minimale changent.
- [x] Utiliser les hauteurs déjà mesurées pour borner la recherche suivante,
  en conservant sa précision de 0,1 point.
- [x] Suspendre le TimelineView lorsque la position est absente ou masquée,
  sans remplacer le sous-arbre du panneau.

Le label de mesure reste séparé du label affiché pour éviter d'invalider celui-ci
à chaque candidat. Les durées visibles gardent une cadence d'une seconde ; la
précision affichée dépend du formateur natif et de ses unités non nulles.

## Validation

Relecture de la résolution, des invalidations et de la borne mémoire. Aucun
test, build ou benchmark exécuté, conformément à la demande de Samuel. Le gain
de fluidité n'est pas mesuré sur appareil.

Plan : [Redimensionner les fiches carte en continu](../docs/plans/2026-09-08-redimensionner-fiches-en-continu.md).

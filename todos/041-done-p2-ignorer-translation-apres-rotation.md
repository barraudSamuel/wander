---
id: "041"
title: "Ignorer la translation devenue obsolète après rotation"
status: done
priority: P2
source: code-review
created: 2026-09-08
tags: [todo, map, gestures, swiftui]
---

# Ignorer la translation devenue obsolète après rotation

## Constat

Effacer l'origine d'un geste lorsque les dimensions changent permettait au
prochain onChanged de capturer une nouvelle origine, puis d'y ajouter la
translation totale de l'ancien geste. Cette branche pouvait déplacer de
nouveau la fiche après une rotation pendant le glissement.

## Résolution

DragOrigin conserve la hauteur affichée initiale et la hauteur utile du repère.
Les valeurs du geste sont ignorées si ce repère a changé. La position
personnalisée conserve sa fraction ; onEnded ou l'annulation efface l'origine.

La revue a aussi retiré une écriture nil redondante après relâchement et les
animations sans déplacement aux limites des ajustements VoiceOver.

## Validation

Relecture indépendante du changement d'origine et du traitement de fin de
geste. Aucun test ni build exécuté à la demande de Samuel ; aucune reproduction
ou réussite sur appareil n'est revendiquée.

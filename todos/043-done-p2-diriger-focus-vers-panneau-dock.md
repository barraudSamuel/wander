---
id: "043"
title: "Diriger le focus vers le panneau ouvert"
status: done
priority: P2
source: code-review
created: 2026-09-10
completed_at: 2026-09-10
tags: [todo, ios, accessibility]
---

# Entrer dans le contenu du panneau avec VoiceOver

## Constat

L'ouverture plaçait explicitement le focus sur la commande Amis ou Profil, située
après le contenu dans l'ordre de lecture. Le nouveau contenu n'était pas ciblé.

## Résolution

Le panneau porte un titre accessible explicite. L'ouverture cible ce titre.
Le correctif de barre native remplace les symboles et leur taille personnalisée
par les assets d’origine, dimensionnés par iOS. Une fermeture programmatique
vers Explorer signale le changement de disposition à VoiceOver en ciblant la
barre native. Le texte du contenu conserve Dynamic Type.

Relecture ciblée indépendante effectuée. Le parcours VoiceOver vocal reste à
confirmer selon `044-ready-p2-valider-dock-sur-compte-reel.md`.

Plan : [panneaux Amis et Profil](../docs/plans/2026-09-10-panneaux-amis-profil.md).

Correctif : [barre native](../docs/plans/2026-09-10-retablir-barre-native.md).

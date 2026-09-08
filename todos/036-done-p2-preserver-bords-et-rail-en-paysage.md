---
id: "036"
title: "Préserver le plein écran et le geste du rail en paysage"
status: done
priority: P2
source: code-review
created: 2026-09-08
completed_at: 2026-09-08
tags: [todo, map, safe-area, ios]
---

# Préserver le plein écran et le geste du rail en paysage

## Constats

La première retouche ignore uniquement les safe areas verticales, puis applique
les insets horizontaux au contenu. En paysage, elle conserve donc des bords vides
et compte deux fois leurs marges. Le capteur UIScreenEdgePan du rail est aussi
décalé vers l'intérieur avec la liste, ce qui l'éloigne du bord physique où le
toucher commence.

## Résolution

- [x] Le conteneur ignore les safe areas sur les quatre bords. La fiche reçoit
  séparément les insets de son contenu.
- [x] Le rail reste dans la zone sûre ; son capteur est placé au bord droit
  physique et conserve les mêmes limites verticales et coordonnées Y locales.
- [x] Les insets leading/trailing sont convertis selon la direction de mise
  en page, avec des alignements explicites vers la droite physique.
- [x] Le scénario UI plein écran reprend le TabView et le rail. La rotation
  vérifie les quatre bords, puis un glissement depuis le bord ouvre le rail.
  Son contenu est accessible et reste éloigné du bord droit système.

Résultats : `/tmp/wander-fullscreen-final.xcresult`, 56/56 ; contrôle étendu du
rail après correction : `/tmp/wander-fullscreen-rail-final.xcresult`, 1/1.
Le rendu plein écran en paysage a aussi été relu directement dans Simulator,
preuve `/tmp/wander-fullscreen-landscape-verified.png`.
Voir le [plan](../docs/plans/2026-09-08-carte-plein-ecran.md).

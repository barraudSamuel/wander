---
id: "045"
title: "Préserver la barre native et les zones sûres des panneaux"
status: done
priority: P2
source: user-regression
created: 2026-09-10
completed_at: 2026-09-10
tags: [todo, ios, navigation, regression]
---

# Barre native et panneaux indépendants

La barre SwiftUI personnalisée avait supprimé les assets et les interactions
Liquid Glass du composant système. Les icônes participaient à son animation.
Le correctif utilise un vrai `UITabBarController`, les trois assets d’origine
et un hosting de carte persistant. Seuls les panneaux s’animent.

Les guides UIKit alimentent les zones sûres SwiftUI : panneau avant la barre,
fiche carte sous l’encoche et contenu disponible avec le clavier. Sept tests UI
passent, puis le test natif renforcé par deux appuis rapides. La séquence vidéo
du changement Amis vers Profil ne montre plus d’icône déplacée dans le panneau.

La couverture sur compte réel et VoiceOver reste décrite dans le todo 044.
Voir [le plan de correction](../docs/plans/2026-09-10-retablir-barre-native.md).

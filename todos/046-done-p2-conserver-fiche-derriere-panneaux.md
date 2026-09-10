---
id: "046"
title: "Conserver la fiche carte derrière Amis et Profil"
status: done
priority: P2
source: user-feedback
created: 2026-09-10
completed_at: 2026-09-10
tags: [todo, ios, navigation]
---

# Conserver l’écran sous les panneaux

La vidéo utilisateur montrait la disparition de la fiche de sortie au clic sur
Amis. ContentView effaçait explicitement la sélection et suspendait l’observation
du détail dès que le panneau quittait Explorer.

Le correctif retire ce lien : la fiche et sa hauteur restent en place, avec
l’observation de la sortie sélectionnée. Les actions volontaires et les gardes
d’accès aux données restent en place. La barre native est inchangée.

Trois tests UI passent, dont une fiche redimensionnée conservée après les trois
fermetures de panneau. Les captures confirment la superposition. Le scénario
DEBUG ne passe pas par les gestionnaires ContentView ; la vidéo et la lecture
du gestionnaire supprimé fondent le diagnostic de production.

Voir [le plan et la validation](../docs/plans/2026-09-10-conserver-fiche-sous-panneaux.md).

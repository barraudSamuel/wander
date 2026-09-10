---
id: "044"
title: "Valider le dock avec compte réel et VoiceOver"
status: ready
priority: P2
source: code-review
created: 2026-09-10
tags: [todo, ios, accessibility, validation]
---

# Couverture complémentaire du dock

Le scénario UI emploie le composant de production et MapKit, avec du contenu
local. Il ne configure pas Firebase et n'exécute pas la suppression d'un compte.

- [ ] Sur appareil, VoiceOver annonce le titre après ouverture ou changement de
  panneau, permet de parcourir les actions et revient à Explorer après Échapper.
- [ ] Les demandes d'amis, erreurs réseau et fiches s'ouvrent depuis le panneau.
- [ ] Des notifications d'ami et de sortie reçues pendant une confirmation du
  profil restent en attente, puis s'ouvrent après annulation ou fin de l'action.
- [ ] Vérifier les réglages système Réduire les animations et la transparence.

Ne pas supprimer de compte réel pour ce contrôle ; utiliser un compte de test
explicitement autorisé si le parcours doit dépasser sa confirmation.

Plan : [panneaux Amis et Profil](../docs/plans/2026-09-10-panneaux-amis-profil.md).

---
id: "062"
title: "Valider les actions d’amitié réelles depuis le profil"
status: ready
priority: P2
source: review
created: 2026-09-22
updated: 2026-09-28
tags: [todo, friends, map, validation]
---

## Constat

Le déplacement approuvé le 27 septembre remplace la liste sous la carte par les
sections du profil personnel. Le bouton Amis et la séparation correspondante
sont supprimés. Ce constat conserve son chemin historique pour les références.

La compilation réussit et les parcours locaux s’exécutent sur l’iPhone 17 déjà
démarré. Le plan du 27 septembre tient le bilan détaillé des tests. Le scénario
local simule les actions ; il ne prouve pas la synchronisation Firebase, les
erreurs réseau ni la livraison des notifications.

## Critères d’acceptation

- [ ] Avec des comptes de test, accepter/refuser une demande, consulter une
  invitation en attente et retirer un ami avec confirmation depuis son profil.
- [ ] Vérifier la réception APNs et l’ouverture du profil sur la demande concernée.
- [ ] Vérifier les erreurs réseau et leur consultation après fermeture puis
  réouverture du profil pendant une action en cours.

## Références

- Plan actuel : `docs/plans/2026-09-27-amis-dans-profil.md`.
- Plan remplacé : `docs/plans/2026-09-22-amis-sous-carte.md`.
- Invitation depuis le profil : `todos/061-ready-p2-valider-invitations-profil.md`.

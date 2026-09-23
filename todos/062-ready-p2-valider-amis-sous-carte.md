---
id: "062"
title: "Valider la liste des amis sous la carte sur iPhone 17"
status: ready
priority: P2
source: review
created: 2026-09-22
tags: [todo, friends, map, validation]
---

## Constat

Amis utilise désormais la séparation carte/liste des événements. La carte
reste interactive, les invitations sont gérées dans la liste basse et les
fiches individuelles restituent la liste à leur fermeture. Le code ami et
l’ajout restent dans le profil personnel.

Les cibles application et tests compilent. Les tests UI sont adaptés mais non
exécutés : seul l’iPhone 16e est démarré, alors que le projet autorise l’iPhone 17.
Le scénario local simule acceptation/refus ; il ne prouve pas la synchronisation
Firebase ni les notifications réelles.

## Critères d’acceptation

- [ ] Sur l’iPhone 17 déjà démarré, exécuter `MotionDockUITests` et les tests
  concernés de `MapSocialGestureUITests` à la taille de texte standard.
- [ ] Vérifier l’ouverture à mi-hauteur, la pleine largeur et le maintien de la
  carte interactive : toucher, déplacement, zoom, pins et cadrage.
- [ ] Vérifier la poignée commune : glissement, agrandissement au toucher,
  repli, retour haptique et fermeture sans saut de cadrage ; interrompre un
  glissement par un changement de présentation.
- [ ] Alterner Amis/Événements après redimensionnement et défilement de chaque
  liste ; retrouver leurs hauteurs et positions respectives, y compris près
  de la fin d’une liste lorsque les hauteurs mémorisées diffèrent.
- [ ] Ouvrir puis fermer son profil et celui d’un ami ; retrouver la liste
  précédente. Vérifier Explorer et un second appui sur Amis pour fermer.
- [ ] Avec des comptes de test, accepter/refuser une demande, consulter une
  invitation en attente et retirer un ami avec confirmation ; vérifier les
  erreurs et l’ouverture d’Amis depuis une notification de demande.
- [ ] Vérifier que les erreurs d’amitié ne présentent pas d’alerte depuis la
  liste masquée et restent consultables à son retour. Alterner vers Événements
  ou un profil pendant une action en cours, puis revenir après succès ou échec.

## Références

- Plan : `docs/plans/2026-09-22-amis-sous-carte.md`.
- Compilation : `/tmp/wander-friends-split-build.log`.
- Invitation depuis le profil : `todos/061-ready-p2-valider-invitations-profil.md`.

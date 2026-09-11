---
id: "047"
title: "Valider la liste d’événements avec un compte réel"
status: ready
priority: P2
source: review
created: 2026-09-10
tags: [todo, ios, events]
---

# Validation distante de la liste d’événements

## Constat

Les tests UI de la liste utilisent les composants de production et des données
locales. Ils vérifient les parcours et le dispatch des actions, mais n’exécutent
pas les observations Firestore authentifiées.

## Preuves

- Plan : `../docs/plans/2026-09-10-liste-evenements-carte.md`.
- Enrichissement social : `../docs/plans/2026-09-10-liste-evenements-sociale-emojis.md`.
- Présentation actuelle : `../docs/plans/2026-09-11-agenda-social-compact.md`.
- Participants et observations de liste : `../docs/plans/2026-09-10-participants-dans-liste-evenements.md`.
- `ContentView` réutilise `mapOutingPlans` et les opérations existantes.
- `OutingPlanService` expose chargement et erreur par propriétaire ; les jetons
  continuent d’écarter les réponses de listeners retirés. Relance limitée aux erreurs.
- Scénarios : `MapSocialGestureUITests/testEventListEmptyLoadingAndErrorStates`
  et `testEventListCanRespondAndCancelWithoutMapTap`.

## Critères d’acceptation

- [ ] Avec deux comptes autorisés, vérifier l’arrivée, la modification et la
  disparition d’une sortie distante pendant la consultation de la liste/fiche.
- [ ] Vérifier une erreur partielle puis « Réessayer », et le retrait d’une amitié.
- [ ] Vérifier l’actualisation des réponses distantes dans les lignes compactes, y compris
  chargement, indisponibilité et refus. Les filtres ont été supprimés.
- [ ] Vérifier les réponses par balayage sur deux événements voisins : bon `eventId`,
  changement des avatars et de l’état, erreur réseau, événement retiré et réponse
  en cours. Confirmer l’ouverture de l’édition du bon événement organisé.
- [ ] Vérifier les avatars après arrivée/départ d’un participant, sur une sortie
  d’ami à laquelle le compte n’a pas répondu, sans ouvrir sa fiche.
- [ ] Confirmer le retrait des observations supplémentaires lorsque les cellules
  sortent du cache natif, qu’un événement disparaît ou qu’Explorer devient inactif.
  Les observations des événements sélectionnés ou rejoints restent indépendantes.
- [ ] Confirmer qu’un changement de publication ou le retrait d’une amitié écarte
  les anciens callbacks et les participants devenus inaccessibles.

## Notes

Limite de validation à reprendre sur un environnement authentifié. Aucun défaut
fonctionnel distant n’a été observé ou supposé à partir des seuls scénarios locaux.

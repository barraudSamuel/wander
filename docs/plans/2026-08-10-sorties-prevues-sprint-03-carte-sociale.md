---
title: "Sorties prévues — Sprint 3 — Affichage social sur la carte"
status: proposed
sprint: 3
date: 2026-08-10
completed_at:
depends_on:
  - "Sprint 1 completed"
  - "Sprint 2 completed"
tags: [plan, sprint, mapkit, friends]
---

# Sprint 3 — Afficher les sorties des amis sur la carte

## Status

Ce sprint est `proposed`. Il requiert les Sprints 1 et 2 en statut `completed`
et une approbation spécifique avant toute modification du code.

## Outcome

La carte affiche la sortie active du compte courant et celles de ses amis
acceptés sous forme d'annotations temporelles distinctes de leurs positions
réelles. Toucher une annotation montre le nom du lieu, l'heure locale et
l'adresse lorsqu'elle existe.

Une sortie disparaît immédiatement lorsque l'amitié est révoquée, lorsque son
document est supprimé ou lorsque `expiresAt` est dépassé.

## Scope

- Écoute directe et incrémentale du document de chaque ami accepté.
- Réconciliation des écouteurs lors des changements d'amitié.
- Filtrage local systématique des documents expirés ou invalides.
- Annotation MapKit dédiée avec SF Symbol temporel.
- Couleur cohérente avec le profil de l'ami, et style distinct pour soi-même.
- Sélection, callout accessible et recentrage sur une sortie.
- Minuteur léger retirant les sorties expirées sans nouvelle écriture serveur.

## Non-goals

- Aucun push ou token d'appareil.
- Aucun affichage public ni lecture de collection globale.
- Aucun trajet prédictif ou position future calculée.
- Aucun bouton de réponse sociale ou discussion.
- Aucune politique TTL de production ; le nettoyage serveur appartient au
  Sprint 5.

## Privacy boundary

Une destination prévue ne doit jamais être représentée comme la position
actuelle de l'utilisateur. Les types d'annotation, icônes, textes et libellés
d'accessibilité doivent employer explicitement « sortie prévue » et une heure.

## Affected files

- `wander/OutingPlanService.swift` — écoute des amis acceptés et expiration.
- `wander/MapWithFogView.swift` — annotations, callouts et recentrage.
- `wander/ContentView.swift` — données transmises à la carte.

## Implementation checklist

- [ ] Ajouter un écouteur direct par ami accepté, sans requête globale.
- [ ] Retirer immédiatement les écouteurs des relations supprimées.
- [ ] Ignorer tout document invalide ou expiré.
- [ ] Mettre en place un minuteur d'expiration sans fuite mémoire.
- [ ] Créer une classe d'annotation dédiée aux sorties.
- [ ] Ajouter un callout natif avec heure locale et adresse facultative.
- [ ] Fournir des libellés VoiceOver non ambigus.
- [ ] Préserver l'ordre des overlays et les annotations de position existantes.
- [ ] Ajouter le recentrage sans perturber le suivi de la position réelle.

## Risks

- Une annotation peut se superposer à la position réelle ; son apparence et son
  texte doivent rester distincts.
- Des écouteurs orphelins pourraient continuer à lire après une révocation.
- Le fuseau du créateur ne doit pas forcer l'affichage chez le destinataire ;
  les dates sont affichées dans le fuseau local de l'appareil.
- Les mises à jour fréquentes de SwiftUI ne doivent pas recréer inutilement les
  annotations MapKit.

## Validation

- [ ] Build Debug iOS réussi sans nouvel avertissement.
- [ ] Deux comptes amis voient la même sortie active.
- [ ] Un compte non ami ne peut ni lire ni afficher la sortie.
- [ ] Position réelle et sortie prévue sont visuellement distinctes.
- [ ] Révocation d'amitié, annulation et expiration retirent le marqueur.
- [ ] Modification d'une sortie met à jour le marqueur existant.
- [ ] Callout, VoiceOver, Dynamic Type et mode sombre vérifiés.
- [ ] Les performances restent stables avec plusieurs amis acceptés.

## Completion record

Renseigner les validations à deux comptes, les captures et `completed_at` avant
de marquer ce sprint `completed`. Arrêter ensuite et demander l'approbation du
Sprint 4.

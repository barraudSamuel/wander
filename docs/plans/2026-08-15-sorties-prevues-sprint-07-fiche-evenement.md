---
title: "Sorties prévues — Sprint 7 — Fiche événement"
status: in_progress
sprint: 7
date: 2026-08-15
proposed_at: "2026-08-15T18:35:00+09:00"
approved_at: "2026-08-15T18:37:28+09:00"
in_progress_at: "2026-08-15T18:37:28+09:00"
rollback_approved_at: "2026-08-15T19:17:07+09:00"
rollback_in_progress_at: "2026-08-15T19:17:07+09:00"
rollback_completed_at: "2026-08-15T19:22:13+09:00"
depends_on:
  - "Sprint 6 completed"
tags: [plan, sprint, swiftui, mapkit, outing, accessibility]
---

# Sprint 7 — Afficher la fiche d’une sortie

## Outcome

Toucher le marqueur d’une sortie prévue affiche une fiche native qui descend
depuis le haut de l’écran, au-dessus de la carte. La fiche présente le lieu,
l’organisateur, la date, l’heure, l’adresse et les participants, puis permet à
un ami de rejoindre ou quitter la sortie sans ouvrir une seconde interface.

La carte reste visible, la fiche reprend les couleurs existantes et se ferme
avec son bouton système ou lorsque la sélection MapKit disparaît. L’ouverture
d’une sortie depuis une notification utilise la même fiche.

## Scope

- Included:
  - sélection bidirectionnelle entre une annotation de sortie et SwiftUI ;
  - fiche supérieure animée avec matériaux, contrôles et symboles système ;
  - informations déjà disponibles dans `OutingPlan` et `MapOutingPlan` ;
  - avatars, total et état de participation synchronisés ;
  - action existante « Je participe » / « Je ne participe plus » ;
  - fermeture explicite, désélection sur la carte et disparition automatique
    d’une sortie expirée, annulée ou devenue inaccessible ;
  - Dynamic Type, VoiceOver, mode sombre et réduction des animations.
- Not included:
  - nouvelle couleur, police, illustration ou dépendance UI ;
  - modification des modèles, des règles Firestore ou des Cloud Functions ;
  - navigation externe, édition de sortie ou liste détaillée des participants ;
  - changement des callouts de position du compte ou des amis.

## Affected files

- `wander/ContentView.swift` — état de sélection et composition de la fiche.
- `wander/MapWithFogView.swift` — synchronisation MapKit et marqueur simplifié.
- `wander/OutingPlanDetailCardView.swift` — contenu SwiftUI de la fiche.
- `docs/plans/2026-08-15-sorties-prevues-sprint-07-fiche-evenement.md` — suivi.
- `todos/` — seulement si la revue découvre une anomalie non résolue.
- `docs/solutions/` — seulement pour un apprentissage réutilisable vérifié.

Le groupe Xcode du projet est synchronisé avec le système de fichiers ; le
nouveau fichier Swift ne doit pas nécessiter de modification manuelle du
`project.pbxproj`.

## Implementation checklist

- [x] Marquer le sprint `in_progress` avant la première modification produit.
- [x] Exposer la sélection d’une sortie depuis le coordinateur MapKit.
- [x] Réconcilier la sélection SwiftUI et la sélection de l’annotation.
- [x] Créer la fiche supérieure avec les informations de sortie.
- [x] Déplacer l’action de participation dans la fiche.
- [x] Retirer le contenu de callout devenu redondant.
- [x] Fermer la fiche lorsque sa sortie n’est plus disponible.
- [x] Respecter VoiceOver, Dynamic Type et la réduction des animations.
- [x] Simplifier et relire le changement.
- [ ] Valider le build et les interactions touchées.

## Risks

- La désélection de l’ancienne annotation lors d’un changement rapide pourrait
  effacer la nouvelle sélection ; le callback doit identifier son propriétaire.
- Une mise à jour SwiftUI ne doit pas resélectionner ou recentrer la carte à
  chaque rafraîchissement des participants.
- La fiche supérieure ne doit pas recouvrir la barre d’état ni rendre les
  contrôles de carte inaccessibles.
- Les tailles d’avatar fixes doivent rester décoratives ; toutes les
  informations doivent rester accessibles sous Dynamic Type et VoiceOver.
- La sortie peut disparaître entre le tap et l’action de participation.

## Validation

- [x] `xcodebuild` Debug générique pour simulateur réussit sans nouvel avertissement.
- [x] L’analyse statique Xcode réussit.
- [ ] Le tap sur une sortie affiche une seule fiche depuis le haut.
- [ ] Fermer la fiche désélectionne le marqueur et permet de le rouvrir.
- [ ] Passer rapidement d’une sortie à une autre conserve la bonne sélection.
- [ ] Une ouverture depuis une notification affiche la fiche correspondante.
- [ ] La participation, son chargement et ses erreurs restent fonctionnels.
- [ ] Expiration, annulation et révocation ferment une fiche devenue invalide.
- [ ] Dynamic Type, VoiceOver, mode sombre et réduction des animations sont vérifiés.
- [x] `git diff --check` réussit.

## Acceptance criteria

- Une seule sortie peut être sélectionnée et présentée à la fois.
- La fiche utilise uniquement les couleurs et composants natifs déjà autorisés.
- Toutes les informations disponibles de la sortie restent lisibles sans
  dépendre de la petite callout MapKit.
- Rejoindre ou quitter une sortie fonctionne depuis la fiche et se met à jour
  en temps réel.
- La carte et les autres types d’annotation conservent leur comportement.
- Aucun changement distant ni de contrat de données n’est effectué.

## Review notes

- Les skills Compound Engineering demandés par le dépôt ne sont pas installés
  dans cette session ; le workflow équivalent est appliqué manuellement.
- La référence visuelle sert uniquement au mouvement et à la hiérarchie ; sa
  palette bleue et ses contrôles personnalisés ne sont pas repris.
- La revue statique n’a trouvé aucune nouvelle journalisation ni dette à
  reporter dans `todos/`.
- Aucun simulateur n’était démarré lors de la validation. Le dépôt interdit
  d’en démarrer un sans autorisation explicite ; les contrôles visuels et
  interactifs restent donc ouverts.
- L’extension proposée ensuite pour présenter les amis dans la même fiche a
  été annulée à la demande du propriétaire ; le callout ami d’origine est
  conservé. Le build générique et l’analyse Xcode réussissent après rollback.

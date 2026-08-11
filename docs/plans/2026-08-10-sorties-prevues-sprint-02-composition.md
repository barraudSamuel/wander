---
title: "Sorties prévues — Sprint 2 — Composer et gérer sa sortie"
status: completed
sprint: 2
date: 2026-08-10
completed_at: "2026-08-11T16:10:48+09:00"
depends_on:
  - "Sprint 1 completed"
tags: [plan, sprint, swiftui, mapkit]
---

# Sprint 2 — Composer et gérer sa propre sortie

## Status

Ce sprint est `completed`. Il a été approuvé par le propriétaire le 2026-08-11,
puis complété le même jour après le build, l'analyse statique, la revue et la
validation interactive confirmée par le propriétaire. Sa complétion n'autorise
pas les Sprints 3 à 5.

## Outcome

Depuis la carte principale, une personne peut ouvrir une feuille native,
rechercher un établissement ou une adresse, choisir un point sur une carte,
sélectionner une heure dans les prochaines 24 heures, puis publier, modifier ou
annuler sa propre sortie.

La sortie est enregistrée avec les fondations du Sprint 1. Aucune sortie d'ami
n'est encore affichée sur la carte et aucune notification n'est envoyée.

## Scope

- Bouton natif « Dire où je vais » sur l'écran d'exploration.
- Feuille SwiftUI de composition.
- Recherche `MKLocalSearch` limitée à la région visible.
- Sélection directe d'une coordonnée sur une prévisualisation MapKit.
- Résolution inverse facultative de l'adresse.
- `DatePicker` borné aux prochaines 24 heures.
- États de chargement, erreurs, modification et annulation.

## Non-goals

- Aucun marqueur de sortie sur `MapWithFogView`.
- Aucune lecture des sorties des amis.
- Aucune notification locale ou distante.
- Aucun itinéraire ou bouton « J'y vais aussi ».
- Aucune modification du schéma Firestore approuvé au Sprint 1.

## User flow

1. L'utilisateur ouvre « Dire où je vais ».
2. Il recherche un lieu ou touche la carte.
3. Il vérifie le nom, l'adresse facultative et l'heure.
4. Il publie la sortie et la feuille se ferme après confirmation serveur.
5. En rouvrant la feuille, il peut remplacer ou annuler cette sortie.

## Affected files

- `wander/OutingPlanComposerView.swift` — nouvelle feuille native.
- `wander/ContentView.swift` — point d'entrée et présentation de la feuille.
- `wander/OutingPlanService.swift` — uniquement si une adaptation du CRUD
  approuvé est indispensable au formulaire.

## Implementation checklist

- [x] Ajouter le bouton avec SF Symbol et libellé VoiceOver.
- [x] Construire la feuille avec les composants SwiftUI standards.
- [x] Ajouter la recherche MapKit sur validation de la requête.
- [x] Afficher au plus un nombre borné de résultats.
- [x] Ajouter la sélection tactile et la résolution inverse annulable.
- [x] Préremplir le formulaire lors d'une modification.
- [x] Borner le `DatePicker` aux dates permises par le contrat.
- [x] Désactiver la validation pendant une écriture en cours.
- [x] Conserver le partage fonctionnel si l'adresse est indisponible.

## Risks

- Les résultats MapKit peuvent être absents ou approximatifs selon la région.
- Une requête ou un géocodage obsolète ne doit pas remplacer une sélection plus
  récente ; chaque opération doit être annulable et identifiée.
- La feuille ne doit pas déclencher de publication tant qu'un lieu valide n'est
  pas sélectionné.
- L'interface doit rester conforme au langage visuel iOS natif du dépôt.

## Validation

- [x] Build Debug iOS réussi sans nouvel avertissement.
- [x] Recherche par établissement et adresse vérifiée sur simulateur.
- [x] Sélection directe sur la carte vérifiée.
- [x] Publication, modification et annulation vérifiées avec Firestore.
- [x] Une erreur réseau laisse la feuille ouverte avec un message utile.
- [x] Une adresse absente n'empêche pas la publication.
- [x] Dynamic Type, mode sombre et VoiceOver vérifiés.
- [x] Aucun marqueur d'ami ni code de notification ajouté prématurément.

## Validation record

- Build réussi le 2026-08-11 avec :
  `xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' build`.
- Analyse statique Xcode réussie le 2026-08-11 avec :
  `xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' analyze`.
- Installation et lancement réussis sur l'iPhone 17 Pro simulé sous iOS 26.3.
- Le propriétaire a confirmé le 2026-08-11 la validation interactive des
  parcours authentifiés, des états d'erreur et de l'accessibilité.
- La relance des tests de règles est bloquée localement par le JDK 17 installé ;
  Firebase CLI 15 exige le JDK 21 déjà documenté par le Sprint 1. Le contrat
  `plans/{userID}` reste couvert par les 18 tests réussis au Sprint 1.

## Review record

Revue exécutée le 2026-08-11. Aucun constat P1, P2 ou P3 confirmé ; aucun
fichier supplémentaire n'a été créé dans `todos/`.

1. La décision la plus délicate reste la concurrence MapKit : chaque recherche
   et chaque géocodage inverse est annulable et protégé par un identifiant afin
   qu'une réponse obsolète ne remplace jamais la dernière sélection.
2. `CLGeocoder`, une interface personnalisée et l'ajout prématuré de marqueurs
   sur la carte principale ont été écartés respectivement pour dépréciation,
   non-conformité au langage iOS natif et dépassement du périmètre du Sprint 2.
3. Le comportement réel derrière l'authentification était le point le moins
   certain après la revue statique ; la validation interactive du propriétaire
   a fermé cette incertitude.

## Completion record

Sprint complété le 2026-08-11 à 16:10:48 +09:00. Le build Debug et l'analyse
statique Xcode ont réussi sans nouvel avertissement, la revue n'a produit aucun
constat priorisé et le propriétaire a confirmé l'ensemble des validations
interactives. Le Sprint 3 peut maintenant être présenté pour une approbation
séparée, mais son implémentation n'a pas commencé.

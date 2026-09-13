---
title: Actions événement directement sur la carte
status: completed
completed_at: 2026-09-11
date: 2026-09-11
approved_at: 2026-09-11
owner: Samuel
---

# Résultat approuvé

Plan proposé dans la conversation puis approuvé par Samuel, qui confirme aussi
la suppression de la fiche narrative « Vous organisez un café le… avec… ».
Toucher un événement conserve la liste et son défilement, centre la carte et
affiche deux boutons natifs Liquid Glass, accepter/refuser, au-dessus de la carte.
Les marqueurs utilisent la même présentation. Les fiches d’amis restent disponibles.

## Périmètre et fichiers

- `wander/ContentView.swift` : liste permanente pour une sélection événement,
  actions superposées branchées sur la réponse existante.
- `wander/MapEventsPanelView.swift` : sélection et accès natif à l’itinéraire
  depuis le menu de ligne ; édition conservée par balayage pour l’organisateur.
- `wander/MapEventActionsView.swift` : deux boutons pour un invité, avec état
  sélectionné et verrouillage pendant vérification/envoi.
- `wander/OutingPlanDetailCardView.swift` : supprimer la fiche narrative inutilisée.
- `wander/DebugSocialMapScenario.swift` et
  `wanderUITests/MapSocialGestureUITests.swift` : même parcours local et tests adaptés.
- `wanderTests/MapEventListPresentationTests.swift` : réutiliser les contrôles de réponse.
- Ce plan et les constats éventuels dans `todos/` ; solution seulement si réutilisable.
- Vault Obsidian Wander : `Backlog features.md` section agenda,
  `Documentation UX.md` sections agenda/fiches événement,
  `Documentation technique.md` sections sélection/présentation événement.
  Mettre à jour `updated` et conserver les wikilinks.

## Étapes

- [x] Approbation explicite du plan dans la conversation.
- [x] Remplacer la fiche par les actions sur carte et conserver les fonctions utiles.
- [x] Adapter le scénario et les tests aux sélections successives sans fiche.
- [x] Simplifier, compiler, valider les parcours portrait sur l’iPhone 17 et relire ; limite paysage dans 051.
- [x] Actualiser la documentation et enregistrer les résultats exacts.

## Risques et validation

La sélection native MapKit ne doit jamais rouvrir une fiche événement.
Vérifier le bon identifiant lors des réponses successives, les états inconnus/envoi,
le maintien du défilement et du divider, le centrage et les gestes de carte.
Vérifier invité, organisateur, annulation, changement depuis un groupe et profil ami.
Les réponses distantes utilisent les services existants ; pas de schéma Firebase.
Les contrôles de réponse unitaires existants sont conservés. Tests UI ciblés puis
vérification visuelle standard sur l’iPhone 17 existant, sans autre runtime.
Pas de tests d’accessibilité dédiés. Aucun Git mutant. Le plan agenda déjà modifié
avant ce travail reste intact. Le workflow CE est exécuté localement ; les règles
du projet priment sur ses opérations Git et son suivi par commits.

## Résultats

La fiche narrative est supprimée et tous ses appels retirés. Le même identifiant
continue de piloter MapKit et les observations ; seul un profil d’ami remplace
la liste. Les deux réponses invité sont en haut à gauche de la carte, et le filtre
reste disponible à droite. L’édition reste dans le balayage natif ; le menu
contextuel donne accès à l’itinéraire. Aucun changement du divider ni de Firebase.

Simplification via trois revues indépendantes : aucune correction de réutilisation
ou performances ; identifiants explicites dans les helpers de tests, commentaire
redondant retiré. Déplacer `canRespond(to:)` hors du helper existant n’a pas été
retenu : il reste la source de vérité commune testée, sans changement de modèle.

Les trois notes Obsidian ont été modifiées avec accès ciblé autorisé ; leurs
propriétés `updated` sont au 11 septembre et les wikilinks sont conservés.

Validation initiale : compilation Debug réussie ; 11 tests unitaires réussis.
Cinq des sept parcours UI passent. Deux échecs à reprendre : rotation non observée
par le prédicat de fenêtre et assertion d’état sur la mauvaise ligne du scénario
`open-event` (sélection initiale de la ligne 2, assertion initialement sur la ligne 1).
Cette assertion a été corrigée. Aucun défaut de réponse observé dans le parcours
qui change explicitement de cible. Résultat : `/tmp/wander-map-event-actions.xcresult`.
Avertissements préexistants : extraction AppIntents et versions d’extensions
15/27 différentes de celle de l’application 41. Aucun nouvel avertissement Swift.

## Validation finale

Deuxième compilation Debug réussie, sur le même iPhone 17
`6F13855D-10B8-45AF-9205-17C8393379E3`, avec le cache existant
`/tmp/wander-social-cluster-derived-data` et sans tests parallèles.
Le résultat `/tmp/wander-map-event-actions-final.xcresult` contient cinq parcours
réussis et un échec paysage. La commande termine donc avec `TEST FAILED`, code 65.

- Annuler la première ligne d’un groupe, puis l’événement restant : réussi.
- Répondre successivement à deux événements, puis modifier/annuler un événement
  propre par balayage : réussi.
- Déplacer réellement la carte puis retoucher la même ligne : recentrage vérifié
  par la position de l’annotation, sans déplacement du cadre de liste.
- Réponses sur les trois hauteurs du divider, état sélectionné et itinéraire par
  menu contextuel : réussi après correction de la cible du test.
- Défilement de la liste avec boutons fixes au-dessus de la carte : réussi.
- Passage paysage : interface toujours en portrait malgré la demande de rotation,
  échec reproduit, cause non établie et consignée dans `todos/051-ready-p2-valider-rotation-actions-evenement.md`.

Les autres parcours réussis dans le premier résultat sont : annulation du groupe
dans l’ordre inverse, conservation de la position de liste après sélection,
profil d’ami depuis un groupe mixte et désactivation des réponses en chargement,
indisponibilité/envoi avec itinéraire accessible. Bilan cumulé : 11 tests unitaires
et 9 parcours UI distincts réussis ; un parcours paysage en échec. Aucun test
d’accessibilité dédié exécuté. Les échanges Firebase authentifiés ne sont pas
prouvés par le scénario local, limite déjà suivie dans 047.

Captures exportées et inspectées dans `/tmp/wander-map-event-actions-final-screens/` :
`4D3B0B6A-3B4E-4934-8A44-7028CE27FE66.png` montre la liste et les deux boutons,
avec checkmark actif bleu ; `83ED6528-D830-4525-852E-128F33ED4B1A.png` montre
le recentrage. Les glyphes emoji manquants du simulateur restent le constat 048.

`git diff --check` passe. Aucun changement de `MapDetailSplitView.swift`, des
services, des règles ou du schéma Firebase. Aucun Git mutant exécuté.
Revue `ce-code-review`, reçu `status: complete`, artifacts
`/tmp/ce-code-review-event-actions-20260911` : aucun défaut de code conservé.
Le suivi documentaire demandé par la revue est résolu dans 050 ; la limite de
rotation est explicite dans 051. La revue adversariale locale a remplacé la
revue externe dont l’accès avait été rejeté automatiquement. Aucun envoi externe
du code n’a été effectué. Les patterns existants de liste montée et de sélection
MapKit sont réutilisés ; pas de nouvelle solution réutilisable à ajouter.

Référence de plateforme : [styles Liquid Glass natifs](https://developer.apple.com/documentation/SwiftUI/PrimitiveButtonStyle/glass%28_%3A%29).


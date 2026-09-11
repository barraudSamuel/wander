---
title: "Événements présentés comme des phrases"
status: completed
date: 2026-09-10
approved_at: 2026-09-10
completed_at: 2026-09-10
owner: Samuel
---

# Événements présentés comme des phrases

Samuel a explicitement approuvé le plan présenté dans la conversation.

## Résultat et périmètre

Supprimer le titre, le filtre et tous les en-têtes de jour. Afficher immédiatement
les événements par ordre chronologique, chacun sous forme d’une phrase avec avatar
intégré, organisateur, activité et emoji, lieu et date complète. Accentuer activité,
lieu et horaire en bleu iOS. Intégrer réponse et distance disponible au texte.
Conserver la taille des caractères pendant le redimensionnement, la sélection,
les actions existantes et le défilement après retour de la fiche.

Un seul incrément, dépendant de la liste existante. Pas de changement des accès ou
écritures Firebase. La limite connue de police emoji du simulateur reste consignée
sans modifier son runtime. Le style de texte des fiches actuelles doit être préservé.

## Fichiers concernés

- `wander/MapEventsPanelView.swift` : liste plate et phrases.
- `wander/MapDetailFittingText.swift` : mode de taille stable et accent bleu natif.
- `wander/OutingPlan.swift`, `wander/OutingPlanDetailCardView.swift` : libellés d’activité partagés.
- `wander/DebugSocialMapScenario.swift` si nécessaire pour les scénarios.
- `wanderTests/MapEventListPresentationTests.swift` et `wanderUITests/MapSocialGestureUITests.swift`.
- `wanderUITests/MotionDockUITests.swift` : adapter la recherche du panneau natif désormais exposé comme une collection.
- Le présent plan et les constats de revue concernés dans `todos/`.
- Vault `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Backlog features.md`, `Documentation UX.md`, `Documentation technique.md`, `00 - Wander.md`.
  Mettre à jour le fonctionnement, la suppression des filtres et les résultats de
  validation, actualiser `updated` et préserver les wikilinks. Accès technique hors
  sandbox si nécessaire ; signaler toute note non actualisée sans créer de copie.

## Étapes et critères d’acceptation

- [x] Enregistrer l’approbation.
- [x] Retirer en-tête, filtres, sections et logique devenue inutile.
- [x] Construire les phrases avec avatar et accents natifs, partager le texte des activités.
- [x] Garantir la taille stable des lignes et préserver le comportement des fiches.
- [x] Adapter les tests existants et vérifier les phrases longues, les états, le retour et les actions.
- [x] Compiler, examiner les captures et tester en portrait/paysage sur l’iPhone 17 existant, taille standard.
- [x] Relire, consigner les résultats et actualiser les quatre notes Obsidian.

## Risques et validation

Le composant de texte commun sait agrandir les caractères dans une fiche : la liste
doit demander explicitement une taille stable. Les phrases longues doivent retourner
leur hauteur complète pour éviter une troncature. Chaque phrase conserve un seul
bouton ouvrant la fiche ; les accents colorés ne créent pas de commandes séparées.
La date figure dans chaque phrase pour éviter toute ambiguïté après suppression des
sections. Les états de participation inconnus restent distincts d’un refus.

Tests de logique du tri, des phrases et de la distance. Tests UI fonctionnels
ciblés de suppression des en-têtes, sélection, retour, redimensionnement, états,
actions et paysage. Contrôle du rendu de la fiche partagée. Pas de tests dédiés
d’accessibilité. Aucun Git mutant.

## Résultats et revue

### Revue

- Les filtres, sections et états associés ont été supprimés, ainsi que leurs
  tests devenus obsolètes. La liste conserve un tri stable par date puis identifiant.
- La phrase contient toujours la date et l’heure, avec une présentation française.
  La réponse personnelle est intégrée au texte, sauf pour les sorties organisées
  où « Vous organisez » suffit. Le calcul et l’expiration de la distance restent identiques.
- Le choix principal est de réutiliser le texte natif de la fiche. Un paramètre
  `expandsToFit`, vrai par défaut, permet à la liste de demander une hauteur sans
  agrandissement. Cela évite un second moteur de mesure et conserve le comportement
  des fiches existantes. Les accents bleus utilisent des attributs UIKit et des
  couleurs système ; ils ne sont pas des commandes distinctes.
- Aucun listener, accès, modèle persistant ou traitement d’action n’est modifié.
  La liste reste montée derrière la fiche, avec ses gestes et sa position.
- Les quatre notes Obsidian décrivent la version en phrases et la suppression des
  filtres. Le constat 047 porte désormais sur les mises à jour distantes des phrases.
- Le défaut de police emoji du simulateur, déjà diagnostiqué dans le constat 048,
  reste une limite de rendu. Aucune modification du runtime n’a été effectuée.

### Validation

Build Debug réussi. Quatre tests unitaires réussissent dans
`/tmp/wander-event-phrases-first.xcresult` : tri conservant tous les états,
composition de la phrase et accents, distinction des réponses inconnues/refusées,
fraîcheur et précision de la distance.

Les deux premiers tests UI échouaient à retrouver l’ancien conteneur `Other` du
panneau. La capture et l’arbre natif montrent que, sans en-tête, SwiftUI expose
directement la `CollectionView` sous l’identifiant `map-detail-pane`. Les tests
recherchent maintenant le panneau indépendamment de son type, et la collection
sous son identifiant de liste ou de panneau. Aucun élément visuel vide n’a été
ajouté pour conserver artificiellement l’ancienne structure.

La reprise `/tmp/wander-event-phrases-ui.xcresult` valide six parcours UI :
participation/annulation/itinéraire, états chargement/erreur/vide, paysage,
ordre par défaut, phrases longues avec position absente/ancienne, suppression
des en-têtes et réponse intégrée après consultation.

Deux assertions de géométrie échouaient sur des erreurs d’arrondi : hauteur du
panneau `644.3333333333331` contre `644.3333333333333`, bouton de
`43.99999999999997` au lieu de `44`. Les comparaisons tolèrent désormais ces écarts
numériques, avec 0,5 point pour le rectangle du panneau et 0,01 point pour le seuil
des boutons. Le code de l’app n’a pas changé pendant cette reprise.

Les deux parcours repris dans `/tmp/wander-event-phrases-geometry.xcresult`
réussissent : redimensionnement/défilement/retour et actions de la fiche à toutes
les hauteurs. Ce bundle termine avec `TEST SUCCEEDED`. Le contrôle du
redimensionnement vérifie également une hauteur de ligne identique avant/après
agrandissement et le retour au même défilement.

Résultat final : quatre tests unitaires et huit parcours UI distincts réussis.
Captures examinées dans `/tmp/wander-event-phrases-ui-screens/` et
`/tmp/wander-event-phrases-geometry-screens/` : phrases sans en-tête, avatars
intégrés et accents bleus, lieu long complet, paysage, retour et fiche préservée.
La limite de police emoji connue reste visible et consignée dans le constat 048.
Les notes Obsidian incluent les résultats exacts et leur propriété `updated`.

`git diff --check` passe. Les avertissements AppIntents et de version d’extension
déjà présents restent inchangés ; aucun nouvel avertissement Swift. Aucun Git
mutant ni modification du runtime. La validation authentifiée reste suivie dans
`../../todos/047-ready-p2-valider-liste-evenements-compte-reel.md`.

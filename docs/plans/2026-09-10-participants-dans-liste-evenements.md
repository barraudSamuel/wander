---
title: "Participants dans les phrases d’événements"
status: completed
date: 2026-09-10
approved_at: 2026-09-10
completed_at: 2026-09-10
owner: Samuel
---

# Participants dans les phrases d’événements

Samuel a validé le plan dans la conversation, puis demandé 📍 devant le nom du lieu.
Les prénoms d’exemple ne sont pas des données produit : les participants viennent
uniquement des événements accessibles du compte.

## Résultat et périmètre

Phrase principale : organisateur, activité représentée par son emoji, date abrégée
et horaire, puis participants. Une personne : avatar et nom. Plusieurs : trois
avatars maximum et +N au-delà. Ne pas répéter l’organisateur ni présenter les
personnes ayant refusé comme participantes. Le lieu est précédé de 📍 ; la réponse
personnelle et la distance disponible restent dans le texte.

Charger les groupes des lignes réalisées par la liste native au fil du défilement,
en complément des observations existantes des événements organisés, sélectionnés
ou auxquels le compte participe. Conserver les groupes des lignes montées derrière
une fiche pour éviter un rechargement au retour. Suspendre les demandes de liste
quand Explorer n’est plus actif. Retirer les événements disparus et respecter les
amitiés autorisées ainsi que la publication actuelle.

Un incrément. Aucun changement du schéma ni des règles Firebase. Les lectures
supplémentaires sont limitées aux lignes réalisées par la liste, qui peut précharger
quelques cellules. Le défaut connu de police emoji du simulateur reste hors périmètre.

## Fichiers concernés

- `wander/MapEventsPanelView.swift` : phrase, participants, présence des lignes.
- `wander/ContentView.swift` : demandes de groupes de la liste et activité Explorer.
- `wander/OutingAttendanceService.swift` : observation complémentaire bornée.
- `wander/DebugSocialMapScenario.swift` : zéro/une/plusieurs personnes et états.
- `wanderTests/MapEventListPresentationTests.swift`, `wanderUITests/MapSocialGestureUITests.swift`.
- Le présent plan et le suivi existant `todos/047-ready-p2-valider-liste-evenements-compte-reel.md`.
- Vault `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Backlog features.md`, `Documentation UX.md`, `Documentation technique.md`, `00 - Wander.md`.
  Actualiser `updated`, conserver les wikilinks, demander l’accès technique hors
  sandbox si nécessaire et signaler précisément toute mise à jour empêchée.

## Étapes et critères d’acceptation

- [x] Enregistrer l’approbation et l’ajout de 📍 au lieu.
- [x] Ajouter les participants, les dates abrégées et le repère du lieu dans la phrase.
- [x] Charger les groupes des lignes réalisées, retirer les demandes devenues inutiles.
- [x] Couvrir zéro/une/plusieurs personnes, doublons, chargement et indisponibilité.
- [x] Compiler, valider les parcours sur l’iPhone 17 existant en taille standard et examiner les captures.
- [x] Relire les conditions d’accès et de nettoyage, documenter résultats et limites, actualiser Obsidian.

## Risques et validation

Les états inconnus ne doivent jamais devenir « aucun participant ». La sortie d’une
ligne du cache natif, la disparition d’un événement et le retrait d’une amitié doivent
retirer ses observations supplémentaires. Les jetons existants écartent les anciens
callbacks. La sélection et les participations existantes gardent leur propre observation.
Les avatars ne doivent pas faire grossir la police pendant le redimensionnement.

Tests unitaires du texte et des participants ; tests UI avec données locales des
états, réponses, défilement et retour. Build Debug et revue des captures. Les écritures
et observations authentifiées restent suivies dans le constat 047. Aucun test dédié
d’accessibilité, aucun Git mutant, aucune installation de simulateur ou de police.

## Résultats et revue

Build Debug réussi sur l’iPhone 17 existant. La passe
`/tmp/wander-event-participants.xcresult` valide sept tests unitaires et les cinq
parcours UI sélectionnés. Une assertion unitaire oubliait le sélecteur Unicode
de présentation emoji du café ; corrigée, elle passe dans
`/tmp/wander-event-participants-unit-retry.xcresult` (`TEST SUCCEEDED`).
Soit huit tests unitaires et cinq parcours UI distincts réussis : groupes et états,
demandes de groupes au défilement et suspension hors Explorer, phrases et réponse
au retour, conservation de hauteur/défilement, participation/refus/annulation.

La sonde du scénario Debug vérifie que les demandes ne couvrent pas les 18 sorties
dès l’ouverture, évoluent après défilement, restent bornées, sont vidées en quittant
Explorer et reprennent au retour. Elle ne prouve pas les échanges Firestore.

Revue : `observe` intersecte les demandes avec les événements actuels ; la
réconciliation retire les listeners lors d’un retrait d’événement ou d’amitié,
recrée ceux d’une nouvelle publication et écarte les anciens callbacks par jeton.
Les chemins sélection/participation/organisation conservent leurs propres motifs
d’observation. Les règles de lecture attendees/declines autorisent déjà ces amis.
Aucune modification des règles, du schéma ni du runtime.

Le constat 047 suit les validations authentifiées restantes. Les quatre notes
Obsidian du périmètre ont été mises à jour avec leur propriété `updated` et leurs
wikilinks conservés. Aucun autre apprentissage réutilisable nécessitant une nouvelle
fiche solution n’a été identifié ; les patterns de texte et liste conservée sont
déjà documentés par les incréments précédents.

Revue visuelle terminée : captures initiales dans
`/tmp/wander-event-participants-screens/`. Les groupes zéro/un/trois/cinq sont visibles,
les réponses après retour et le défilement sont conservés. Des captures immédiates
pendant le rebond et la transition de retour montrent une composition incomplète.
Les reprises ciblées `/tmp/wander-event-participants-captures.xcresult`, puis
`/tmp/wander-event-participants-settled.xcresult` passent (`TEST SUCCEEDED`).
Après stabilisation d’une seconde, les captures confirment le texte et les avatars
complets, y compris le groupe de cinq au retour. Aucun changement de production
n’a été nécessaire pour ces captures. Capture finale examinée :
`/tmp/wander-event-participants-settled-screens/AA5B971B-744B-49A7-9593-5F69E7CDFABB.png`.
Le défaut de police emoji connu reste suivi dans le constat 048.

`git diff --check` passe. Aucun nouveau warning Swift ; les avertissements de
métadonnées AppIntents et de version de l’extension sont préexistants. Aucun test
dédié d’accessibilité n’a été lancé. L’application normale est relancée après tests.

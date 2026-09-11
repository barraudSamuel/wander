---
title: "Liste sociale des événements et emojis"
status: completed
date: 2026-09-10
approved_at: 2026-09-10
completed_at: 2026-09-10
owner: Samuel
tags: [plan, ios, events, design]
---

# Liste sociale des événements

Plan présenté dans la conversation et explicitement approuvé par Samuel (« j'approuve »).

## Résultat et périmètre

Enrichir la liste permanente avec l’avatar de l’organisateur, une activité accompagnée
d’un emoji et du nom de l’organisateur, un horaire visible, le lieu, la réponse du
compte et une distance approximative lorsque sa position est récente. Regrouper les
événements par jour et proposer les filtres natifs Toutes / J’y vais / Les miennes.
La taille des lignes reste indépendante du déplacement de la séparation.
Le retour de la fiche conserve le filtre, le défilement et la hauteur du panneau.

Un seul incrément, dépendant de la liste permanente déjà implémentée. Pas d’avatars
de participants supplémentaires, de nouvelles observations Firebase, de permission
de localisation supplémentaire, de durée de marche ni de changement du schéma.
Les composants et couleurs restent ceux d’iOS.

## Fichiers concernés

- `wander/MapEventsPanelView.swift` : présentation, filtres, sections et distance.
- `wander/ContentView.swift` : transmission de la position déjà disponible.
- `wander/OutingPlan.swift`, `wander/OutingPlanDetailCardView.swift` : emoji partagé.
- `wander/DebugSocialMapScenario.swift` : données locales variées et localisation absente/ancienne.
- `wanderUITests/MapSocialGestureUITests.swift` : parcours et rendu.
- `wanderTests/MapEventListPresentationTests.swift` : filtres, changement de jour et fraîcheur.
- Le présent plan et les constats de revue dans `todos/` si nécessaire.
- `docs/solutions/2026-09-10-identifiant-ligne-bouton-swiftui.md` : leçon vérifiée pendant la validation.
- Vault `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Backlog features.md` (fonctionnalités réalisées), `Documentation UX.md` (liste et carte),
  `Documentation technique.md` (présentation et validation), `00 - Wander.md` (état).
  Actualiser `updated`, conserver les wikilinks et demander l’accès technique au vault
  hors sandbox si nécessaire. Signaler précisément tout blocage, sans créer de copie.

## Étapes et critères d’acceptation

- [x] Enregistrer l’approbation du plan.
- [x] Implémenter les informations sociales, emojis et filtres natifs.
- [x] Ajouter les sections par jour et la distance approximative conditionnelle.
- [x] Conserver sélection, défilement, hauteur et parcours des fiches.
- [x] Adapter les scénarios et vérifier les états vides propres aux filtres.
- [x] Compiler, tester sur l’iPhone 17 existant et examiner les captures.
- [x] Relire/simplifier, consigner les résultats et actualiser les quatre notes.

## Risques et validation

Les lieux longs doivent rester lisibles. Le changement de jour
et l’expiration d’une position doivent être pris en compte même si la liste reste
ouverte. Les filtres ne doivent pas assimiler une réponse inconnue à une participation.
Les événements organisés par le compte font aussi partie de « J’y vais ».
La distance est à vol d’oiseau, arrondie et masquée si la position a plus de cinq
minutes, présente une précision supérieure à 100 m ou est invalide.

Tests unitaires déterministes des filtres, du calendrier et de la position ; tests UI
ciblés des filtres, du retour, des actions et des états en portrait et paysage,
avec la taille de texte standard. Build Debug sur le simulateur iPhone 17 déjà existant. Les scénarios locaux
ne valident pas les écritures Firebase réelles.

## Validation et revue

### Résultat

Implémentation terminée, build Debug réussi et douze tests distincts réussis :
quatre tests unitaires et huit parcours UI fonctionnels. Captures portrait et
paysage examinées. Une limite du runtime empêche la validation visuelle des
emojis colorés, consignée ci-dessous. Les quatre notes Obsidian ont été actualisées
avec `updated` et leurs wikilinks conservés.

### Tests et captures

- `MapEventListPresentationTests` : quatre tests couvrant filtres et réponses
  inconnues, tri stable, changement de jour, heure d’été et fraîcheur/précision
  de la position. Réussis dans `/tmp/wander-social-list-tests.xcresult` et
  `/tmp/wander-social-list-final.xcresult`.
- Première passe UI : les sept parcours ne retrouvaient pas les boutons par
  identifiant. Déplacer le groupement descriptif vers le label du bouton corrige
  ce défaut ; le parcours filtres/retour passe dans
  `/tmp/wander-social-list-accessibility-fix.xcresult`.
- `/tmp/wander-social-list-final.xcresult` : six parcours réussis avant interruption
  volontaire de la passe pour respecter la nouvelle consigne du dépôt sur les
  tests en taille standard. Parcours réussis : réponses inconnues dans J’y vais,
  participation/annulation, états chargement/erreur/vide, position absente/ancienne
  et filtre vide, ordre par défaut, redimensionnement/défilement/retour.
  Ce bundle est interrompu et n’est pas présenté comme une passe globale réussie.
- `/tmp/wander-social-list-render.xcresult` : trois parcours réussis après
  simplification du titre en textes séparés : paysage en taille standard,
  redimensionnement/défilement/retour, filtres avec consultation puis refus d’une
  sortie (elle quitte J’y vais au retour, le filtre reste actif). Ce bundle termine
  avec `TEST SUCCEEDED`. Le redimensionnement est commun aux deux dernières passes.
- Captures : `/tmp/wander-social-list-render-screens/`. La capture filtrée finale
  conserve avatars, horaires et distances après retour ; les sections Aujourd’hui /
  Demain et le défilement indépendant sont visibles en paysage.
- `git diff --check` passe. Les avertissements AppIntents et de versions d’extension
  déjà présents restent hors de cet incrément ; aucun nouvel avertissement Swift.

### Revue et limites

Le choix principal est un menu Picker natif dans l’en-tête pour réserver la hauteur
aux lignes. Les réponses personnelles existantes alimentent les filtres sans
observations supplémentaires. Les sorties organisées sont incluses dans J’y vais,
y compris lorsque leur état de participation personnelle vaut `notRequested`.
Le filtre signale les réponses en cours de chargement ou indisponibles au lieu
d’annoncer une liste vide. Le calendrier local et un rafraîchissement chaque minute
actualisent les sections et la distance ; aucune permission n’est déclenchée.

La revue a simplifié le titre en deux textes natifs (emoji et activité), et mutualisé
l’emoji avec la fiche. La liste conserve son identité sous la fiche, donc son filtre
et son défilement. Aucune modification du schéma, des règles ou des écritures Firebase.
Les modifications simultanées d’`AGENTS.md` et du périmètre des tests ont été conservées.

Le rendu emoji reste limité par le simulateur : un diagnostic Core Text exécuté
hors du dépôt signale explicitement la police `AppleColorEmoji.ttc` indisponible
dans le runtime iOS 26.3 et son remplacement par `LastResort`. La fiche UIKit
existante présente le même défaut. Redémarrer le même appareil ne le résout pas.
Constat : `../../todos/048-ready-p2-police-emoji-simulateur.md` ; aucune nouvelle
installation ni modification du runtime effectuée.

La synchronisation authentifiée reste à vérifier dans
`../../todos/047-ready-p2-valider-liste-evenements-compte-reel.md`.
Leçon réutilisable : `../solutions/2026-09-10-identifiant-ligne-bouton-swiftui.md`.

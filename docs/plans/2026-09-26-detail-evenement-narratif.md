---
title: Fiche événement narrative sans titres épinglés
status: completed
date: 2026-09-26
approved_at: 2026-09-26
started_at: 2026-09-26
completed_at: 2026-09-26
owner: Samuel
related:
  - 2026-09-23-detail-evenement-panneau.md
tags: [plan, events, ios, design]
---

> Approche remplacée le 26 septembre à la demande de Samuel par le
> [plan de cartes autonomes](2026-09-26-cartes-evenements-autonomes.md),
> approuvé séparément. Le détail, le zoom et les actions par balayage sont
> retirés. Les validations ci-dessous décrivent la version historique.


# Fiche événement narrative sans titres épinglés

## Outcome and approval

Plan présenté avec le statut `proposed` dans la conversation, puis approuvé par
Samuel avec « implemente » le 26 septembre 2026 après exploration des références.
La fiche présente l'organisateur, l'activité, le lieu et l'heure dans une
composition typographique continue, avec les participants proches du résumé.
Tous les titres et toutes les actions défilent avec le contenu. Le retour natif
« Événements » reste accessible et la barre conserve son titre vide.

## Scope and approach

Remplacer uniquement la liste du détail par un `ScrollView` et un `VStack`
ordinaire. Utiliser police système, couleurs sémantiques, avatars existants et
boutons natifs. Mettre l'accent sur l'activité et le lieu, rendre les mots de
liaison plus discrets, puis afficher date, participants, adresse et actions.
Conserver les noms des participants, les états de réponse et de roster, les
gardes de participation et les callbacks existants.

La référence fournie guide le rythme du texte. Partiful inspire la place des
invités, Luma la hiérarchie, Apple Invitations les actions natives. Ces sources
statiques ne prouvent pas leur comportement au défilement.

- https://partiful.com/
- https://apps.apple.com/us/app/luma-events-invites/id1546150895
- https://www.apple.com/newsroom/2025/02/introducing-apple-invites-a-new-app-that-brings-people-together/
- https://dribbble.com/shots/23998184-Event-details-page-for-an-event-app

## Non-goals and dependencies

Pas de changement du modèle, de Firebase, de la carte, de la navigation du
panneau ou des listes Amis/Événements. Aucun ajout de photo de couverture,
police, bibliothèque, effet décoratif ou titre/action fixe.
Réutiliser `MapEventListPresentation` et `ProfileAvatarView`.
Le travail reste dans le checkout courant. Aucune commande Git mutante,
aucun commit, aucune publication. Les consignes du dépôt prévalent sur les
automatismes de branche et de commit des skills.

## Affected files

- `wander/MapEventDetailView.swift` : composition et défilement.
- `wanderUITests/MapSocialGestureUITests.swift` : assertions et recherche des
  actions adaptées au contenu défilant, sans exécuter les tests.
- Ce plan : approbation, checklist, revue et validation exacte.
- `todos/` : constats prioritaires uniquement si la revue en retient.
- Obsidian Wander, coffre existant
  `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  - `Backlog features.md`, entrée « Détail événement depuis la carte et la liste ».
  - `Documentation UX.md`, « Architecture de navigation » et « Sorties prévues ».
  - Mettre à jour `updated`, conserver les wikilinks, ne pas ouvrir Obsidian.
  - Le coffre est hors des racines d'écriture par défaut ; utiliser l'accès
    technique autorisé, sinon consigner les sections restant à mettre à jour.

## Implementation

- [x] Enregistrer l'approbation avant les changements d'implémentation.
- [x] Composer la fiche narrative et préserver les états/actions.
- [x] Adapter les tests UI existants aux textes et au défilement.
- [x] Simplifier, compiler l'app et les cibles de tests, puis revoir le diff.
- [x] Actualiser les deux notes Obsidian et consigner les résultats.

## Risks and validation

Les lieux et noms longs doivent revenir à la ligne, sans hauteur fixe.
Un groupe nombreux doit conserver tous ses noms et laisser les actions
accessibles. Les états chargement, indisponibilité et envoi ne doivent pas
permettre une réponse mais doivent garder l'itinéraire utilisable.
Le retour, la sélection et la hauteur du panneau gardent leurs propriétaires.

Validation autorisée : `xcodebuild build-for-testing` pour la destination
générique iOS Simulator, sans lancement ni installation ; revue indépendante
du diff et contrôle de ses espaces. Les tests d'exécution simulateur restent
suspendus selon la demande de Samuel consignée le 23 septembre. Aucun nouveau
test dédié d'accessibilité. Aucun succès visuel ou UI en exécution ne sera
revendiqué. La compilation et la revue remplacent l'exécution pour ce travail.

## Acceptance criteria

- [x] Le détail ne contient plus de `List`, d'en-tête épinglé ni de titre de navigation.
- [x] Organisateur, activité, lieu, date, noms des participants et adresse
  disponible restent consultables.
- [x] Les actions natives et leurs gardes sont conservées.
- [x] L'app et les cibles de tests compilent sans nouveau diagnostic Swift.
- [x] Revue achevée et documentation actualisée ou limitation exacte enregistrée.

## Review notes

Le rendu et les interactions sur appareil ne sont pas vérifiés dans ce travail.
La validation partielle du plan du 23 septembre reste distincte.

### Validation et simplification

- `ce-work` appliqué dans le checkout existant, aucune commande Git mutante.
- `ce-simplify-code` : trois lectures indépendantes, réutilisation, qualité et
  efficacité. Aucun constat retenu et aucune simplification supplémentaire.
- Première compilation arrêtée sur une interpolation Swift répartie sur deux
  lignes dans une chaîne ordinaire. Corrigée avec une valeur `Text` locale.
- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build-for-testing`
  réussit le 26 septembre : `TEST BUILD SUCCEEDED`, code de sortie 0.
  Journal final : `/tmp/wander-event-narrative-build.log`.
- Aucun nouveau diagnostic Swift. Avertissements préexistants : extraction de
  métadonnées AppIntents et versions 15/27 des extensions face à l'app 46,
  déjà suivies dans `todos/054-ready-p2-aligner-build-extensions.md`.
- `ce-test-xcode` consulté : exécution des surfaces UI `SKIP` selon la consigne
  de Samuel, résultat de validation en exécution `PARTIAL`. Aucun test exécuté,
  aucune installation, ouverture, création ou démarrage de simulateur.
- Tests UI existants adaptés au titre narratif et à la position réelle des
  actions. Le scénario liste → détail → défilement → retour vérifie aussi le
  déplacement du titre si le contenu déborde et conserve les attentes de hauteur.
- `Backlog features.md` et `Documentation UX.md` mises à jour dans le coffre
  existant à `2026-09-26T12:27:21+09:00`. Propriétés `updated` vérifiées et
  séquences de wikilinks comparées avant/après, identiques. Obsidian non ouvert.

### Revue finale

- `ce-code-review mode:agent base:HEAD`, menée indépendamment après
  simplification, terminée avec `status: complete`, aucun constat actionnable.
  Reçu : `/tmp/compound-engineering-501/ce-code-review/20260926-122602-a6e0d4fb/review.json`.
  Les empreintes SHA-256 des deux fichiers Swift correspondent au contenu revu.
- `git diff --check` réussit. Le diff comprend uniquement la vue, ses tests UI
  et ce nouveau plan ; les deux notes approuvées sont actualisées dans Obsidian.
- Aucun nouveau `todos/`, aucun défaut propre à ce changement retenu.
  Pas de nouvelle solution `ce-compound` : composants et comportement natifs
  déjà connus, sans apprentissage réutilisable vérifié en exécution.
- Choix principal : hiérarchiser les informations avec le texte et les avatars
  existants, en gardant les boutons système. Une grande couverture aurait
  nécessité une donnée absente ; elle ne fait pas partie de cette refonte.
- Limite : rendu, transitions et parcours UI non exécutés. Les critères du
  présent plan sont satisfaits dans le périmètre approuvé de compilation/revue ;
  le plan précédent reste distinct et sa validation UI interrompue est inchangée.

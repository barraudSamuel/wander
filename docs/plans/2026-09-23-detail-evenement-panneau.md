---
title: Détail événement dans le panneau sous la carte
status: in_progress
date: 2026-09-23
owner: Samuel
tags: [plan, events, ios]
---

# Détail événement dans le panneau sous la carte

## Outcome and approval

Plan présenté dans la conversation et explicitement approuvé par Samuel le
23 septembre 2026. Depuis un pin ou une ligne, ouvrir le détail dans le panneau
Événements. Retour natif à la liste avec sa position et la hauteur conservées.

## Scope and approach

Navigation SwiftUI native dans le panneau existant. Une sélection partagée pilote
carte et fiche. Afficher catégorie, lieu, date, organisateur, participants et les
actions existantes de participation, modification et itinéraire. Une sélection
depuis la carte ouvre aussi le panneau. Si l'événement disparaît, revenir à la
liste. Aucun changement Firebase, de modèle de données ou de navigation de profil.

## Affected files

- `wander/ContentView.swift`: sélection commune et ouverture du panneau.
- `wander/MapEventsPanelView.swift`: navigation liste/détail et retour.
- `wander/MapEventDetailView.swift`: nouvelle fiche native.
- `wander/DebugSocialMapScenario.swift`: parité du scénario local.
- `wanderUITests/MapSocialGestureUITests.swift`: parcours et attentes actualisés.
- Ce plan; `todos/` pour les éventuels constats de revue.
- Obsidian Wander: `Backlog features.md` (événements), `Documentation UX.md`
  (navigation événements), `Documentation technique.md` (panneau et sélection).
  Mettre à jour `updated` et conserver les wikilinks. Le coffre est hors des
  racines autorisées; demander l'accès technique lors de la mise à jour et
  consigner toute impossibilité sans créer de copie du coffre.

## Implementation

- [x] Relier les deux entrées à la navigation et afficher la fiche.
- [x] Préserver retour, défilement, hauteur, actions et réconciliation.
- [x] Actualiser le scénario et les tests UI concernés.
- [ ] Simplifier, compiler, vérifier sur l'iPhone 17 déjà lancé et revoir.
- [ ] Actualiser les trois notes Obsidian et enregistrer les résultats.

## Risks and validation

Risque principal: recréer la liste et perdre sa position, ou garder une sélection
invisible lors d'un changement de panneau. Vérifier liste → fiche → retour,
pin → fiche → retour, changement d'événement, disparition, participation,
modification et itinéraire. Garder les profils fonctionnels. Compiler sans nouvel
avertissement et effectuer les tests fonctionnels à taille standard sur le seul
iPhone 17 déjà lancé. Aucun test dédié d'accessibilité. Pas de commande Git mutante.

## Review notes

Validation et constats à compléter pendant le travail.

### Validation intermédiaire

- Compilation Debug réussie sur iPhone 17 `6F13855D-10B8-45AF-9205-17C8393379E3`,
  journal `/tmp/wander-event-detail-build.log`. Avertissements déjà présents :
  métadonnées AppIntents et versions des extensions 15/27 face à l'app 46,
  suivies dans `todos/054-ready-p2-aligner-build-extensions.md`.
- 11 tests `MapEventListPresentationTests` réussis lors du premier passage.
- Premier passage UI : 7 échecs, aucun succès revendiqué. Les gestes longs
  sautaient les actions; déplacements bornés corrigés dans les tests. Le parcours
  annulation de deux événements depuis groupe puis pin passe lors du diagnostic.
- Diagnostic direct : le conteneur collection retourne `isHittable=false`, sa
  première ligne retourne `true`, puis le vrai toucher ouvre le détail et le retour
  natif fonctionne. Les assertions UI doivent porter sur les éléments interactifs
  et sur le viewport utile entre barre de navigation et dock. Preuves :
  `/tmp/wander-event-hit-diagnostic.log`, `/tmp/wander-event-detail-diagnostic.xcresult`.
- Les trois notes Obsidian ont été mises à jour, validation finale encore en cours.
- Simplification : 3 lectures indépendantes, callback de retour rendu obligatoire
  et tri déplacé hors du rafraîchissement minute. Aucun changement de modèle.
- Revue `ce-code-review` en cours sur le diff local et la nouvelle vue, avec
  `AGENTS.md` comme critères. Git reste en lecture seule conformément aux accords.

### Arrêt de la validation demandé par Samuel

Le 23 septembre, Samuel demande explicitement l'arrêt des tests sur simulateur.
Le `xcodebuild test` en cours et son runner sont interrompus immédiatement.
Ne plus lancer de tests sur simulateur sans nouvelle demande explicite de Samuel.

La fonctionnalité est implémentée. Compilation et 11 tests de présentation
réussis. Parcours UI vérifiés avant l'arrêt : liste → détail → retour avec
défilement/hauteur conservés, retour après profil ami, états de réponse en
chargement/envoi avec itinéraire accessible, annulation depuis groupe puis pin.
La dernière passe des autres parcours est interrompue ; aucun succès global
n'est revendiqué. Le plan reste `in_progress` pour refléter cette validation
partielle, sans programmation d'une nouvelle passe simulateur.

### Correction des titres approuvée le 26 septembre 2026

Statut de la correction : `completed`, `completed_at: 2026-09-26`, après
enregistrement des statuts `approved` puis `in_progress`.
Samuel a répondu « je valide » au plan
présenté dans la conversation. Cette approbation couvre la correction suivante
dans le travail en cours ; elle ne relance pas les tests sur simulateur.

Résultat attendu : les listes Mes amis et Événements utilisent toutes deux
un en-tête de section natif, sans barre de navigation au-dessus de la liste.
La fiche événement conserve sa barre et son retour natif vers Événements.

Fichiers concernés par cette correction :
- `wander/MapEventsPanelView.swift` : en-tête de section et visibilité de la
  barre de navigation selon la destination.
- `wanderUITests/MapSocialGestureUITests.swift` : attentes de liste et de retour.
- Ce plan : approbation, suivi et validation.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md` :
  section « Architecture de navigation », distinction liste/fiche et propriété
  `updated`. Conserver les wikilinks et ne pas ouvrir Obsidian.

Checklist de la correction :
- [x] Rétablir l'en-tête et limiter la barre de navigation à la fiche.
- [x] Adapter les tests existants sans les exécuter.
- [x] Simplifier, compiler l'app et les tests, puis effectuer la revue.
- [x] Actualiser la note UX et consigner les résultats.

Risque principal : transmettre à la fiche la barre masquée de la liste et perdre
le bouton Retour. Définir explicitement sa visibilité sur chaque destination.
Conserver la pile, la sélection, les hauteurs et les positions de défilement.
Validation autorisée : compilation Debug et des cibles de tests, revue du diff.
Le rendu, la transition et le retour après défilement ne seront pas revérifiés
sur simulateur dans cette correction. Aucun test dédié d'accessibilité, aucune
commande Git mutante. Les changements locaux antérieurs sont conservés.

Validation de la correction :
- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build-for-testing`
  réussit le 26 septembre : `TEST BUILD SUCCEEDED`, code de sortie 0.
  Journal : `/tmp/wander-header-parity-build.log`.
- App et cibles de tests compilées, aucun test exécuté et aucune installation ou
  ouverture de simulateur. L'exécution UI reste exclue par la consigne de Samuel.
- Aucun nouveau diagnostic Swift. Les avertissements AppIntents et les versions
  d'extensions 15/27 contre 46 subsistent ; ces versions sont déjà suivies dans
  `todos/054-ready-p2-aligner-build-extensions.md`.
- `git diff --check` réussit. La comparaison avec les copies conservées sous
  `/tmp/wander-header-parity-before-20260926/` isole la correction du travail
  local antérieur.
- `ce-simplify-code` : trois lectures séparées, réutilisation, qualité et
  efficacité ; aucun constat retenu, aucune réécriture supplémentaire.
- `ce-code-review` : le helper rejette la base de fichiers avant correction
  avec `invalid base endpoint`. Il accepte seulement des références Git ;
  élargir la revue au diff de branche inclurait le travail précédent.
  `Code review: targeted manual due to unrelated branch work` : lecture du diff
  exact et contre-revue indépendante terminées, aucun constat actionnable.
  Reçu de cette revue manuelle : `/tmp/wander-header-parity-review/review.json`.
- `Documentation UX.md`, section « Architecture de navigation », actualisée
  avec la distinction liste/fiche et la limite de validation. Propriété
  `updated` changée, wikilinks comparés et conservés, Obsidian non ouvert.
- Aucun nouveau fichier `todos/` : aucun défaut propre à cette correction retenu.
  Pas de nouvelle fiche de solution : le changement repose sur les composants
  natifs déjà documentés et son rendu n'a pas été revérifié en exécution.

Les critères de cette correction sont satisfaits dans la limite approuvée de
compilation et de revue. Le plan global reste `in_progress` pour sa validation
UI antérieure interrompue ; cette correction ne la déclare pas terminée et ne
programme pas de nouvelle passe sur simulateur.

### Retirer le titre de catégorie du détail, approuvé le 26 septembre 2026

Statut de cet ajustement : `completed`, `completed_at: 2026-09-26`, après
enregistrement de `approved` puis `in_progress`.
Samuel a répondu « je valide » au plan
présenté pour retirer le titre de catégorie et ne garder que le retour natif.

Résultat attendu : aucun titre centré dans la barre du détail événement ; seul
le bouton retour natif « Événements » reste affiché. Les informations de la fiche,
les actions et les en-têtes des listes restent tels quels.

Fichiers concernés :
- `wander/MapEventDetailView.swift` : titre de navigation explicitement vide.
- `wanderUITests/MapSocialGestureUITests.swift` : vérifier le retour et l'absence
  du titre, identifier l'événement par le contenu de sa fiche.
- Ce plan : approbation, checklist et validation.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md` :
  section « Architecture de navigation » et propriété `updated`, wikilinks
  conservés, sans ouvrir Obsidian.

Checklist :
- [x] Vider le titre du détail en gardant la barre et son retour natif.
- [x] Adapter les assertions existantes de navigation et de contenu.
- [x] Simplifier et revoir le diff ciblé, compiler l'app et les tests.
- [x] Actualiser la note UX et enregistrer les résultats.

Risque : masquer la barre entière ferait disparaître le retour. Conserver sa
visibilité et son mode inline, modifier uniquement son titre. Les contrôles
existants de retour, de défilement et de hauteur sont conservés. Validation
limitée à la compilation et à la revue : aucun test exécuté, aucun simulateur
démarré. Aucun changement Git ; conserver les modifications locales antérieures.

Validation de cet ajustement :
- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build-for-testing`
  réussit avec `TEST BUILD SUCCEEDED`, code de sortie 0. Journal :
  `/tmp/wander-event-detail-title-build.log`. Aucun test exécuté.
- Aucun nouveau diagnostic Swift ; seuls les avertissements AppIntents déjà
  connus apparaissent dans cette compilation incrémentale.
- `git diff --check` réussit. Comparaison ciblée avec
  `/tmp/wander-event-detail-title-before-20260926/` : une ligne de présentation
  changée, assertions adaptées et helper de vérification commun aux parcours.
- Relectures de simplification : réutilisation, qualité, efficacité ; aucun
  changement supplémentaire utile. Revue de correction indépendante et lecture
  locale : aucun constat actionnable. Le helper `ce-code-review` reste limité
  aux références Git, comme documenté ci-dessus ; revue manuelle du seul diff
  de cet ajustement pour préserver le périmètre du travail local antérieur.
- La note `Documentation UX.md` indique désormais une barre de détail sans
  titre de catégorie, avec uniquement le retour natif. `updated` actualisé,
  wikilinks préservés, Obsidian non ouvert.
- Aucun nouveau constat à ajouter à `todos/` ni apprentissage distinct nécessitant
  une fiche de solution. Le rendu et les animations restent non revérifiés sur
  simulateur, conformément au périmètre approuvé.

Cet ajustement est terminé dans le périmètre approuvé. Il ne change pas le
statut `in_progress` de la validation globale du plan, interrompue précédemment.

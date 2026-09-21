---
title: Badges d'événements et liste sous la carte
status: completed
approved_at: 2026-09-20
completed_at: 2026-09-20
---

# Résultat attendu

Samuel a validé ce plan corrigé après avoir rejeté la densité du carrousel à
deux lignes. Les événements repliés doivent ressembler aux marqueurs de carte :
icône de catégorie d'environ 40 pt avec date/heure et état discret greffés dessus,
environ quatre à cinq événements visibles, défilement horizontal, matériau natif
translucide autour des badges. Un glissement vers le haut ouvre le split screen,
carte en haut et liste détaillée des événements en bas. La poignée règle la
hauteur ; rabattre le panneau retrouve les icônes.

## Périmètre

- Tap sur un badge : centrage et sélection de l'événement.
- Appui long : actions existantes. Liste développée : lieu, organisateur,
  participants, date et statut, actions de réponse/édition/itinéraire.
- Une carte MapKit stable et interactive dans les deux dispositions.
- Conservation des positions de défilement, des fiches d'amis et des états
  vide/chargement/erreur. Observations uniquement pour le contenu actif.
- Aucun changement Firebase, règle, modèle métier ou commande Git mutante.
- Validation limitée à la compilation de l'app et des cibles de tests, conformément
  à l'instruction toujours active « Non, compiler seulement ». Aucun simulateur lancé.

## Fichiers affectés

- `wander/MapEventBadgeView.swift`, nouveau composant reprenant le marqueur existant.
- `wander/MapEventsPanelView.swift`, badges et liste détaillée avec geste d'ouverture.
- `wander/MapDetailSplitView.swift`, liste en bas et carte stable au-dessus.
- `wander/ContentView.swift`, intégration de l'état et des callbacks.
- `wander/DebugSocialMapScenario.swift` et `wanderUITests/MapSocialGestureUITests.swift`.
- Ce plan et `todos/059-ready-p2-valider-carrousel-evenements.md`.
- Notes du vault `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Backlog features.md`, `Documentation UX.md`, `Documentation technique.md`,
  `00 - Wander.md`. Actualiser `updated` et préserver les wikilinks.

## Dépendances et mise en œuvre

- [x] Adapter le split avec une zone d'événements persistante en bas et une poignée.
- [x] Créer les badges compacts et restaurer les lignes détaillées dans le panneau.
- [x] Relier la production et le scénario local à la même composition.
- [x] Adapter les tests existants aux deux modes, aux gestes et aux observations.
- [x] Simplifier, compiler, relire et consigner les limites de validation.
- [x] Mettre à jour les quatre notes Obsidian et le suivi 059.

## Risques et critères d'acceptation

- Distinguer le glissement horizontal du geste vertical d'ouverture et du
  défilement vertical de la liste. La poignée porte le redimensionnement/repli.
- La carte garde les mêmes bounds de rendu pendant les changements de disposition.
- Les onglets restent accessibles ; les badges ne masquent pas les commandes.
- Les marqueurs sont reconnaissables sans description complète en mode replié.
- La liste détaillée apparaît sous la carte et disparaît lorsqu'on la rabat.
- Compilation réussie et revue effectuée ; rendu/gestes non exécutés à la demande
  de Samuel, à consigner explicitement sans annoncer de validation visuelle.

## Contexte d'exécution

Continuation des modifications locales de la première tentative sur `main`.
Elles appartiennent à la même demande ; aucun fichier tiers à annuler ni à publier.
La première tentative reste décrite dans son plan historique ; ce plan est la
référence produit courante.

## Validation et revue

- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build` : succès, `/tmp/wander-events-badges-build.log`.
- Même commande avec `build-for-testing` : `TEST BUILD SUCCEEDED`, code 0,
  `/tmp/wander-events-badges-build-for-testing.log`. App, tests unitaires et UI compilés.
- `git diff --check` : succès.
- Aucun simulateur démarré, test exécuté, capture ou contrôle visuel effectué.
  La limite produit est conservée dans le suivi 059. Aucun contrôle dédié
  d’accessibilité n’est ajouté comme validation requise.
- Avertissements hérités : extraction AppIntents sans dépendance au framework,
  versions des extensions 15/27 différentes de l’app 42, déjà suivies dans 054.
- Simplification `ce-simplify-code` : trois rubriques collectées. Deux réemplois
  de propriétés métier et suppression d’un état de visibilité redondant appliqués.
  Cinq suggestions laissées de côté : nouvelle configuration générique inutile
  pour les deux appels existants, changement de libellés hors simplification,
  trois optimisations de cache/horloge sans coût mesuré justifiant leur complexité.
- La hauteur du rail et la réserve du split utilisent la même métrique de texte
  système ; les contrôles natifs conservent leurs affordances d’accessibilité.
- Quatre notes Obsidian actualisées dans le vault existant, propriété `updated`
  comprise, sans ouvrir Obsidian ni créer de copie de vault.
- Revue `ce-code-review` : sept lectures, correction, Swift/iOS, tests, standards,
  maintenabilité, retours d’expérience et adversarial local. Aucun défaut retenu
  après synthèse. La proposition de modifier les couleurs de la poignée a été
  écartée : elles reprennent la présentation existante du split demandé.
  Dossier : `/tmp/compound-engineering-501/ce-code-review/20260920-174845-6ddfd949/`.
- Aucun changement Git mutant effectué.

## Réemploi des connaissances

Les invariants déjà documentés restent applicables : collection montée sous la
fiche, emplacement MapKit stable, bounds natifs inchangés, marges des contenus
séparées des bounds de rendu. Voir les solutions du 8 et du 10 septembre sur
ces sujets. Aucun nouveau comportement d’exécution n’a été vérifié qui justifie
une nouvelle fiche de solution.

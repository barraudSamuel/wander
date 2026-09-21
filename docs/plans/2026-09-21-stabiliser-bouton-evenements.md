---
title: Stabiliser le bouton événements après un changement de panneau
status: completed
approved_at: 2026-09-21
completed_at: 2026-09-21
---

# Résultat et périmètre

Samuel approuve le plan présenté dans la conversation avec « j'approuve le
plan ». Le calendrier doit conserver son diamètre après Profil → Événements,
Amis → Événements et fermeture de la liste, avec le rendu UIKit natif.
Pas de changement des actions, de la navigation ou des données.

## Fichiers affectés

- `wander/NativeMapTabView.swift`.
- `wanderUITests/MotionDockUITests.swift`.
- Ce plan et `todos/059-ready-p2-valider-carrousel-evenements.md`.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md`.

Actualiser `updated` dans les deux notes et préserver les wikilinks.

## Éléments du diagnostic

La vidéo fournie montre le cercle réduit après ouverture des événements, puis
toujours réduit après fermeture. Le code recalcule son diamètre entre 44 et
54 points depuis les bounds et safeAreaInsets de la barre transformée à 90 %.
Il assigne ensuite `eventsButton.frame`. Le SDK UIKit local, `UIView.h:188-194`,
demande d'utiliser bounds/center lorsque la vue est transformée. La configuration
du calendrier conserve une taille de symbole de 22 points dans les deux états.

Le test de retour depuis les panneaux contrôle la navigation mais pas les
dimensions. Le test depuis Explorer contrôle le frame seulement à l'ouverture.
Les valeurs réelles de safeAreaInsets et de la transformation du bouton pendant
la vidéo ne sont pas disponibles : la cause dynamique exacte reste une hypothèse.
Le correctif supprime ces deux dépendances de la géométrie au même endroit.

## Mise en œuvre

- [x] Renforcer les parcours existants pour comparer taille et position avant
  et après changements de panneau, ouverture et fermeture répétées.
- [x] Fixer le diamètre à 54 points, conserver l'ancrage supérieur et horizontal,
  placer le bouton via bounds/center et calculer la réserve du contenu depuis
  sa géométrie au repos.
- [x] Simplifier, compiler l'app et les tests, puis effectuer la revue ciblée.
- [x] Actualiser les notes UX/technique et le suivi 059 avec les preuves et limites.

## Résultats de validation

- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug
  -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution
  build-for-testing` : `TEST BUILD SUCCEEDED`, code 0. Journal
  `/tmp/wander-events-stable-size-build.log`.
- `git diff --check` : succès.
- Avertissements préexistants : métadonnées AppIntents sans dépendance au
  framework ; versions des extensions 27/15 contre 42, déjà suivies dans 054.
- `ce-simplify-code` : trois passes indépendantes réemploi/qualité/efficacité,
  aucun constat, aucune modification supplémentaire.
- `ce-code-review`, périmètre du correctif seulement, profondeur lite : aucune
  anomalie retenue. Lecture de la géométrie, des callbacks de layout et de la
  réserve de contenu ; aucune modification des callbacks d'action, de la
  sélection ou de la persistance. Reçu dans
  `/tmp/compound-engineering-501/ce-code-review/20260921-events-stable-size/review.json`.
- `ce-test-xcode` : `PARTIAL`. XcodeBuildMCP absent ; compilation réalisée avec
  la CLI existante. Aucun simulateur déjà démarré, donc parcours UI, rendu avec
  clavier et paysage `SKIP`. Pas de preuve rouge/verte ni de confirmation de la
  cause dynamique exacte ; ces limites figurent dans le suivi P2 059.
- Les deux notes Obsidian existantes sont actualisées, leurs champs `updated`
  modifiés et leurs wikilinks vérifiés inchangés, sans ouverture d'Obsidian.
- Pas de solution ajoutée dans `docs/solutions/` : aucun apprentissage nouveau
  vérifié en exécution. Le contrat UIKit bounds/center est une règle documentée
  par le SDK, pas une preuve de la transformation utilisée dans cette vidéo.

Décision principale : rendre la géométrie au repos indépendante du layout
transitoire et de la transformation du bouton. Garder uniquement le diamètre
constant laisserait le risque de l'assignation à `frame` ; forcer la transformation
à l'identité supprimerait les interactions natives. L'incertitude restante est
le rendu réel après correction, notamment clavier et paysage.

## Risques et validation

Vérifier par lecture l'alignement, la place disponible en largeur, le suivi du
clavier et l'indépendance des animations natives. Compiler avec
`xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug
-destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution
build-for-testing`, puis `git diff --check`.

`xcrun simctl list devices booted` ne retourne aucun appareil démarré. Aucun
appareil/runtime ne sera démarré ou créé. Pas de test UI exécuté ni de preuve
rouge/verte ; validation visuelle et gestuelle conservée explicitement dans 059.
Pas de test dédié d'accessibilité. Aucun Git mutant, commit ou publication.

## Critères d'acceptation

- La géométrie au repos du bouton ne dépend plus de la hauteur variable de la
  barre ni de la transformation animée du bouton.
- Les parcours UI existants compilent avec les assertions de non-régression.
- Compilation et revue terminées, limites de validation visuelle documentées.
- Les deux notes Obsidian sont actualisées, ou leur impossibilité d'écriture
  est rapportée avec les sections encore à mettre à jour.

## État initial

HEAD `5301b3b8f17c961aaaff48b2f4ec8fb125a8a2fd`, arbre propre. Exécution locale
avec le moteur natif, conformément aux règles Git du dépôt. Le statut approuvé
est enregistré avant toute modification du code.

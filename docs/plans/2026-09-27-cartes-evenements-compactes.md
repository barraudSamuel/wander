---
title: Cartes événements compactes et créateur inclus
status: completed
date: 2026-09-27
completed_at: 2026-09-27
owner: Samuel
---

# Cartes événements compactes et créateur inclus

Samuel a approuvé le plan présenté dans la conversation par « je valide ».

## Résultat et périmètre

Réduire la hauteur des cartes événements tout en conservant les informations
et les contrôles natifs. Le compteur et les avatars incluent l'organisateur
une seule fois : créateur seul = 1, créateur et un invité = 2.

## Approche

Réduire l'icône de catégorie, les marges et les espacements. Réunir la date
et la distance sur une ligne lorsque la largeur le permet, avec un repli
vertical. Garder les titres et adresses lisibles et les actions existantes.
Utiliser `visiblePeople`, qui inclut déjà l'organisateur et dédoublonne les
identifiants. Le résumé textuel continue à nommer l'organisateur une seule
fois. Garder les états de chargement et d'indisponibilité distincts du total.

La navigation, les services, les règles Firebase et les données persistées
restent hors périmètre. Les changements locaux préexistants sont conservés.
Aucune commande Git modificatrice, aucun commit ni publication.

## Fichiers concernés

- `wander/MapEventsPanelView.swift` : disposition et compteur.
- `wanderTests/MapEventListPresentationTests.swift` : créateur, doublons,
  refus et états inconnus.
- `wanderUITests/MapSocialGestureUITests.swift` : vérification fonctionnelle
  des compteurs dans les scénarios existants, si nécessaire.
- Ce plan, puis un finding dans `todos/` si la revue en révèle un.
- Coffre `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  - `Documentation UX.md`, section Sorties prévues.
  - `Documentation technique.md`, section Événements et participations.
  - `Backlog features.md`, entrée Valider les cartes événements autonomes.
  Actualiser `updated` et conserver les wikilinks des trois notes.

## Étapes

- [x] Approbation explicite du plan.
- [x] Adapter les tests du compteur.
- [x] Compacter les cartes et inclure l'organisateur dans l'aperçu.
- [x] Simplifier et relire uniquement le delta de ce travail.
- [x] Compiler l'app et les tests ; documenter l'exécution et le rendu indisponibles.
- [x] Mettre à jour les trois notes Obsidian.
- [x] Consigner la validation et la revue finale.

## Risques et validation

Les titres/adresses longs et les trois boutons d'un invité doivent tenir
sans chevauchement. Ne pas confondre groupe vide et groupe inconnu, ne pas
doubler l'organisateur et ne pas compter les refus. Conserver les noms du
résumé textuel existant.

Validation ciblée sur `MapEventListPresentationTests` et le parcours existant
`testEventListParticipantGroupsAndUnknownStates`, puis observation des cartes
organisateur et invité à taille de texte standard sur l'iPhone 17 déjà démarré.
Ne démarrer, créer ou télécharger aucun simulateur. Si le service simulateur
reste inaccessible, consigner cette limite et compiler l'app et les tests.
Aucun test d'accessibilité dédié.

## Critères d'acceptation

Cartes visiblement plus denses, informations conservées, créateur inclus
une fois dans le total chargé, états inconnus préservés, compilation et
tests ciblés réussis selon l'environnement accessible. Documenter précisément
toute validation indisponible et tout accès au coffre refusé.

## Suivi

Exécution native dans le répertoire courant, selon l'autorisation approuvée.
Les règles du dépôt sur Git et le suivi du plan priment sur les valeurs par
défaut de `ce-work`. Les fichiers Swift concernés comportaient déjà des
modifications avant ce travail ; la revue porte sur une copie de référence
prise au début de l'implémentation.

Le service CoreSimulator a répondu le 27 septembre : aucun appareil démarré.
XcodeBuildMCP n'est pas connecté. Suivi équivalent manuel avec `xcodebuild`,
sans installation d'outil ni démarrage de simulateur. La preuve rouge/verte
et l'observation UI ne peuvent pas être exécutées dans cet état ; les tests
seront compilés et leur exécution restera explicitement non vérifiée.

## Implémentation et simplification

L'icône passe de 48 à 32 pt et de `largeTitle` à `title2`. Les espacements
principaux passent de 12 à 6 pt, ceux de la description de 6 à 3 pt, et ceux
entre les sections de 12 à 8 pt. La ligne utilise des marges verticales de
8 pt et horizontales de 12 pt. Le séparateur et les boutons natifs sont
conservés. Date et distance partagent un `HStack` si leur largeur idéale
tient ; `ViewThatFits` propose sinon un `VStack` multilignes.

`participants(for:)` utilise le groupe dédupliqué existant, organisateur
en premier. Seul le résumé descriptif retire ce premier élément déjà nommé.
Le test existant couvre désormais les totaux 1 et 2, les doublons du créateur
et des invités, les refus et les états inconnus, pour les deux rôles. Les
légendes des captures du scénario UI sont alignées sur les totaux 1, 2, 4, 6.

`ce-simplify-code` : trois relectures indépendantes, réutilisation, qualité et
efficacité. Aucune proposition retenue, aucun changement supplémentaire.

## Validation effectuée

- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build-for-testing` : code 0, `TEST BUILD SUCCEEDED`.
- Journal : `/tmp/wander-compact-cards-build.log`.
- Aucun diagnostic Swift. Avertissements d'extraction AppIntents et écarts de
  `CFBundleVersion` des extensions, dans des configurations non modifiées
  par ce travail. Pas de modification de configuration hors périmètre.
- `git diff --check` réussi.
- `xcrun simctl list devices booted -j` : aucun appareil démarré. Aucun
  simulateur créé, démarré ou téléchargé. Tests ciblés et rendu non exécutés.
- Notes Obsidian mises à jour le 27 septembre à 10:57:34 +09:00,
  propriété `updated` actualisée ; comparaison des wikilinks avant/après
  strictement identique pour les trois notes. Obsidian n'a pas été ouvert.

## Choix et limites

Le point délicat est de compter le créateur dans le pied de carte sans le
répéter dans la phrase descriptive. Le modèle fournit déjà cet invariant ;
ajouter artificiellement 1 au compteur ou créer une inscription Firebase
introduirait deux définitions différentes et a été écarté.
Le rendu réel des longues adresses et des trois boutons reste la principale
incertitude sans simulateur actif. Aucun apprentissage nouveau au-delà des
invariants déjà documentés ne justifie une note `docs/solutions/` distincte.

## Revue finale

`ce-code-review`, revue de correction limitée aux trois fichiers du delta de
cette session : `status: complete`, `Ready to merge`, aucun finding ni
exigence manquante. Reçu :
`/tmp/compound-engineering-501/ce-code-review/20260927-105734-17433069/review.json`.
Les limites d'exécution des tests et de rendu sont conservées dans le reçu et
les notes Obsidian. Aucun finding de code à créer dans `todos/`.

Le périmètre approuvé est terminé avec compilation et revue. La validation
visuelle et l'exécution des tests restent non effectuées, conformément au
repli prévu sans simulateur actif. Aucun commit ni changement Git effectué.

---
title: "Profil et réglages dans une seule bottom sheet"
status: completed
completed_at: 2026-09-22T13:44:01+09:00
date: 2026-09-22
owner: Samuel
tags: [plan, map, profile, navigation]
---

# Profil et réglages dans une seule bottom sheet

## Approval and outcome

Plan présenté dans la conversation et explicitement approuvé par Samuel :
« je valide ». L’icône de profil remplace le filtre en haut à droite et ouvre
la même fiche que le pin personnel. L’onglet Profil disparaît de la barre du bas.

## Scope and dependencies

Reprendre les changements non commités du profil personnel. Conserver identité,
progression, position et adresse ; ajouter avatar, pseudo, couleur, mode fantôme,
fréquentation, localisation, notifications et actions du compte dans la même
feuille native. Garder les confirmations existantes et le cadrage de la carte.
Explorer, Amis et Événements restent accessibles depuis la navigation.

Aucun changement des services Firebase, règles, permissions ou modèle de données.
Aucune commande Git mutante. Implémentation native dans le checkout existant ;
les instructions utilisateur priment sur les changements de branche et commits
proposés par ce-work. Les changements préexistants sont conservés.

## Affected files

- `wander/ContentView.swift`
- `wander/OwnProfileSheet.swift`
- `wander/ProfilePanelView.swift`
- `wander/MotionDockView.swift`
- `wander/NativeMapTabView.swift`
- `wander/FriendProfileSheet.swift`
- `wander/DebugSocialMapScenario.swift`
- `wanderUITests/MotionDockUITests.swift`
- `wanderUITests/MapSocialGestureUITests.swift`
- `wanderTests/FriendProfilePresentationTests.swift`
- Ce plan et, si la revue établit un défaut restant, un fichier priorisé dans `todos/`.
- Obsidian, racine `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  - `Backlog features.md` : regroupement du profil et statut de livraison.
  - `Documentation technique.md` : responsabilité des vues, présentation et navigation.
  - `Documentation UX.md` : accès au profil, réglages, fréquentation et confirmations.
  - `00 - Wander.md` : résumé de la navigation.
  - Mettre à jour `updated` et préserver les wikilinks pour chaque note.

## Implementation

- [x] Réutiliser les réglages et actions existantes dans la fiche personnelle.
- [x] Préserver une hauteur compacte indépendante de la longueur des réglages.
- [x] Unifier les accès par bouton et pin ; supprimer filtre et onglet Profil.
- [x] Adapter le scénario local et les tests concernés.
- [x] Simplifier, compiler, relire et consigner les résultats.
- [x] Mettre à jour les quatre notes Obsidian.

## Risks

- Le formulaire, le clavier et la mesure de hauteur ne doivent pas se gêner.
- Les confirmations du compte doivent bloquer fermeture et navigation concurrente.
- L’état de la liste d’événements doit survivre à l’ouverture du profil.
- La suppression de l’onglet ne doit pas déplacer la carte ni masquer Événements.
- Les deux accès doivent rester utilisables même sans position disponible.

## Validation and acceptance

Adapter les tests existants de navigation, de clavier et de sélection personnelle.
Vérifier la mesure compacte avec un contenu visible plus long que le résumé.
Compiler l’app et les cibles de tests ; contrôler le diff et les transitions
de compte. La preuve avant implémentation est la lecture des tests existants,
qui attendent encore trois onglets et le filtre. Pas de passage rouge runtime
possible sous la contrainte simulateur ci-dessous.

Le 22 septembre, `xcrun simctl list devices booted` montre uniquement un iPhone
16e. Le plan autorise les parcours sur l’iPhone 17 déjà démarré uniquement.
Aucun test ni parcours sur un autre appareil, aucun démarrage de simulateur.
Cette limite devra rester explicite dans le compte rendu final.

Acceptation : une seule fiche personnelle, les réglages existants accessibles,
le filtre et l’onglet supprimés, compilation réussie et documentation cohérente.
Les parcours UI non exécutés ne seront pas présentés comme validés.

## Implementation details

- `presentOwnProfile` est partagé par le pin et le bouton `map-own-profile`.
- Le formulaire existant conserve ses actions et ajoute le binding de fréquentation.
- La mesure ne monte que le résumé. Le formulaire visible assure lui-même le
  défilement ; pas de formulaire imbriqué dans une `ScrollView`.
- La feuille interdit sa fermeture interactive durant un flux du compte ; les
  sélections de profil, événement et création sont protégées pendant ce flux.
- La largeur du conteneur natif passe à 50 % de la zone sûre, maximum 220 points,
  pour les deux onglets ; la réduction de 10 % et le calendrier séparé restent.
- Le scénario DEBUG injecte un formulaire local, sans opération de compte réel.

## Verification evidence

- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug
  -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution
  build-for-testing` : `TEST BUILD SUCCEEDED`.
- Journal initial : `/tmp/wander-unified-profile-build.log`.
- Aucun diagnostic Swift nouveau. Avertissements préexistants AppIntents et
  versions d’extensions 15/27 contre 43, déjà suivis dans `todos/054-ready-p2-aligner-build-extensions.md`.
- Tests adaptés : deux onglets, accès bouton/pin, conservation pseudo/fréquentation,
  clavier, confirmations, paysage et liste d’événements. Régression de mesure :
  formulaire long ouvert à la hauteur du résumé.
- `ce-test-xcode` lu ; XcodeBuildMCP indisponible. Validation équivalente manuelle
  par CLI pour la compilation. Aucune exécution de tests, installation ou capture.
- Les quatre notes Obsidian ont été mises à jour le 22 septembre avec `updated`.
  Frontmatter et délimiteurs des wikilinks contrôlés, sans ouvrir Obsidian.

## Simplification

`ce-simplify-code` : trois lectures indépendantes terminées.
Réutilisation : aucun changement nécessaire. Qualité : suppression de l’import SwiftData inutilisé dans `ProfilePanelView`.
L’import CoreLocation proposé comme inutile a été rétabli après rejet par le
compilateur, car les cas de son enum d’autorisation l’exigent. Efficacité : aucun changement retenu.
Propositions écartées : extraction des sélections préexistantes hors du périmètre
et suppression d’une revalidation de disponibilité d’ami avant itinéraire, qui
changerait la protection au moment du toucher.

## Review

La lecture du routage relève qu’une demande d’amitié notifiée doit maintenant
fermer la feuille personnelle avant d’afficher Amis. Le callback conserve ses
gardes de disponibilité et de flux du compte, puis efface seulement une sélection
de profil. Il conserve un événement déjà sélectionné. Correction appliquée et
compilation relancée ; validation fonctionnelle limitée à la lecture des callbacks.

L’envoi du diff privé à Grok via Cursor a été refusé par le contrôle automatique
d’autorisation : destination externe non autorisée pour ce contenu. Aucun job
n’a démarré et aucun contenu n’a été envoyé. La revue utilise le repli local.

Le test de conservation du défilement distingue explicitement le panneau Amis,
qui préserve la sélection d’événement, de la fiche personnelle, qui devient la
sélection exclusive comme le pin personnel existant. Après fermeture du profil,
la liste et son défilement restent en place, sans restaurer une sélection cachée.
Ce comportement est identique depuis le bouton et le pin.

Compilation finale après correction du routage et adaptation de cette assertion :
`TEST BUILD SUCCEEDED`, journal `/tmp/wander-unified-profile-build-final.log`.
`git diff --check` passe. Aucun test runtime exécuté.

## Review conclusions

Les neuf lectures locales sont terminées. Aucun défaut confirmé dans le
regroupement. La présentation illustrée et la sélection exclusive viennent du
profil personnel préexistant demandé par Samuel et sont conservées. Les lacunes
de tests du géocodage et du cadrage préexistant restent des limites de couverture,
sans nouveau défaut établi ni élargissement de cette implémentation.

- Décision principale : mesurer seulement le résumé pour conserver le palier
  compact, tout en affichant un formulaire natif complet.
- Alternatives écartées : imbriquer le formulaire dans une `ScrollView`, mesurer
  tous les réglages à l’ouverture ou dupliquer les opérations de compte.
- Incertitude restante : rendu, clavier, gestes et confirmations en exécution.
  Les tests sont compilés, jamais présentés comme exécutés.
- Compound : pas de nouvelle solution autonome. Réutilisation de la présentation
  native déjà documentée ; aucune nouvelle observation runtime vérifiée.

Les critères d’acceptation du périmètre de validation autorisé sont satisfaits :
regroupement implémenté, app et tests compilés, revue locale terminée sans défaut
confirmé, notes Obsidian actualisées. La validation UI reste explicitement non
exécutée et suivie dans le backlog ; aucun succès runtime n’est revendiqué.

Reçu `ce-code-review` : `status: complete`, verdict `Ready to merge`, zéro constat
et zéro action restante. Fichier :
`/tmp/compound-engineering-501/ce-code-review/20260922-unified-profile/review.json`.

La revue précise que le formulaire DEBUG ne valide pas les opérations réelles de
`ProfilePanelView`. Annulation/erreur de déconnexion, réauthentification Apple,
verrouillage de fermeture et reprise d’une notification restent à vérifier en
exécution sur l’appareil autorisé, sans effectuer d’action destructive réelle.
Aucun fichier `todos/` ajouté : aucun défaut confirmé restant ; les limites de
validation figurent dans ce plan et le backlog Obsidian.

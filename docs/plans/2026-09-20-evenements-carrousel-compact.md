---
title: Événements en carrousel compact sur la carte
status: completed
completed_at: 2026-09-20T17:23:53+09:00
approved_at: 2026-09-20
---

# Résultat attendu

Remplacer le panneau permanent d'événements au-dessus de la carte par une
rangée horizontale de 80 à 90 points, placée juste au-dessus de la navigation.
Le matériau iOS laisse discerner la carte derrière un flou translucide.
Samuel a explicitement approuvé ce plan dans la conversation le 20 septembre.

## Périmètre et décisions approuvées

- Deux lignes par événement : emoji, activité et horaire, puis lieu et organisateur.
- Indicateur discret de participation, ordre chronologique, aperçu du suivant.
- Toucher un événement centre la carte ; appui long pour les actions existantes.
- Les profils d'amis conservent leur panneau ; le retour conserve le défilement.
- États vide, chargement, erreur et réessai compacts ; recentrage au-dessus du rail.
- Contrôles et matériau natifs iOS. Aucun changement Firebase ni de modèle métier.

## Fichiers affectés

- `wander/MapEventsPanelView.swift` : présentation horizontale et actions.
- `wander/ContentView.swift` : placement du rail et du recentrage sur la carte.
- `wander/MapDetailSplitView.swift` si les marges partagées nécessitent une adaptation.
- `wander/DebugSocialMapScenario.swift` et `wanderUITests/MapSocialGestureUITests.swift` :
  adapter le scénario existant et les validations de la présentation remplacée.
- Ce plan ; `todos/` pour les constats éventuels.
- Vault `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Backlog features.md` (agenda compact), `Documentation UX.md` (carte et événements),
  `Documentation technique.md` (composition des vues et observations),
  `00 - Wander.md` (état du projet). Mettre à jour `updated` et conserver les wikilinks.

## Mise en œuvre

- [x] Remplacer la liste verticale par le carrousel translucide.
- [x] Intégrer le carrousel sans recréer la carte ni perdre les profils d'amis.
- [x] Adapter les scénarios et tests existants aux gestes horizontaux.
- [x] Simplifier et relire le changement.
- [x] Compiler l'application et les cibles de tests, sans exécuter les parcours.
- [x] Mettre à jour les quatre notes Obsidian et leur propriété `updated`.
- [x] Consigner les résultats exacts et la revue finale.

## Risques et validation

Vérifier lisibilité, conflits de gestes carte/carrousel, marges de navigation,
retour de profil, sélection, appui long, édition et états vide/chargement/erreur.
Réutiliser les tests de présentation et les scénarios locaux sans compte réel.
Pas de tests dédiés d'accessibilité ni de nouveau simulateur/runtime.
Le simulateur iPhone 17 existant est éteint au début du travail : son démarrage
a été refusé par Samuel : « Non, compiler seulement ». Aucun lancement ni test
simulateur ne sera effectué ; validation limitée à la compilation et à la revue.
Le vault est hors des racines d'écriture : demander l'accès sandbox pour la mise
à jour autorisée ; consigner toute note non mise à jour si l'accès échoue.

## Critères d'acceptation

- Rangée de 80–90 pt à taille de texte standard, sur la carte, au-dessus des onglets.
- Plusieurs événements consultables horizontalement, matériau système translucide.
- Sélection, actions, retour des profils et suspensions des observations fonctionnels.
- Compilation réussie et revue effectuée, limites explicites. Les parcours visuels
  ne font plus partie des validations à exécuter dans cette session, sur instruction
  explicite de Samuel après approbation du plan.

## Exécution

Implémentation native dans la session, un ensemble de vues étroitement couplées.
État initial propre sur `main`. Aucune commande Git mutante, aucun commit ni push,
conformément aux consignes de Samuel. Le suivi dans le plan suit AGENTS.md.

## Validation et revue

- Première compilation Debug de l'app réussie :
  `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build`.
  Journal : `/tmp/wander-events-carousel-build.log`.
- Aucun nouveau diagnostic Swift. Avertissements connus d'extraction AppIntents
  et de versions d'extensions 15/27 contre 42 pour l'app, déjà suivis dans le
  constat [054](../../todos/054-ready-p2-aligner-build-extensions.md).
- Compilation de l'app, des tests unitaires et UI réussie à 17:12 KST :
  `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build-for-testing`.
  Résultat `TEST BUILD SUCCEEDED`, code de sortie 0. Journal :
  `/tmp/wander-events-carousel-build-for-testing.log`. Ce résultat valide la
  compilation des tests, pas leur exécution.
- Après ajout des assertions de suspension/reprise des participants à l'ouverture
  et à la fermeture d'un profil ami, même `build-for-testing` réussi à 17:15 KST.
  Journal final : `/tmp/wander-events-carousel-final-build.log`, code de sortie 0.
  Seul l'avertissement AppIntents préexistant est émis par cette passe incrémentale.
- Les scénarios de redimensionnement portent désormais sur les fiches d'amis.
  Les scénarios d'événements utilisent le défilement horizontal, les menus
  contextuels, le placement au-dessus des onglets et le retour de profil.
  Les assertions de zoom tiennent compte de la portion libre au-dessus du rail.
- Simplification `ce-simplify-code` : trois lectures indépendantes réutilisation,
  qualité et efficacité. Une duplication de la politique de masquage a été
  consolidée dans `MapEventsPanelView.isPresented`. Deux suggestions concernant
  le tri et le rafraîchissement périodique hérités ne sont pas appliquées : pas
  de régression démontrée, coût minime, ajout de cache ou de minuterie non justifié.
- Les quatre notes du vault ont été mises à jour le 20 septembre à 17:09 KST.
  Frontmatter `updated`, liens au plan et paires de wikilinks contrôlés.
- Validation UI limitée par choix explicite de Samuel : ni démarrage, ni test,
  ni capture de simulateur. Les anciens tests des listes verticales ne prouvent
  pas le rendu du nouveau carrousel.
  Suivi fonctionnel : [059](../../todos/059-ready-p2-valider-carrousel-evenements.md).

- Revue `ce-code-review`, sept lectures : correction, Swift/iOS, tests, normes du
  projet, maintenabilité, enseignements existants et recherche de régressions.
  Zéro constat nécessitant une correction. Le contrôle manquant sur la suspension des
  groupes a été ajouté au scénario de retour de profil et compilé. Le nettoyage
  des helpers compacts a été rejeté par la validation indépendante : aucun
  défaut actuel démontré. Les helpers et leurs tests unitaires restent conservés.
  Dossier de revue : `/tmp/compound-engineering-501/ce-code-review/20260920-171036-399ad4dc/`.
- `git diff --check` passe. Aucun changement de configuration, dépendance,
  schéma Firebase, commande Git mutante ou lancement de simulateur.
- Pas de nouvelle fiche `docs/solutions/` : les patterns de viewport stable et
  de vues conservées sous les panneaux sont déjà documentés ; aucun nouvel
  enseignement runtime vérifié n'a émergé de cette validation par compilation.

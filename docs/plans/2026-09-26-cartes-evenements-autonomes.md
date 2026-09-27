---
title: Cartes événements autonomes
status: completed
started_at: 2026-09-26
completed_at: 2026-09-26
date: 2026-09-26
approved_at: 2026-09-26
owner: Samuel
---

# Cartes événements autonomes

## Résultat et approbation

Samuel a approuvé le plan présenté dans la conversation avec « je valide ».
Remplacer les cartes agrandies et la fiche détail par une carte autonome,
suivant la dernière image fournie : icône de catégorie à gauche, description
à droite, actions et participants en bas. Cette décision remplace les plans
de détail narratif et de cartes agrandies du 26 septembre.

## Périmètre et étapes

- [x] Remplacer la carte bouton par une section native de List : icône,
  organisateur, activité, lieu, date/heure et distance fiable disponible.
- [x] Afficher directement Participer / Refuser, ou Modifier pour l'organisateur,
  Itinéraire et un aperçu des participants avec compteur. Conserver les états
  chargement, indisponibilité et envoi, ainsi que les permissions existantes.
- [x] Supprimer détail, zoom, swipe actions, menu par appui long et expansion
  automatique. La carte elle-même ne déclenche aucune navigation.
- [x] Faire converger repères, groupes et notifications vers la liste sur la
  carte ciblée, y compris un nouveau tap sur le même repère. Conserver le focus
  géographique et la liste montée, avec une seule hauteur réglable.
- [x] Limiter les observations de participants aux cartes visibles lorsque la
  liste est active ; conserver les observations propres aux services existants.
- [x] Adapter les tests fonctionnels existants, simplifier, compiler et revoir.
- [x] Actualiser la documentation et les anciens plans sans effacer l'historique.

## Fichiers concernés

- `wander/MapEventsPanelView.swift` : carte, actions et ciblage du défilement.
- `wander/MapEventDetailView.swift` : suppression, plus aucun appel nécessaire.
- `wander/MapDetailSplitView.swift` : retrait de la géométrie propre au détail.
- `wander/ContentView.swift` : sélection de repère, notification et observations.
- `wander/MapWithFogView.swift` : raccord minimal du second toucher sur un
  repère événement déjà sélectionné, nécessaire au ciblage répété approuvé.
  La sélection au début du toucher distingue ce geste du premier callback
  natif ; aucun changement au rendu MapKit ou aux profils.
- `wander/DebugSocialMapScenario.swift` : mêmes branchements pour les scénarios.
- `wanderUITests/MapSocialGestureUITests.swift` : actions directes, absence de
  détail/swipe, défilement, repères, fermeture/réouverture, chargements/erreurs.
- Ce plan, les deux plans événements du 26 septembre et `todos/` pour constats.
- Coffre Obsidian existant
  `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Backlog features.md`, `Documentation UX.md`, `Documentation technique.md`,
  `00 - Wander.md`. Actualiser `updated`, préserver les wikilinks, ne pas ouvrir
  Obsidian. En cas d'accès impossible, consigner les sections non actualisées.

## Contraintes et risques

UI native iOS, boutons système, aucune donnée ni règle Firebase nouvelle.
Préserver profils, édition/annulation, itinéraires, tri, géométrie MapKit et
changements non liés. Aucun Git mutant, commit, PR ou export externe.
Risques : boutons imbriqués dans une List, demandes répétées de défilement,
événement absent pendant le chargement, liste masquée par un profil, observations
conservées hors écran. Les actions doivent être indépendantes, le ciblage ne
doit pas déclencher une navigation ou une observation de détail.

## Validation et acceptation

La suspension des tests simulateur reste applicable. Aucun lancement, test,
capture, installation ou nouveau simulateur. Adapter les tests puis compiler
uniquement, sans revendiquer de preuve rouge/verte ou de résultat visuel.

Commande :
`xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build-for-testing`

- [x] Carte autonome conforme au contenu convenu ; chaque action reste disponible.
- [x] Aucun détail, zoom ou action de swipe ; hauteur du panneau stable au ciblage.
- [x] Repère et notification amènent à la carte ; retour aux panneaux conserve le scroll.
- [x] Scénarios adaptés et compilés ; revue terminée, aucun diagnostic Swift nouveau.
- [x] Documentation alignée et limites visuelles explicitement consignées.

Ces critères décrivent l'implémentation relue et la validation autorisée.
Ils ne constituent pas une validation des interactions ou du rendu en exécution.

## Validation réalisée

Exécution native avec `ce-work`, sur les
fichiers déjà modifiés pour l'approche remplacée. Les règles AGENTS sur Git,
l'approbation, la tenue du plan et le simulateur priment sur les automatismes
des skills.

- Unité UI tests confiée à un worker local, limitée au seul fichier approuvé,
  après stabilisation des interfaces. Helpers de fiche/menu retirés ; actions
  recherchées dans la carte correspondante et amenées dans la zone visible.
  Scénarios conservés pour carte/profils, réponses, annulation, erreurs et
  observations. Scénarios adaptés pour corps de carte inerte, repère répété et
  absence d'agrandissement. Aucun rouge/vert exécuté.
- `ce-simplify-code` : trois lectures distinctes réutilisation, qualité et
  efficacité. Trois simplifications qualité appliquées : ancien paramètre de
  recentrage supprimé, observation de sélection superflue retirée, hauteur du
  split revenue à son interface initiale. Un changement efficacité : tri sorti
  du TimelineView pour ne pas le refaire à chaque actualisation de distance.
  Réutilisation du helper de toucher dans quatre tests laissée telle quelle :
  gain limité et ajout d'un second appel de révélation de carte inutile.
- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build-for-testing`
  réussit avec `TEST BUILD SUCCEEDED`, code 0. Journal :
  `/tmp/wander-autonomous-cards-build.log`. Aucun diagnostic Swift ; un
  avertissement préexistant d'extraction AppIntents sans framework associé.
- `git diff --check` passe. `ce-test-xcode` consulté : surfaces UI `SKIP`,
  résultat `PARTIAL` conformément à la suspension approuvée. Aucune action
  sur simulateur, aucun résultat visuel ou d'interaction revendiqué.
- Les quatre notes Obsidian sont finalisées : implémentation et revue terminées,
  compilation validée et exécution UI non vérifiée. Leurs propriétés `updated`
  sont actualisées et leurs 41 occurrences de wikilinks sont préservées.
  Les anciennes approches sont signalées comme remplacées dans les deux plans
  et le constat 064. Aucune ouverture d'Obsidian.
- Revue `ce-code-review mode:agent base:HEAD` terminée, locale uniquement :
  `status: complete`, run `20260926-autonomous-cards`, artefacts dans
  `/tmp/compound-engineering-501/ce-code-review/20260926-autonomous-cards`.
  Sept lectures spécialisées, fusion et validation indépendante. Le reçu
  avant correction conclut « Ready with fixes » avec un seul constat P2.
- Ce P2 est corrigé : le second toucher sur un repère déjà sélectionné émet
  maintenant une nouvelle demande de ciblage. La sélection est capturée au
  début du toucher pour éviter de doubler le premier callback natif.
  Relecture ciblée indépendante du correctif : aucun nouveau constat retenu.
  Résolution consignée dans [065](../../todos/065-done-p2-recibler-evenement-deja-selectionne.md).
- Le candidat de couverture initiale/différée a été rejeté comme défaut P2,
  sans bug de production démontré. Une assertion initiale utile a néanmoins
  été ajoutée : ouverture directement sur la carte 18 sans helper de défilement.
- Compilation finale après correction avec la même commande :
  `TEST BUILD SUCCEEDED`, code 0, journal
  `/tmp/wander-autonomous-cards-final-build.log`. Aucun diagnostic Swift ;
  trois avertissements préexistants AppIntents. `git diff --check` passe.
  Aucun test ni simulateur exécuté.

## Décisions et limites

La principale décision est de séparer la demande ponctuelle de défilement de
la sélection du repère : conserver celle-ci ne doit ni rouvrir une fiche ni
redéfiler à chaque retour au panneau. Un UUID identifie chaque demande.
Réutiliser la pile de détail ou sa géométrie aurait gardé les comportements
explicitement retirés ; ils ont été supprimés.

Le point le moins certain reste le défilement natif à l'ouverture initiale
et les zones visibles dans un panneau compact. Les scénarios sont compilés,
mais leur exécution reste suspendue. Aucun enseignement nouveau vérifié en
exécution ne justifie une nouvelle note `docs/solutions/` ; le correctif est
documenté dans le constat et les notes existantes.

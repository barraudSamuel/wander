---
title: "Fiches carte narratives et adaptatives"
status: completed
date: 2026-09-08
approved_at: 2026-09-08
completed_at: 2026-09-08T18:15:00+09:00
owner: Samuel
tags: [plan, map, ux, accessibility]
---

# Fiches carte narratives et adaptatives

## Résultat et approbation

Samuel a approuvé le plan présenté dans la conversation par « j'approuve ».
Les fiches événement et joueur d'Explorer ont un titre utile et une fermeture
fixes, un résumé narratif adaptatif et des actions fixes sur une seule ligne.
La référence fournie guide le texte mêlant informations, icônes et avatars.
Les contrôles, couleurs et polices restent natifs iOS.

## Périmètre et décisions

- Nom du lieu ou du joueur dans l'en-tête, adresse complète retirée du résumé.
- Organisateur, activité et date en couleur principale ; mots de liaison en
  couleur secondaire. Avatars des participants dans le flux, puis +N si besoin.
  Les refus restent distincts et les noms restent disponibles pour VoiceOver.
- Itinéraire, refus et participation sur une seule ligne fixe. Icônes seules
  lorsque les textes ne tiennent plus ; cibles d'au moins 44 points et libellés
  accessibles complets. L'organisateur conserve Modifier.
- Espacements, texte et avatars s'adaptent à la hauteur pendant le glissement,
  puis le résumé défile à sa taille minimale lisible. Dynamic Type reste respecté.
- Même adaptation pour le joueur, avec position et itinéraire. Les états de
  chargement, erreur, réponse, position ancienne/absente et mode fantôme restent.
- Périmètre limité à la présentation : callbacks sociaux, sélection, Firebase,
  création/modification d'événement et feuille de l'onglet Amis conservés.

## Fichiers concernés

- `wander/MapDetailSplitView.swift` : présentation adaptative partagée, limites
  de hauteur et maintien de la surface MapKit stable.
- `wander/OutingPlanDetailCardView.swift` : résumé narratif et actions fixes.
- `wander/FriendProfileSheet.swift` : panneau joueur narratif et actions fixes.
- `wander/DebugSocialMapScenario.swift` : données locales pour les cas limites.
- `wanderUITests/MapSocialGestureUITests.swift` : visibilité, réponses et resize.
- Ce plan ; constats de revue dans `todos/`, apprentissage vérifié éventuel
  dans `docs/solutions/`.

Notes du coffre `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :

- `Backlog features.md` : En cours, fiches carte et validation.
- `Documentation UX.md` : Fiches et carte partagée, amis, sorties, accessibilité.
- `Documentation technique.md` : Carte, responsabilités des vues, validation.
- `00 - Wander.md` : État du projet.

Mettre à jour `updated`, préserver les wikilinks et vérifier la lecture Obsidian.
Le coffre est lisible mais hors des racines d'écriture initiales ; si l'accès
échoue, enregistrer les sections restantes sans créer de coffre de substitution.

## Mise en œuvre

- [x] Composer le résumé partagé et sa typographie adaptative bornée.
- [x] Adapter l'événement et le panneau joueur avec actions fixes accessibles.
- [x] Étendre les fixtures et adapter les tests UI existants.
- [x] Simplifier, compiler, tester les parcours et effectuer la revue.
- [x] Mettre à jour les notes Obsidian et vérifier leur lecture initiale.

## Risques et validation

- Éviter les oscillations de layout : taille déterminée par la hauteur proposée,
  sans boucle d'observation de la taille du contenu.
- Conserver les dimensions natives MapKit pendant le resize ; réutiliser les
  tests de géométrie et de gestes existants.
- Garder le résumé accessible avec noms longs, nombreux avatars, grandes polices,
  faible hauteur et mode sombre ; aucun bouton masqué sous la poignée.
- Contrôler les réponses oui/non, la mise à jour en cours, l'indisponibilité,
  l'itinéraire et l'action Modifier dans les fixtures locales.
- Compilation Debug sans nouvel avertissement, tests ciblés et captures sur
  l'iPhone 17 déjà démarré uniquement. Aucun nouveau simulateur/runtime.
- Vérification du rendu en plusieurs hauteurs, portrait/paysage, grandes polices,
  fermeture, remplacement ami/événement, déplacement et zoom de carte.
- Pas de Git mutateur : travail dans le checkout courant conformément aux
  instructions explicites du propriétaire, sans branche, commit ou publication.

## Stratégie de preuve

Les tests UI existants prouvent les gestes et la stabilité MapKit mais attendent
encore des actions défilantes. Ils seront adaptés au nouveau contrat et complétés
par des scénarios de réponse et d'accessibilité. Pour cette évolution visuelle,
la validation intégrée et les captures suivent l'implémentation coordonnée ; pas
de tests unitaires reproduisant les détails de mise en page.

## Validation exécutée et revue

L'arbre initial était propre. L'iPhone 17
6F13855D-10B8-45AF-9205-17C8393379E3 était déjà démarré sous iOS 26.3.1.

- XcodeBuildMCP absent : validation équivalente via Xcode, XCTest et simctl.
- Première passe : 2/3 tests passent ; la cible verticale de l'action Itinéraire
  mesurait 42 pt. La hauteur minimale du label a été corrigée pour obtenir 44 pt.
- Deuxième passe : participation oui/non et états chargement/indisponible/écriture
  passent. Le contrôle du profil lisait la géométrie à deux instants pendant
  l'animation ; il attend désormais l'alignement final panneau/poignée.
- Inspection des captures : suppression de la répartition forcée en colonnes
  égales, qui faisait déborder le libellé de participation dans son bouton.
- Cas AX5 ajouté en paysage et panneau agrandi : nombre d'avatars borné par la
  largeur proposée, avec +N exact et tous les noms conservés pour VoiceOver.
- Simplification : aucune opportunité de réutilisation exacte ; deux calculs
  répétés consolidés, participants/déclinaisons et fixtures carte/détail.
  La proposition de retirer FriendProfileFields a été rejetée : la feuille
  native de l'onglet Amis en dépend toujours.
- Deux avertissements préexistants de CFBundleVersion dans les extensions
  sont apparus au premier build, sans nouvel avertissement Swift.

- Première suite complète : 57/60 passent. En AX5 paysage, le résumé ne
  disposait que de 29 points ; la réserve minimale de carte a été réduite sur
  les fenêtres courtes, et les seuils de croissance suivent aussi Dynamic Type.
  Le résumé conserve ainsi sa taille minimale au lieu de grossir prématurément.
  L'échec interrompait la remise en portrait et contaminait les deux tests
  suivants ; chaque setUp impose et attend désormais le portrait effectif.
- Revue ce-code-review : six angles locaux et une validation séparée, aucun
  constat P1/P2 restant. Le dernier delta de hauteur et d'orientation a été relu.
  Aucun processus de revue externe, aucune modification des interactions MapKit.
- Les quatre notes Obsidian ont été mises à jour et inspectées en mode lecture.
  Leurs propriétés, liens, paragraphes, listes et callouts s'affichent ; les
  30 wikilinks pointent vers des notes et sections existantes. Le tableau et le
  Mermaid techniques existants sont conservés, sans modification de leur contenu.

## Bilan final

- Build Debug valide, aucun nouvel avertissement Swift.
- `/tmp/wander-responsive-regression.xcresult` : 55/60. Les quatre nouveaux
  scénarios passent, dont les réponses, les états indisponibles, les profils
  fantômes/sans position/anciens et AX5 en portrait/paysage.
- Les cinq échecs restants concernent trois contrôles MapKit existants et deux
  tests UI. Les activités de `testDetailScrollKeepsPaneAndHeaderInPlace`
  montrent une interruption par `com.sheepesports.app` avant le toucher ; cette
  observation ne prouve pas la cause des quatre autres échecs.
- Reprise de ces cinq contrôles sans modifier le code :
  `/tmp/wander-responsive-recheck.xcresult`, **5/5**. Les 43 tests unitaires et
  17 tests UI prévus sont ainsi validés sur la version finale, sur deux passes.
  Aucun résultat global 60/60 en une seule exécution n'est revendiqué.
- Sélections, suppression dans les deux ordres, fermeture, glissement, zoom,
  plein écran et dimensions natives MapKit stables sont couverts.
- Captures finales : `/tmp/wander-responsive-regression-captures/` pour le
  mode sombre, les participants nombreux et AX5 ;
  `/tmp/wander-fiche-responsive-clair.png` pour le mode clair. La capture claire
  et les captures portrait ont été inspectées. XCTest valide la géométrie AX5
  paysage ; son export de capture présente un cadrage tourné imparfait.
- `git diff --check` passe. Aucun Git mutateur, backend, modèle ou règle
  Firestore modifié. Le constat corrigé figure dans
  `todos/037-done-p2-preserver-resume-et-actions-en-faible-hauteur.md`.
- Notes Obsidian finalisées à 18:14:28 : frontmatter, fences et wikilinks
  valides. Le rendu avait été vérifié avant le bilan final. Une modification
  concurrente de `AGENTS.md`, constatée en fin de tâche, interdit désormais
  d'ouvrir Obsidian sans demande explicite : aucune nouvelle ouverture après
  cette lecture, et cette modification du propriétaire est conservée.
- ce-compound : aucune nouvelle solution durable. Les contraintes de largeur,
  les seuils typographiques et les attentes de géométrie sont récupérables
  dans l'implémentation, les tests et ce plan ; une fiche serait redondante.

Limites : libellés, noms complets et états accessibles vérifiés par XCTest,
mais pas de parcours VoiceOver vocal complet. Le suivi existant
`todos/034-ready-p2-valider-groupes-en-tres-grande-police.md` reste ouvert.
Les transitions Firebase réelles et le nouvel aspect sur iPhone physique
n'ont pas été retestés dans cette tâche. Le contrôle physique Metal décrit
dans les notes concerne le correctif précédent.

Commande de validation complète :

```sh
xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'id=6F13855D-10B8-45AF-9205-17C8393379E3' \
  -derivedDataPath /tmp/wander-participant-badge-derived-data \
  -disableAutomaticPackageResolution -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  -resultBundlePath /tmp/wander-responsive-regression.xcresult \
  -only-testing:wanderTests/MapViewportViewTests \
  -only-testing:wanderTests/MapSocialProximityStateTests \
  -only-testing:wanderTests/MapSocialProximityControllerTests \
  -only-testing:wanderUITests/MapSocialGestureUITests test
```

La reprise utilise les mêmes options, le bundle
`/tmp/wander-responsive-recheck.xcresult` et les cinq sélecteurs suivants :

```text
wanderTests/MapSocialProximityControllerTests/testExpandedGroupFitsChangingViewportWithoutLosingSelectionOrRepeatedCentering
wanderTests/MapSocialProximityControllerTests/testRemovingFirstEventSelectedThroughItsRowKeepsTheCoincidentSecondEvent
wanderTests/MapSocialProximityControllerTests/testRemovingSecondEventSelectedThroughItsRowKeepsTheCoincidentFirstEvent
wanderUITests/MapSocialGestureUITests/testDetailScrollKeepsPaneAndHeaderInPlace
wanderUITests/MapSocialGestureUITests/testMapFillsWindowBehindNativeTabBar
```

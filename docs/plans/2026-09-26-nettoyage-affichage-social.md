---
title: "Nettoyage de l’affichage amis et événements"
status: completed
date: 2026-09-26
approved_at: 2026-09-26
started_at: 2026-09-26
completed_at: 2026-09-26
owner: Samuel
tags: [plan, refactor, mapkit, social]
---

# Nettoyage de l’affichage amis et événements

## Approbation et résultat attendu

Plan proposé dans la conversation, approuvé explicitement par Samuel avec
« je valide ». Ce sprint retire les anciennes présentations inutilisées,
réduit les doublons et évite la reconstruction des avatars lors des mouvements
de carte. L’apparence et les interactions actuelles sont conservées.

## Périmètre et exclusions

- Retirer le détail supérieur de MapDetailSplitView, ses états et gestes,
  MapDetailPanel et MapDetailFittingText sans appelant de production.
- Retirer les bulles MapKit désactivées et leurs callbacks. Conserver les
  marqueurs, la présence, les profils natifs et leur géocodage partagé.
- Mutualiser les boutons des lignes amis, le formatage des durées et la
  préparation des participants/refus. Supprimer compactStatus et le paramètre
  selectedEventID toujours nil dans le service de participation.
- Réutiliser les vues des avatars d’événement lorsque leur contenu ne change
  pas, tout en actualisant la position et les autres propriétés visuelles.
- Notifications explicitement exclues par Samuel. Aucune refonte des listeners,
  règles ou données Firebase, ni modification du clustering ou des politiques
  de fraîcheur. Aucun Git mutant, commit, PR ou déploiement.

## Dépendances et fichiers concernés

Le point de départ est le working tree existant, y compris les cartes autonomes
du 26 septembre. Les modifications locales antérieures sont conservées. Le plan
ne dépend pas de la clôture de l’ancien sprint global d’architecture.

- `wander/MapDetailSplitView.swift`
- `wander/MapDetailFittingText.swift` à supprimer
- `wander/MapWithFogView.swift`
- `wander/MapOffscreenIndicatorView.swift`
- `wander/ContentView.swift`
- `wander/FriendsPanelView.swift`
- `wander/MapEventsPanelView.swift`
- `wander/OutingAttendanceService.swift`
- `wander/DebugSocialMapScenario.swift`
- `wander/FriendPresenceFormatting.swift` à créer
- `wanderTests/MapEventListPresentationTests.swift`
- `wanderTests/OutingCategoryBadgeViewTests.swift` à créer
- `wanderUITests/MapSocialGestureUITests.swift` si ses assertions de présence
  d’un ancien détail doivent être adaptées
- Ce plan et `todos/020-ready-p2-refactor-codebase.md`
- Coffre existant `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Backlog features.md` et `Documentation technique.md`. Mettre à jour `updated`
  et préserver les wikilinks ; aucune ouverture d’Obsidian. En cas d’accès
  impossible, consigner précisément les sections restantes sans copie de coffre.

## Checklist

- [x] Retirer les anciennes bulles MapKit et leur branchement.
- [x] Retirer le détail supérieur et le moteur de texte obsolète.
- [x] Réduire les doublons et paramètres inutilisés.
- [x] Réutiliser les avatars identiques et ajouter la couverture ciblée.
- [x] Passer la simplification et corriger les constats utiles.
- [x] Compiler l’app et les tests, vérifier les références et le diff.
- [x] Terminer la revue et mettre à jour la documentation.

## Risques et protections

Préserver la taille native et l’identité de la carte pendant les animations,
les insets, les listes maintenues montées et leur scroll, ainsi que les hauteurs
indépendantes des panneaux amis/événements. Garder les revalidations de position,
de confidentialité et de participation. La réutilisation des avatars doit
prendre en compte leur ordre, leur nombre et la transition vers une liste vide.

## Validation et critères d’acceptation

L’exécution sur simulateur reste suspendue, conformément au plan approuvé.
Aucun lancement, installation, capture ou test exécuté sur simulateur.

- Recherche des références restantes aux composants retirés.
- Tests existants de présentation conservés ; retirer seulement les assertions
  propres aux composants supprimés. Test ciblé des avatars via la vraie vue
  UIKit : stabilité sur données identiques, renouvellement sur changement,
  compteur et suppression des avatars devenus absents.
- Compilation : `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build-for-testing`.
- `git diff --check` et revue de simplification/correction.
- Aucun résultat d’interaction, de performance mesurée ou de test exécuté ne
  sera revendiqué sur la seule base de compilation.
- Acceptation : les quatre nettoyages sont présents, les sources et tests
  compilent, aucun défaut actionnable introduit ne reste après revue, les
  documents concernés sont à jour ou leur impossibilité est explicitée.

## Exécution et preuves

Les instructions du dépôt et l’approbation du working tree existant priment
sur les automatismes de skills : exécution native locale, aucune création de
branche ou commit, progression suivie dans ce plan. Les modifications partagent
plusieurs fichiers ; implémentation séquentielle, revues indépendantes ensuite.
Les tests seront écrits/adaptés et compilés sans preuve rouge/verte, puisque
leur exécution est suspendue.

Copie de référence des sources avant modification :
`/private/tmp/wander-social-cleanup-7tb5096_`.

Implémentation effectuée dans le contexte principal : la tentative de création
d’un worker n’a pas démarré, la limite de conversations d’agents étant atteinte.
Aucune écriture n’a été déléguée. Le retrait des bulles réduit leur modèle aux
données réellement utilisées par les repères, nommé `MapUserPresenceInfo`.
Le cache d’adresse `MapProfileAddress` reste utilisé par les profils natifs.
Les assertions UI d’absence de l’ancien panneau restent pertinentes et sont
conservées sans modification de `MapSocialGestureUITests.swift` pour ce sprint.

`ce-simplify-code` : trois lectures séparées, réutilisation, qualité et
efficacité, sur le delta du miroir initial. Aucun constat de réutilisation ou
d’efficacité ; suppression de `MapUserCoordinate.distance(to:)`, devenu sans
appelant après le retrait du géocodage des bulles. Trois commentaires devenus
orphelins retirés. Les modèles des agents existants sont conservés : la limite
de conversations empêche d’en créer de nouveaux et la reprise ne propose pas
d’override. Aucun gain de fluidité mesuré n’est revendiqué.

Parsing des onze sources/tests concernés réussi avec `xcrun swiftc -frontend
-parse`. Première compilation arrêtée par les droits du sandbox sur les caches
Xcode/SwiftPM ; relance avec accès aux caches existants, sans nouveau runtime.

Compilation finale : `TEST BUILD SUCCEEDED`, code 0. Journal :
`/private/tmp/wander-social-cleanup-build.log`. Les trois nouveaux tests UIKit
sont compilés pour arm64 et x86_64, sans exécution. Aucun diagnostic Swift ;
les avertissements AppIntents et les versions différentes des extensions
préexistent au nettoyage (projet Xcode identique au miroir initial).

Les recherches ne trouvent plus de références aux composants supprimés dans
les sources et tests ; `git diff --check` réussit. `NotificationService.swift`
et le fichier de tests UI sont identiques au miroir initial. Le delta du
nettoyage représente 1 184 lignes nettes retirées, tests compris.

Trois relectures locales groupées (correction et cycle de vie iOS ; adversarial
et tests ; conventions, maintenabilité, performances et solutions existantes)
ne relèvent aucun défaut actionnable. Les agents existants ont été repris,
pas de nouvelles lectures par modèle indépendant ni de fournisseur externe.
Artefacts : `/private/tmp/compound-engineering-501/ce-code-review/20260926-social-cleanup-x6yqnu9h`.

Les notes Obsidian `Backlog features.md` et `Documentation technique.md` sont
mises à jour, propriété `updated` comprise, et leurs wikilinks conservés.
Le todo 020 documente cet incrément tout en restant ouvert. Aucune nouvelle
leçon réutilisable distincte des solutions existantes ne justifie une nouvelle
note dans `docs/solutions/`.

---
title: Bouton événements à droite de la navigation
status: completed
approved_at: 2026-09-21
completed_at: 2026-09-21
---

# Résultat et périmètre approuvés

Samuel a validé le remplacement du rail de badges par un bouton calendrier
séparé, à droite de la barre native inférieure. Il ouvre la liste des événements
sous la carte et un second appui la ferme. La poignée conserve le réglage de
hauteur et le repli. Aucun composant d'événements ne reste au-dessus de la barre
quand la liste est fermée.

Le bouton retrouve Explorer depuis Amis/Profil et remplace une fiche d'ami par
la liste. Les confirmations de compte continuent de protéger la navigation.
Les actions, les états vide/chargement/erreur, le défilement conservé et la carte
MapKit stable restent disponibles. Les observations de groupes suivent la liste
uniquement quand elle est ouverte et active.

## Fichiers affectés

- `wander/NativeMapTabView.swift`, `wander/MotionDockView.swift`.
- `wander/ContentView.swift`, `wander/DebugSocialMapScenario.swift`.
- `wander/MapDetailSplitView.swift`, `wander/MapEventsPanelView.swift`.
- Suppression de `wander/MapEventBadgeView.swift`.
- `wanderUITests/MapSocialGestureUITests.swift`, `wanderUITests/MotionDockUITests.swift`.
- Ce plan et `todos/059-ready-p2-valider-carrousel-evenements.md`.
- Vault existant `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Backlog features.md`, `Documentation UX.md`, `Documentation technique.md`,
  `00 - Wander.md`, avec actualisation de `updated`.

## Mise en œuvre

- [x] Ajouter le bouton natif à droite des onglets et relier son état/action.
- [x] Retirer les badges et les marges réservées au rail ; conserver la liste.
- [x] Adapter le scénario et les tests fonctionnels aux ouvertures par bouton.
- [x] Simplifier, compiler et effectuer la revue.
- [x] Actualiser le suivi et les quatre notes Obsidian.

## Risques et validation

Le groupe barre/bouton doit tenir dans la largeur disponible, suivre le clavier
et laisser les gestes de carte hors des contrôles. Vérifier la cohérence du
bouton avec les panneaux de navigation, la fiche d'ami et la poignée. Ne pas
réinitialiser le rendu natif de la carte à l'ouverture/fermeture.

Validation autorisée : compilation Debug de l'app et de ses cibles de tests
avec `build-for-testing`, puis revue du diff. Samuel maintient « compiler
seulement » : aucun simulateur lancé, test exécuté, capture ou test dédié
d'accessibilité. Le rendu et les gestes restent une limite explicite de validation.

## Exécution

Continuation sur le checkout courant avec les changements locaux de cette même
demande. Aucun Git mutant, commit ou publication. Moteur natif, modifications
liées exécutées dans le même checkout. Les tests existants sont adaptés ; pas de
preuve rouge exécutée puisque Samuel interdit l'exécution des tests pour ce travail.

## Validation

- Compilation app Debug : `BUILD SUCCEEDED`, code 0,
  `/tmp/wander-events-button-build.log`.
- `git diff --check` : succès.
- Simplification `ce-simplify-code` : réemploi, qualité et efficacité relus.
  Quatre simplifications de qualité appliquées : arguments obligatoires du
  bouton, fabrique unique des événements du scénario, noms des cellules visibles
  et de la hauteur minimale du panneau. Aucun changement de comportement.
  Deux propositions de cache/horloge non appliquées, sans coût mesuré qui justifie
  un nouveau cycle de cache. La liste reste volontairement montée.
- Les quatre notes Obsidian ont été actualisées dans le vault existant, avec
  leur propriété `updated` et leurs wikilinks conservés. Obsidian n'a pas été ouvert.
- Compilation finale app et tests : `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build-for-testing`.
  Résultat `TEST BUILD SUCCEEDED`, code 0 ; journal
  `/tmp/wander-events-button-build-for-testing.log`.
- Avertissements hérités uniquement : métadonnées AppIntents sans framework,
  versions des extensions 15/27 contre 42 pour l'app, déjà suivies dans 054.
- Validation d'exécution `PARTIAL` : compilation `PASS`, bouton/liste/poignée/
  clavier/paysage `SKIP` à la demande de Samuel. Aucun simulateur ni test lancé.
- Revue `ce-code-review` complète, huit lectures : correction, Swift/UIKit,
  adversarial local, tests, standards, maintenabilité, performances et connaissances.
  Aucun constat retenu après synthèse. Les observations propres aux événements
  sélectionnés/rejoints/organisés restent attendues ; le guard des confirmations
  de compte est présent avant toute mutation et sa vérification sur appareil
  reste dans 059, sans ajout de faux scénario.
  Dossier : `/tmp/compound-engineering-501/ce-code-review/20260920-181953-bbbb245f/`.
- Aucun changement Git mutant, commit ou publication.

## Connaissances réemployées

La carte garde son emplacement et ses bounds de rendu natifs. La liste reste
montée lorsque le panneau est fermé, et le conteneur natif transmet séparément
les réserves du contenu. Ces règles sont déjà documentées dans les solutions
sur le rendu MapKit et les zones sûres ; aucune nouvelle leçon vérifiée en
exécution ne justifie une fiche supplémentaire.

## Correction d'alignement du 21 septembre

Samuel signale sur sa capture que le calendrier est plus bas que la capsule
des onglets. La correction reprend le placement déjà approuvé, sans modifier
la navigation ni le comportement des événements. L'approbation du 20 septembre
reste applicable à ce correctif du même périmètre.

Le calcul borne le diamètre du bouton à 54 points mais utilise le milieu de
toute la zone UIKit, incluant l'espace inférieur de la barre flottante. Cela
ajoute `(controlsFrame.height - side) / 2` à sa position supérieure. La capture
montre le décalage ; aucune reproduction locale n'est exécutée.

Plan de correction : ancrer le bouton au bord supérieur converti de la barre,
conserver son diamètre et sa position horizontale, puis renforcer les assertions
existantes qui acceptaient son centre n'importe où dans la hauteur d'un onglet.
Vérifier désormais les centres à deux points près en portrait, paysage et avec
le clavier. Fichiers concernés : `wander/NativeMapTabView.swift`,
`wanderUITests/MotionDockUITests.swift`, ce plan, le suivi 059, ainsi que les
notes Obsidian déjà approuvées `Documentation UX.md` et
`Documentation technique.md`, avec leur propriété `updated`.

- [x] Corriger le calcul et renforcer les tests existants.
- [x] Compiler l'app et les tests, puis relire le diff limité au correctif.
- [x] Actualiser les deux notes et le suivi de validation.

Risque restant : la géométrie native Liquid Glass peut varier selon l'orientation
et le clavier. La compilation seule ne valide pas l'alignement visuel ; les
assertions sont compilées, sans lancement de simulateur ni exécution de tests.
Pré-correctif : HEAD `3e0cee4c3224a89a969bdf296ae5deca23b9adfe`, checkout avec
les huit fichiers Swift modifiés et les quatre documents non suivis de cette
même demande. Aucun Git mutant. Pas de changement de backlog ou de vision.

### Résultat du correctif

- Une seule expression de position modifiée, `controlsFrame.minY` ; taille,
  abscisse, callbacks, transformation et sélection conservés.
- Les assertions existantes comparent le centre du bouton à celui de l'onglet
  Profil avec une tolérance de deux points, y compris clavier et paysage.
  Elles sont seulement compilées ; aucune preuve rouge/verte exécutée.
- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug
  -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution
  build-for-testing` : **TEST BUILD SUCCEEDED**, code 0. Journal
  `/tmp/wander-events-alignment-build-for-testing.log`. Seul avertissement :
  extraction des métadonnées AppIntents ignorée faute de framework, préexistant.
- `git diff --check` : succès. Relecture manuelle du diff de correction comparé
  aux copies pré-correctif, et non de tout le travail local antérieur.
  Simplification/revue dédiées non relancées pour ce réglage mécanique de moins
  de dix lignes, conformément à `ce-debug/references/post-fix-handoff.md`.
  Aucun autre défaut retenu ; le constat visuel reste à revérifier dans 059.
- Notes UX et technique actualisées avec `updated` au 21 septembre et wikilinks
  conservés. Pas de rendu Obsidian, simulateur, test, commit ou publication.
- Confiance : compilation confirmée, correction visuelle non encore vérifiée.
  Pas de nouvelle solution enregistrée comme validée en exécution.

## Ajustement des espacements du 21 septembre

La nouvelle capture de Samuel confirme que l'alignement vertical lui paraît
correct. Il demande de remonter légèrement le recentrage et de rapprocher le
calendrier de la barre. Le plan suivant a été présenté puis explicitement
approuvé avec « je valide » avant modification.

- Recentrage : passer sa marge inférieure de 8 à 20 points, soit 12 points
  plus haut dans la même zone sûre.
- Calendrier : retirer les 8 points ajoutés après le bord droit converti de
  la barre. Conserver son diamètre et son alignement vertical.
- Adapter le test existant pour accepter des cadres adjacents sans chevauchement.
- Compiler l'app et les tests uniquement ; aucune exécution ni simulateur.

Fichiers affectés : `wander/ContentView.swift`, `wander/NativeMapTabView.swift`,
`wanderUITests/MotionDockUITests.swift`, ce plan,
`todos/059-ready-p2-valider-carrousel-evenements.md` et la note existante
`/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`.
Actualiser le champ `updated` de cette note et préserver ses wikilinks.
Le comportement du recentrage et des événements reste identique.

- [x] Appliquer les deux espacements et adapter l'assertion existante.
- [x] Compiler les cibles app/tests et relire les trois lignes modifiées.
- [x] Actualiser la note UX et le suivi 059.

Risque et validation : le placement avec clavier et en vue partagée reste à
confirmer visuellement sur appareil. La capture confirme seulement le précédent
alignement en portrait ; elle ne valide pas encore ces nouveaux espacements.

### Validation des espacements

- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug
  -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution
  build-for-testing` : **TEST BUILD SUCCEEDED**, code 0. Journal
  `/tmp/wander-map-controls-spacing-build-for-testing.log`.
- Uniquement les avertissements AppIntents préexistants : extraction des
  métadonnées ignorée faute de dépendance au framework. Aucun nouvel avertissement.
- Revue manuelle limitée au diff de cet ajustement : deux valeurs de layout et
  une assertion adaptée. Les tailles, l'alignement vertical, les zones sûres et
  les actions restent identiques. Aucun autre changement requis ; aucune nouvelle
  abstraction ou leçon réutilisable à documenter pour ces trois lignes.
- `git diff --check` réussi. Note UX actualisée avec son champ `updated` et
  wikilinks préservés. Le suivi 059 distingue le retour positif sur le précédent
  alignement et les nouveaux espacements encore à confirmer.
- Aucun simulateur lancé, aucun test exécuté, aucune opération Git mutante.

## Seuil de fermeture à 10 %, approuvé le 21 septembre

Samuel approuve explicitement le passage de 20 % à 10 %, en conservant le
plafond de 120 points. La fermeture se produit au relâchement de la poignée
si la hauteur utile du panneau est strictement inférieure à
`min(120, availableHeight * 0.1)`. Ce réglage demande de descendre davantage
avant de fermer. La vitesse du geste n'intervient pas.

Fichiers : `wander/MapDetailSplitView.swift`, ce plan, le suivi
`todos/059-ready-p2-valider-carrousel-evenements.md` et la note Obsidian
`/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`.

- [x] Modifier uniquement le coefficient du seuil.
- [x] Actualiser la note UX et le suivi 059.
- [x] Compiler et relire le changement, sans exécuter de tests ni de simulateur.

Le ressenti sur appareil reste à confirmer. Pas de nouveau test dédié pour ce
réglage d'une constante ; les parcours existants de la poignée restent disponibles.

Validation : compilation Debug iOS Simulator générique avec
`xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug
-destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build` :
**BUILD SUCCEEDED**, code 0. Journal `/tmp/wander-events-dismiss-threshold-build.log`.
Relecture ciblée : seul `0.2` devient `0.1`, comparaison stricte et plafond
conservés. `git diff --check` réussi. Avertissements préexistants uniquement :
métadonnées AppIntents sans framework et versions des extensions 15/27 contre 42,
déjà suivies dans 054. Note UX et `updated` actualisés, wikilinks conservés.
Aucun test ni simulateur exécuté ; aucun changement Git mutant. Le ressenti
reste suivi dans 059, sans prétendre à une validation gestuelle.

## Retour haptique au seuil, approuvé le 21 septembre

Samuel approuve un impact haptique léger au franchissement du seuil de fermeture,
une seule fois par glissement. Réutiliser le générateur UIKit léger déjà employé
par le zoom de carte. Le seuil reste `min(120, availableHeight * 0.1)` et la
fermeture se produit toujours au relâchement. Réinitialiser le verrou haptique
en fin ou annulation de geste, sans impact lors d'une ouverture ou d'un appui.

Fichiers approuvés : `wander/MapDetailSplitView.swift`, ce plan,
`todos/059-ready-p2-valider-carrousel-evenements.md` et la note Obsidian existante
`/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`.

- [x] Ajouter le retour léger et empêcher les répétitions pendant un glissement.
- [x] Compiler et relire le franchissement, la fin et l'annulation du geste.
- [x] Mettre à jour la note UX et le suivi 059.

Risques : vibrations répétées près du seuil ou verrou conservé au prochain geste.
Validation autorisée : compilation seule et relecture ; aucun simulateur ni test
exécuté. Le ressenti réel de l'impact reste à confirmer sur iPhone.

Validation : même commande de compilation Debug iOS Simulator générique que
pour le seuil, **BUILD SUCCEEDED**, code 0 ; journal
`/tmp/wander-events-closing-haptic-build.log`. Seul avertissement préexistant :
métadonnées AppIntents ignorées faute de dépendance au framework.
Relecture ciblée du diff : le verrou est activé avant l'impact, conservé si la
poignée remonte pendant le geste, puis remis à zéro en fin ou annulation.
Le seuil est partagé entre la détection haptique et la fermeture pour éviter
leur divergence. Le retour n'est émis que dans le glissement valide de la
poignée des événements. Pas de fermeture anticipée ni d'impact sur un appui.
`git diff --check` réussi. Note UX actualisée avec `updated` et wikilinks
préservés ; ressenti suivi dans 059. Aucun test, simulateur ou Git mutant.

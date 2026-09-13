---
title: Agenda social compact
status: completed
date: 2026-09-11
approved_at: 2026-09-11
completed_at: 2026-09-11
owner: Samuel
---

# Agenda social compact

Plan présenté puis validé dans la conversation. Les skills de design consultés
orientent la hiérarchie ; l’implémentation conserve les composants natifs iOS.
Le workflow Compound Engineering est suivi manuellement, les skills CE étant absents.

## Résultat et périmètre

Trois lignes par événement : activité avec emoji et heure ; lieu avec 📍,
distance disponible et date ; organisateur, avatars et état court. Cible indicative
80–90 points à la taille standard. Lieu tronqué sur une ligne, complet dans la fiche.
Les surlignages narratifs quittent la liste. Aucun titre, filtre ou groupe par jour.
Le divider, ses gestes et positions sont conservés sans modification de son fichier.

Le toucher ouvre la fiche existante et situe l’événement. Un balayage natif permet
de participer/refuser, ou de modifier ses événements. Aucun balayage complet ne
déclenche une réponse. Les actions inconnues ou en cours restent indisponibles.
La liste garde ses observations de groupes et son défilement au retour.

## Fichiers concernés

- `wander/MapEventsPanelView.swift` : disposition, états, avatars et actions natives.
- `wander/ContentView.swift` : branchement sur les opérations existantes.
- `wander/DebugSocialMapScenario.swift` : scénario local des actions.
- `wanderTests/MapEventListPresentationTests.swift`,
  `wanderUITests/MapSocialGestureUITests.swift` : adaptation et vérification.
- Ce plan, les constats pertinents dans `todos/` et solution réutilisable si nécessaire.
- Vault `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Backlog features.md`, `Documentation UX.md`, `Documentation technique.md`, `00 - Wander.md`.
  Propriété `updated` actualisée et wikilinks conservés.

## Étapes et critères d’acceptation

- [x] Enregistrer l’accord.
- [x] Remplacer les paragraphes par trois lignes natives compactes.
- [x] Relier les actions de balayage aux réponses et à l’édition existantes.
- [x] Vérifier les noms longs, zéro/une/plusieurs personnes, états et actions directes.
- [x] Vérifier la densité, le défilement, le retour et le divider sur l’iPhone 17 existant.
- [x] Relire, documenter les résultats et actualiser les quatre notes Obsidian.

## Risques et validation

Préserver la bonne cible d’événement lors d’un balayage, empêcher les réponses
pendant chargement/envoi et garder les états du groupe distincts de zéro inscrit.
Vérifier que la date, l’état et les avatars ne sont pas comprimés par un nom long.
Les distances restent à vol d’oiseau et expirent selon les contrôles existants.
Build Debug, tests unitaires pertinents, tests UI et captures stabilisées à taille
standard. Aucun test dédié d’accessibilité ; support natif conservé.
Pas de changement du schéma, des règles, des services Firebase ni du runtime.
Les échanges authentifiés restent suivis dans 047 ; la police emoji du simulateur
dans 048. Aucun Git mutant. Les modifications préexistantes sont conservées.

## Résultats et revue

Trois HStack SwiftUI remplacent le texte ajusté de la liste. Les avatars utilisent
`ProfileAvatarView` ; la réponse et la date gardent leur place, le lieu et le nom
de l’organisateur peuvent être tronqués. Le résumé natif conserve les informations
complètes. Les fonds surlignés et le rendu TextKit ne sont plus utilisés par la liste.
Le composant de texte partagé et les fiches restent inchangés.

Les actions natives ont `allowsFullSwipe: false`. Les callbacks portent l’identifiant
de la ligne, puis `ContentView` retrouve l’événement courant pour l’édition ou passe
par les contrôles existants de réponse. Une réponse exige un invité, un état connu
et aucune mise à jour en cours. Le scénario local suit exactement les mêmes callbacks.

La première commande de validation a échoué pendant la reconstitution du cache
SwiftPM : `Package.swift` de Firebase avait changé pendant sa lecture. Aucune
compilation applicative ni aucun test n’avaient alors démarré. La reprise compile
correctement. Le premier passage a détecté une ligne de 102,33 points ; les marges
natives de cellule ont été fixées à 8 points en haut et en bas. Le contrôle de
densité passe ensuite dans l’intervalle 70–94 points et la capture confirme les
trois lignes compactes. Les dates affichent bien « 11 sept. » même sur un appareil
configuré en anglais.

La somme SHA du fichier `MapDetailSplitView.swift` correspond à celle enregistrée
avant les modifications. `git diff --check` passe. Les quatre notes Obsidian du
périmètre sont mises à jour ; le constat 047 inclut les réponses par balayage avec
un compte authentifié. Aucun changement de service, schéma ou règle Firebase.

### Validation exacte

Sur l’iPhone 17 déjà démarré `6F13855D-10B8-45AF-9205-17C8393379E3`, Debug :

- 11 tests `MapEventListPresentationTests` réussis dans
  `/tmp/wander-compact-agenda-validation.xcresult`.
- Cinq parcours UI réussis dans ce même résultat : réponses inconnues/en cours,
  lieux longs/localisation absente ou périmée, groupes 0/1/3/5 et états inconnus,
  observations au défilement/suspension hors Explorer, redimensionnement/retour.
  Le test de densité avait échoué avant correction des marges.
- Après correction, deux tests UI réussis dans
  `/tmp/wander-compact-agenda-density.xcresult` :
  `testCompactListDensityAndDirectSwipeActions` et
  `testEventListResizeScrollAndReturnPreservePosition`.
  Participer/refuser cible la bonne ligne sans ouvrir la fiche ni déplacer le
  divider ; Modifier ouvre le formulaire de son événement.
- Bilan : 11 tests unitaires et 6 parcours UI distincts réussis, dont le parcours
  de redimensionnement rejoué après correction. Dernière commande : `TEST SUCCEEDED`.
- Captures finales exportées et inspectées dans
  `/tmp/wander-compact-agenda-density-screens/` ; capture principale
  `F9DE2663-55A1-4897-9BAC-92A47195277C.png`.
- Avertissements préexistants : extraction AppIntents et versions des extensions
  15/27 différentes de celle de l’app 41. Aucun nouvel avertissement Swift observé.

La police emoji absente du simulateur produit encore des glyphes de remplacement
et un espacement incorrect, déjà suivi dans 048. Les caractères demandés restent
dans les textes. Aucun runtime ni aucune police n’a été modifié. Les échanges
distants authentifiés restent la limite de validation 047, sans défaut observé.

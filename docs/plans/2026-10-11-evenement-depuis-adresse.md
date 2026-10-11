---
title: Créer un événement depuis une adresse enregistrée
date: 2026-10-11
status: completed
completed_at: 2026-10-11
approved_at: 2026-10-11
---

# Résultat attendu

Depuis la fiche d'une adresse de la carte, ouvrir le formulaire existant avec
le nom, l'adresse, les coordonnées et une catégorie présélectionnée lorsque
le code Naver est reconnu. CAFE correspond à Café, DINING à Repas. La catégorie
reste modifiable ; les autres codes et les valeurs absentes demandent un choix.
Samuel a approuvé le plan et cet ajout dans le chat le 11 octobre 2026.

## Périmètre et fichiers

- `wander/SavedPlaceDetailView.swift` : bouton natif de création.
- `wander/ContentView.swift` : transition après fermeture de la fiche et remise à zéro.
- `wander/OutingPlanComposerView.swift` : valeurs initiales du lieu, sans géocodage de remplacement.
- `wander/SavedPlace.swift` : correspondance de catégorie, sans donnée persistée supplémentaire.
- `wander/DebugSocialMapScenario.swift` : parcours et publication locale de test.
- `wanderTests/SavedPlaceTests.swift` : catégories reconnues, inconnues et absentes.
- `wanderUITests/NaverImportUITests.swift` : ouverture, préremplissage, fermeture, nouvelle création et publication.
- Ce plan ; `todos/` si la revue révèle un défaut restant.
- Notes du vault `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/` :
  `Backlog features.md` — import de favoris Naver ; `Documentation UX.md` — fiche
  d'adresse et création d'événement ; `Documentation technique.md` — transmission
  du lieu au formulaire et validation. Mettre à jour leur propriété `updated`.

## Hors périmètre et dépendances

Réutiliser les contrôles natifs, le formulaire et la publication existants.
Aucune nouvelle dépendance, migration ou modification Firebase.
Ne pas modifier l'état Git. Aucun test d'accessibilité dédié.

## Checklist

- [x] Ajouter une preuve UI du comportement manquant.
- [x] Ajouter la correspondance de catégorie et ses tests.
- [x] Relier fiche, fermeture puis formulaire prérempli.
- [x] Adapter le scénario de publication locale et les tests UI.
- [x] Simplifier et compiler ; exécuter les tests ciblés.
- [x] Vérifier les points d'entrée existants et effectuer la revue.
- [x] Mettre à jour les trois notes Obsidian et consigner les résultats.

## Risques et validation

Éviter deux feuilles présentées simultanément, les informations écrasées par
le géocodage et un ancien lieu réutilisé après fermeture. Conserver les avertissements
Naver. Contrôler la propriété du lieu avant l'ouverture en production.

Compiler le schéma wander et tester sur l'iPhone 17 Pro déjà lancé,
`C0DADF07-7E14-4D5E-AE4B-B17844A9C454`. Vérifier le nom, l'adresse, la catégorie,
la fermeture sans publication puis la réouverture et la publication locale.
Vérifier la création par + et appui long ainsi que la modification d'événement.
Le scénario local ne prouve pas les échanges réels avec Firebase.

## Critères d'acceptation

Le bouton ouvre le formulaire prérempli après fermeture de la fiche. Une catégorie
connue est présélectionnée et modifiable, sinon le choix reste requis. Fermer
le formulaire ne crée rien. Publier utilise les informations de l'adresse.
Les validations exactes et toute limitation documentaire sont enregistrées ici.

## Suivi d'implémentation et revue

- Exécution native dans le checkout existant, sans commande Git modificatrice.
- Preuve initiale : le test UI échoue sur `saved-place-create-event` absent,
  dans `/tmp/wander-saved-place-red.log`, avant modification du code produit.
- Les cinq tests `SavedPlaceTests` passent dans `/tmp/wander-saved-place-green.log`.
- Deux assertions UI ont ensuite été corrigées après inspection vidéo et de
  la hiérarchie : `LabeledContent` expose plusieurs textes préfixés par « Lieu » ;
  le Picker expose la sélection comme texte enfant, pas comme `value`.
  Ces échecs ne traduisaient pas une perte des données affichées.
- Revue de simplification `ce-simplify-code` : trois lecteurs, aucun changement
  nécessaire. Partager la constante de hauteur avec le scénario Debug a été
  écarté : ce seul doublon ne justifie pas d'élargir la visibilité du type privé.
- La revue a identifié les limites de publication existantes, 120 caractères
  pour le nom et 200 pour l'adresse. Les textes importés sont nettoyés et bornés
  dès le préremplissage ; la fiche conserve les originaux. Le scénario local
  utilise maintenant `OutingPlan.validatedDraft`, comme la publication réelle.
  Un test vérifie ces limites avec une catégorie inconnue et un choix manuel.
- XcodeBuildMCP absent : validation équivalente par `xcodebuild` et `simctl`.
  La collecte verbose automatique des tests échoués a été arrêtée sur les deux
  seuls processus créés par cette tâche, puis désactivée pour la passe finale.
  Les logs, vidéos et hiérarchies utiles ont été conservés.


## Validation finale

Compilation Debug de l'app et des tests réussie sur l'iPhone 17 Pro existant,
iOS 26.3, avec le SDK iOS 27. Aucun diagnostic Swift. Les messages Xcode
`Metadata extraction skipped, no AppIntents.framework dependency found` et
`debugger version lookup failed` proviennent des outils et étaient également
présents dans la passe initiale avant modification du code produit.

Dix tests distincts ont un dernier résultat réussi : cinq `SavedPlaceTests`,
les trois parcours `NaverImportUITests` ci-dessous, et les deux parcours
`MapSocialGestureUITests` ci-dessous. La première passe finale contient huit
succès et deux échecs de recherche de contrôles hors écran. Le retest des deux
cas, avec défilement natif de la fiche, réussit. Aucun échec résiduel.

Commandes exactes depuis la racine du dépôt :

```bash
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'platform=iOS Simulator,id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' -only-testing:wanderTests/SavedPlaceTests -only-testing:wanderUITests/NaverImportUITests/testCreateEventFromSavedAddressPrefillsPlaceAndCategory -only-testing:wanderUITests/NaverImportUITests/testUnknownCategoryRequiresChoiceAndLongPlaceCanPublish -only-testing:wanderUITests/NaverImportUITests/testSingleFieldPreviewSaveAndReimportWithoutDuplicates -only-testing:wanderUITests/MapSocialGestureUITests/testLongPressCreatesOneDraftAndPressingItsPinDoesNotCreateAnother -only-testing:wanderUITests/MapSocialGestureUITests/testEventCardsExposeDirectGuestAndOrganizerActions -parallel-testing-enabled NO -collect-test-diagnostics never -disableAutomaticPackageResolution test
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'platform=iOS Simulator,id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' -only-testing:wanderUITests/NaverImportUITests/testSingleFieldPreviewSaveAndReimportWithoutDuplicates -only-testing:wanderUITests/NaverImportUITests/testUnknownCategoryRequiresChoiceAndLongPlaceCanPublish -parallel-testing-enabled NO -collect-test-diagnostics never -disableAutomaticPackageResolution test
```

Logs : `/tmp/wander-saved-place-final.log` et `/tmp/wander-saved-place-scroll.log`.
Résultats Xcode dans `~/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx/Logs/Test/` :
`Test-wander-2026.10.11_12-23-21-+0900.xcresult` et
`Test-wander-2026.10.11_12-27-07-+0900.xcresult`.
Capture du formulaire inspectée :
`/tmp/wander-saved-place-verified/2140E678-8BC3-4FC7-93A0-32DC8EB56AF7.png`.

Le parcours vérifie nom, adresse, coordonnées, catégorie Café, fermeture puis
réouverture, changement vers Repas et contenu de la carte de l'événement publié.
Le deuxième parcours vérifie une catégorie inconnue, Publier désactivé avant
choix, les limites 120/200 caractères et la publication après choix manuel.
Le réimport et le lien Naver restent fonctionnels ; la fiche défile nativement.

Revue `ce-code-review`, profondeur lite : aucun défaut restant. Le code modifié
est local à la présentation et à son préremplissage, sans nouveau contrat réseau.
`git diff --check` réussit. Reçu : `/tmp/wander-saved-place-review/review.json`.
Aucun finding non résolu à ajouter à `todos/`. Les trois notes Obsidian prévues
sont mises à jour dans le vault existant, sans ouverture d'Obsidian.

Limites : publication Firebase réelle et création par + dans une session
connectée non exercées. Les branchements du + et de l'appui long ont été relus ;
le test d'appui long valide le callback cartographique. Le suivi de validation
connectée du + reste dans `todos/076-ready-p2-valider-menu-creation-carte.md`.
Aucun test dédié d'accessibilité, aucun nouveau simulateur et aucune opération
Git modificatrice. Pas de lint Swift distinct configuré pour cette tâche.

`ce-compound` : Documentation skipped. Les correspondances, limites et
séquences de présentation sont explicites dans le code, les tests et ce plan ;
aucun enseignement supplémentaire ne justifie une note de solution.

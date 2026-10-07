---
title: État des boutons de participation aux événements
status: completed
date: 2026-09-28
approved_at: 2026-09-28
completed_at: 2026-09-28
---

# Résultat attendu

Plan proposé dans la conversation, réduit aux boutons à la demande de Samuel,
puis explicitement approuvé par « je valide ».

La réponse enregistrée est visible directement sur les boutons de la liste :
la coche est sélectionnée si le compte participe, la croix s'il refuse.
Sans réponse, les deux boutons restent neutres. Le choix opposé reste disponible.
Pendant l'envoi, les deux boutons sont désactivés.

## Périmètre et décisions approuvées

- Utiliser les styles natifs SwiftUI : rempli pour le choix sélectionné,
  bordé pour le choix neutre. Exposer aussi le trait natif de sélection.
- Dériver la sélection de `participationState`, sans second état local.
- Conserver les textes existants, sans ajouter de ligne de statut.
- Conserver la sauvegarde, les erreurs, le chargement, l'itinéraire,
  les actions organisateur et le tri existants.
- Aucune modification Firebase, des modèles ou de la synchronisation.

## Fichiers concernés

- `wander/MapEventsPanelView.swift` : état et style des boutons.
- `wanderUITests/MapSocialGestureUITests.swift` : renforcer les parcours de
  réponse existants avec sélection visible, changement d'avis et réouverture.
- `wanderTests/MapEventListPresentationTests.swift` : couverture existante
  des états et gardes à réutiliser ; modification uniquement si nécessaire.
- Le présent plan, tenu à jour jusqu'à la validation.
- Notes sous `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Backlog features.md`, `Documentation UX.md`, `Documentation technique.md`.
  Mettre à jour les sections événements et `updated`, conserver les wikiliens.
- `todos/` : seulement si la revue révèle des constats à consigner.

## Mise en œuvre

- [x] Présenter le plan révisé et obtenir l'approbation explicite.
- [x] Implémenter la sélection native des deux boutons.
- [x] Adapter les tests UI existants et conserver les gardes.
- [x] Simplifier puis compiler et exécuter les tests ciblés.
- [x] Inspecter les captures des états neutre, participant et refusé.
- [x] Effectuer la revue et actualiser les trois notes Obsidian.

## Risques et validation

La mise en évidence ne doit jamais annoncer une réponse non enregistrée.
Les états inconnus restent neutres et désactivés ; un envoi conserve la dernière
réponse confirmée et les gardes existantes. Vérifier la lisibilité sur une ligne
compacte et l'indépendance entre deux événements.

Compiler l'application et ses cibles de tests. Exécuter la couverture de
présentation existante et les parcours UI ciblés sur l'iPhone 17 déjà démarré,
UUID `6F13855D-10B8-45AF-9205-17C8393379E3` : sans réponse, participation,
refus, nouvelle participation, fermeture/réouverture, états indisponible/envoi,
actions organisateur et itinéraire conservés. Capturer et inspecter le rendu.
Ne pas lancer de tests dédiés d'accessibilité ou créer de simulateur.

Changement de présentation : pas de test unitaire recopiant les comparaisons
de l'interface. Renforcer les tests fonctionnels déjà en place et inspecter
les captures remplace une étape rouge pour cette modification de style.

## Contexte et contraintes

État initial propre, HEAD `c213d2b98700ebe0ce850de28e76cd259100fde3`, branche
`main`. Aucune commande Git mutante, aucun commit ni publication. Les règles
du projet priment sur les automatismes de branche et de commit des skills.
XcodeBuildMCP absent : validation CLI équivalente via Xcode et le simulateur.
Le premier accès sandboxé à CoreSimulator a échoué ; l'accès autorisé a confirmé
le simulateur déjà démarré. Aucun nouveau simulateur n'a été lancé.

## Revue et résultats

Simplification terminée : les trois revues de réutilisation, qualité et
efficacité n'ont relevé aucun changement utile. Le paramètre `isSelected`
du composant existant réunit le style rempli et le trait natif correspondant.
Les tests unitaires de présentation sont réutilisés sans modification.

## Commandes et preuves

Premier passage :

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'platform=iOS Simulator,id=6F13855D-10B8-45AF-9205-17C8393379E3' -parallel-testing-enabled NO -disableAutomaticPackageResolution -resultBundlePath /private/tmp/wander-event-buttons-tests.xcresult -only-testing:wanderTests/MapEventListPresentationTests -only-testing:wanderUITests/MapSocialGestureUITests/testGuestCardActionsRespondWithoutResizingMap -only-testing:wanderUITests/MapSocialGestureUITests/testEventCardsExposeDirectGuestAndOrganizerActions -only-testing:wanderUITests/MapSocialGestureUITests/testEventListUnknownOrUpdatingResponseDisablesResponseActions -only-testing:wanderUITests/MapSocialGestureUITests/testUnavailableAndUpdatingParticipationKeepsDirectionsAccessible test
```

- Compilation réussie. Les 10 tests de présentation et le test de maintien de
  l'itinéraire pendant chargement/indisponibilité/envoi passent.
- Trois tests UI échouent : le helper défile alternativement de ±67,4 pt pour
  inspecter le bouton du deuxième événement ; la coche est aussi exposée comme
  sélectionnée sans réponse et pendant le chargement.
- La vidéo du test sans réponse montre les deux boutons correctement neutres.
  L'échec de sélection concerne donc le trait natif, pas le style visuel.
  Image extraite inspectée : `/private/tmp/wander-event-buttons-initial-neutral.png`.
- Correction : retirer explicitement `.isSelected` sur la branche neutre,
  l'ajouter sur la branche remplie. Les nouvelles assertions lisent la carte
  réalisée sans défilement ; les taps gardent le helper de visibilité existant.
- Journal initial : `/private/tmp/wander-event-buttons-tests.log`.

Relance des trois tests concernés, sans élargir la suite :

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'platform=iOS Simulator,id=6F13855D-10B8-45AF-9205-17C8393379E3' -parallel-testing-enabled NO -disableAutomaticPackageResolution -resultBundlePath /private/tmp/wander-event-buttons-retry.xcresult -only-testing:wanderUITests/MapSocialGestureUITests/testGuestCardActionsRespondWithoutResizingMap -only-testing:wanderUITests/MapSocialGestureUITests/testEventCardsExposeDirectGuestAndOrganizerActions -only-testing:wanderUITests/MapSocialGestureUITests/testEventListUnknownOrUpdatingResponseDisablesResponseActions test
```

Résultat final : **TEST SUCCEEDED**, 3 tests UI, 0 échec, 224,069 secondes.
Les trois échecs initiaux sont remplacés par cette validation réussie.
Journal : `/private/tmp/wander-event-buttons-retry.log`.

Captures inspectées sous `/private/tmp/wander-event-buttons-evidence/` :

- `CA2BB7A4-CDE3-4ABD-B46E-3FD590AC9653.png` : deux boutons neutres sans réponse.
- `2D609C5D-2503-49CF-B342-551D03CF99ED.png` : coche remplie après participation.
- `D0A3CE7C-12A0-4045-92CB-5409433FABC6.png` : croix remplie après refus.
- La capture `D417B14A-ADF7-4578-BAC1-B4BCFEB3B892.png` conserve également
  la nouvelle participation dans les preuves du test.

Les boutons restent alignés sur une seule ligne. Le bouton non sélectionné
garde le fond neutre natif et le choix enregistré est rempli en bleu.

Les avertissements de métadonnées AppIntents sont préexistants. Les numéros de
build des extensions 15 et 27 face à l'app 49 sont déjà suivis dans
`todos/054-ready-p2-aligner-build-extensions.md`. Aucun diagnostic Swift nouveau.
La validation utilise le scénario local ; aucun nouvel échange Firebase réel.

Les trois notes Obsidian prévues ont été mises à jour dans leurs sections
événements. `updated` a été actualisé et les wikiliens sont inchangés.
Obsidian n'a pas été ouvert.

Revue de code `ce-code-review` légère terminée sans constat :
`/private/tmp/compound-engineering-501/ce-code-review/event-response-buttons-20260928/review.json`.
Critères relus : `AGENTS.md`, plan approuvé, delta final et tests fonctionnels.
Les avertissements préexistants restent rattachés au suivi existant, sans doublon.
`git diff --check` passe. Aucune commande Git mutante n'a été exécutée.

La sélection provient exclusivement de la réponse enregistrée, car un état
optimiste local pourrait diverger lors d'une erreur. L'ajout d'une ligne de
statut a été écarté à la demande de Samuel. La seule limite de validation est
l'absence de nouveaux échanges Firebase réels ; les services n'ont pas changé.

Évaluation `ce-compound` : pas de nouvelle note de solution. Les tests couvrent
explicitement le faux état sélectionné et la documentation technique décrit
le retrait du trait natif. Une note supplémentaire ferait doublon avec ces
preuves et n'apporterait pas de raisonnement durable absent des fichiers finaux.

## Bilan de validation iOS

- Projet : `wander.xcodeproj`. Scheme : `wander`.
- Simulateur : iPhone 17 déjà démarré, iOS 26.3.
- Compilation : réussie. Surface : liste des événements.
- Réponses successives et réouverture : PASS, assertions et captures.
- Indépendance des événements et actions organisateur : PASS.
- Réponses inconnues, indisponibles et envoi : PASS.
- Itinéraire pendant les états bloquants : PASS au premier passage.
- Tests de présentation : PASS, 10 tests.
- Erreurs de console attribuables au changement après correction : 0.
- Vérifications humaines demandées : 0. Échecs résiduels : 0.
- Résultat du périmètre local : PASS.

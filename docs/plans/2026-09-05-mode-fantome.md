---
title: "Mode fantôme"
status: in_progress
date: 2026-09-05
approved_at: 2026-09-05
started_at: 2026-09-05
owner: Samuel
tags: [plan, privacy, friends, location]
---

# Mode fantôme

## Outcome

Un bouton natif 👻 sur la carte et un interrupteur dans le profil suspendent le
partage de position jusqu'à désactivation. Les amis voient « 👻 Indisponible »
dans la liste et la fiche, sans position, itinéraire ou actualisation.
Samuel a approuvé le plan présenté dans la conversation par « implemente ».

## Scope and decisions

- Statut du compte dans `users/{uid}`, intention locale persistante par compte.
- Activation : bloquer les envois locaux, puis enregistrer atomiquement le
  statut et supprimer `locations/{uid}`. Confirmer uniquement après le serveur.
- Publications de l'app, de l'extension et des cellules conditionnées au statut
  distant dans une transaction. Éviter les publications concurrentes/tardives.
- Exploration locale maintenue ; nouvelles cellules synchronisées à la sortie.
  Cette pause diffère également la sauvegarde et la restauration multi-appareil.
- À la sortie : nouvelle position et nouvelle durée de présence, sans reprendre
  une mesure ou une ancienneté accumulée pendant la période invisible.
- Hors ligne : intention conservée, état en attente explicite, partage bloqué.
- Aucune modification/déploiement des règles ou Cloud Functions. Aucun Git mutateur.
- Aucun minuteur, filtre par ami, suppression de l'historique déjà partagé,
  ni changement des sorties volontairement publiées.

## Affected files

- `wander/ContentView.swift` : commandes, statut amis, cycle de localisation.
- `wander/FriendProfileSheet.swift` : disponibilité et actions.
- `wander/FriendSyncService.swift` : statut, transactions et écoute des amis.
- `wander/LocationTracker.swift` : recommencer la présence à la reprise.
- `wander/LocationPushService.swift` : éligibilité et actualisations.
- `wander/LocationPushSharedConfiguration.swift` : contrat commun app/extension.
- `WanderLocationPushExtension/LocationPushServiceExtension.swift` : publication.
- `wander/GhostModeState.swift` : état testable des transitions du compte.
- `wanderTests/GhostModeTests.swift` : transitions et contrat de publication.
- `firebase-tests/tests/ghost-mode.test.mjs` : contrat sous émulateur.
- `docs/plans/2026-09-05-mode-fantome.md` : suivi et preuves.
- `todos/` : éventuels constats priorisés ; `docs/solutions/` : apprentissage vérifié.
- Obsidian, sous `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/` :
  - `Backlog features.md` : fonctionnalité et statut.
  - `Documentation technique.md` : schéma, partage, synchronisation et tests.
  - `Documentation UX.md` : commandes, amis, confidentialité et états.
  - `00 - Wander.md` : état du produit.

## Implementation

- [x] U1. État par compte, activation atomique et publications conditionnelles.
- [x] U2. Extension et consentement partagé ; demandes d'actualisation.
- [x] U3. Interface native, statuts amis et reprise de présence.
  - Ajustement demandé après implémentation : bouton 👻 toujours circulaire,
    avec le même style `.glass`, la forme `.circle` et la taille `.large` que
    les boutons d'orientation et de recentrage. Textes d'état placés au-dessus.
- [x] U4. Tests ajoutés, simplification et revue du changement intégré ;
  vérifications exécutables réalisées, validation iOS restante détaillée ci-dessous.
- [x] U5. Documentation, constats et validation Obsidian.

## Risks and limitations

- Un ami peut conserver une position déjà reçue dans son cache ; aucune révocation
  rétroactive de ces copies n'est promise.
- Une ancienne version connectée au compte peut ignorer le statut et republier.
  La garantie porte sur les clients à jour, sans nouvelle interdiction serveur.
- Les transactions requièrent une connexion. Les erreurs ne doivent jamais
  réactiver silencieusement le partage.
- Les retours tardifs, le changement de compte et les bascules rapides doivent
  préserver la dernière intention ; un envoi antérieur à la reprise est rejeté.
- Le vault Obsidian est initialement hors racines autorisées en écriture. Les
  notes seront mises à jour si l'accès est accordé ; sinon leurs sections et
  l'absence de validation en mode lecture seront consignées sans substitut.

## Validation and acceptance criteria

- [x] Build app et extension sans nouveau diagnostic Swift.
- [ ] Tests des transitions : compte, relance, erreur, attente et bascule rapide.
- [x] Émulateur : lecture ami sans coordonnées, publications concurrentes bloquées,
  reprise avec nouvelle position, nouvelles cellules différées.
- [ ] Tests iOS sur l'iPhone 17 déjà démarré, sans démarrer un autre simulateur.
- [ ] UI : bouton, interrupteur, fiche ouverte, rail/groupes/indicateurs, itinéraire,
  accessibilité et états hors ligne.
- [ ] Deux comptes et appareils : activation pendant un envoi, actualisation APNs.
  Toute indisponibilité de ces moyens sera explicitement enregistrée.
- [x] Revue `ce-simplify-code`, validation `ce-test-xcode` adaptée aux outils
  disponibles (build), puis `ce-code-review` et corrections relues.
- [x] Notes Obsidian : `updated`, wikilinks et rendu des sections affectées vérifiés.

## Review and evidence

Plan issu d'une investigation en lecture seule et d'une revue des flux. Choix
principal : arrêter la publication des données et non seulement l'affichage.
La protection des écritures en vol nécessite des transactions sur les trois
chemins (app, extension, cellules), même si les règles restent identiques.
Références : [transactions Firebase](https://firebase.google.com/docs/firestore/manage-data/transactions)
et [cache hors ligne](https://firebase.google.com/docs/firestore/manage-data/enable-offline).

### Résultats du 5 septembre 2026

- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug
  -destination 'generic/platform=iOS Simulator' -parallel-testing-enabled NO
  -disableAutomaticPackageResolution build-for-testing` : succès sur le code
  final, app, extension et tests. Aucun nouveau diagnostic Swift. Le dernier
  journal ne contient que les avertissements AppIntents d'extraction ignorée.
  Journal : `/private/tmp/wander-ghost-build-reviewed.log`.
- `firebase-tests` : `npm run test:rules` avec le JDK 21 installé sous
  `/opt/homebrew/opt/openjdk@21` : 49 tests passés, 0 échec, dont 11 tests fantôme.
  Journal : `/private/tmp/wander-ghost-firestore-final.log`.
  Les fixtures testent le protocole et provoquent des retries réels sous
  émulateur ; elles ne remplacent pas l'exécution des publishers Swift.
- Un harness temporaire macOS compile le vrai `wander/GhostModeState.swift`
  avec `swiftc -default-isolation MainActor` et réussit 13 assertions : refus
  initial, activation, chaîne locale, persistance, conflit, idempotence,
  acquittement ancien et mémoire après acquittement dans les deux sens.
- Les 21 tests `GhostModeTests` compilent ; ils ne sont pas déclarés exécutés.
- `git diff --check` : succès. Règles Firebase, configuration serveur et projet
  Xcode inchangés. Aucune mutation Git ou déploiement.
- Ajustement circulaire demandé ensuite : nouvelle compilation
  `build-for-testing` réussie, sans diagnostic Swift ; journal
  `/private/tmp/wander-ghost-circle-build.log`. Comparaison statique des trois
  boutons : même style `.glass`, forme `.circle` et taille `.large`. Les états
  textuels sont séparés du cercle, et la note UX a été actualisée et relue.
- Simplification : trois revues (réemploi, qualité, coût) ; moins de filtrages
  inutiles, moins de mutations publiées et lecture extension retardée après
  vérification de l'éligibilité.
- Revue intégrée : trois relecteurs de session couvrent correction/fiabilité,
  sécurité/concurrence et Swift/tests/standards. Les angles groupés ne sont pas
  comptés comme des votes indépendants supplémentaires. Les correctifs ont été
  relus ; aucun nouveau défaut confirmé après correction.
- La revue externe Grok via Cursor a été refusée avant lancement par le
  contrôle automatique, faute d'autorisation de divulguer le code privé à ces
  fournisseurs. Repli sur la revue de cette session ; aucun envoi externe.
- Corrections : conflit d'intention obsolète, mémoire après acquittement,
  filtrage du cache pré-reprise, identité des listeners. Voir
  `todos/026-done-p1-proteger-reprise-mode-fantome.md`.
- Obsidian : les quatre notes prévues sont mises à jour. Délimiteurs du
  frontmatter et ancres des wikilinks affectés vérifiés ; lecture native
  « Aperçu » inspectée dans Obsidian, y compris listes, tableaux et callouts.
  Aucun bloc Mermaid ou code clôturé modifié dans ces notes.
- Apprentissage : `docs/solutions/2026-09-05-suspendre-partage-position-sans-regles.md`,
  frontmatter et références validés. La note de synchronisation personnelle a
  été ajustée pour documenter cette suspension explicite.

### Validation restant à exécuter

Aucun simulateur n'était démarré. L'iPhone 17 Pro iOS 26.3 existant
(`C0DADF07-7E14-4D5E-AE4B-B17844A9C454`) était éteint. L'autorisation de le
démarrer a été demandée conformément à `AGENTS.md` ; aucun démarrage, appareil
ou runtime supplémentaire n'a été lancé. Les parcours iOS, XCTest, VoiceOver,
hors ligne multi-compte et APNs restent ouverts dans
`todos/027-ready-p2-valider-mode-fantome-ios.md`.

Le plan reste `in_progress` sans `completed_at`. Les critères natifs ci-dessus
et les corrections issues de la seconde revue ci-dessous restent à traiter
avant de déclarer l'implémentation terminée.

### Seconde revue demandée le 5 septembre 2026

Revue sans correctif du code final, y compris le bouton circulaire et les
fichiers non suivis. Trois relecteurs de session, puis un nouveau validateur
indépendant, ont confirmé quatre défauts :

- **#1 / P1** : une transaction de publication peut recréer la position après
  l'arrêt de « Enregistrer mes déplacements ». La suppression ne change pas
  le profil lu par la transaction. Reproduction Firestore locale : position
  supprimée, transaction libérée, document recréé et lisible par un ami accepté.
  Suivi : `todos/028-ready-p1-empecher-republication-apres-arret-suivi.md`.
- **#2 / P2** : une activation fantôme annulée hors ligne avant confirmation
  peut afficher à tort que la position reste masquée.
  Suivi : `todos/029-ready-p2-corriger-statut-annulation-fantome-hors-ligne.md`.
- **#3 / P2** : l'hydratation normale d'un compte visible réinitialise la durée
  de présence restaurée, même sans bascule fantôme.
  Suivi : `todos/030-ready-p2-preserver-presence-au-lancement.md`.
- **#4 / P2** : une erreur tardive d'un upload d'une ancienne révision peut
  laisser les cellules en attente après la reprise, sans nouvelle tentative.
  Suivi : `todos/031-ready-p2-relancer-cellules-apres-ancienne-erreur.md`.

Les états #2 et #3 sont reproduits dans un harness macOS compilant le vrai
`GhostModeState`, sans validation du rendu SwiftUI ou de CoreLocation. Le
constat #4 repose sur les callbacks inspectés ; un test natif déterministe
reste nécessaire. La reproduction #1 teste le protocole sur Firestore local,
pas le service Swift en exécution. Aucun simulateur démarré.

Les empreintes des quinze fichiers examinés étaient inchangées avant les
ajouts de suivi ; `git diff --check` réussi. Les builds et 49 tests de protocole
antérieurs ne couvrent pas ces interactions et ne sont pas déclarés rejoués.
Aucun correctif, changement de règles, déploiement ou commande Git mutatrice.
La revue externe précédemment refusée n'a pas été retentée ; aucune
corroboration entre modèles n'est revendiquée.

Rapport et preuves temporaires :
`/private/tmp/wander-ghost-second-review-aoo_241p/` (`detailed-report.md`,
`review.json`, `validator.json`, reproductions et journaux).
Verdict : **Not ready**, avec #1 à corriger avant diffusion. Les quatre constats
sont enregistrés, sans correction appliquée pendant cette seconde revue.

---
title: "Accepter les alias IANA lors de la publication d'événements"
status: completed
date: 2026-10-24
owner: Samuel
approved_at: 2026-10-24
completed_at: 2026-10-24
related: ["../../todos/082-pending-p2-accepter-alias-fuseaux-iana.md"]
tags: [plan, events, timezone]
---

# Résultat attendu

Publier et modifier un événement avec `Asia/Kolkata`, et relire les événements
portant cet identifiant, sans erreur de fuseau. Conserver les identifiants déjà
acceptés et rejeter les valeurs invalides ou les formats de décalage fixe qui
ne sont pas compatibles avec les notifications serveur.

## Approbation et périmètre

Samuel a approuvé le plan présenté dans le chat par « je valide », y compris
la validation sur l'iPhone 18 Pro déjà démarré. Le plan est enregistré au statut
`approved` avant l'implémentation. La correction est un seul incrément.
Pas de migration ni de déploiement Firebase. Aucun Git mutatif : les règles du
dépôt priment sur les recommandations de branche et de commit des skills.
Les modifications préexistantes des pins restent hors périmètre ; seule la
ligne de contournement du fuseau dans NaverImportUITests est concernée.

## Cause et approche

`OutingPlanComposerView` et la Share Extension transmettent le fuseau système.
Le helper privé partagé par `validatedDraft` et `init(document:)` exige une
présence dans `TimeZone.knownTimeZoneIdentifiers`. La liste peut omettre un alias
que Foundation sait interpréter. Conserver cette liste pour les identifiants
déjà acceptés et autoriser aussi les identifiants IANA comportant `/` que
`TimeZone(identifier:)` reconnaît, ainsi que l'alias standard `UTC` explicitement
prévu dans la validation. Ne pas réécrire l'identifiant ni la date.

Firestore ne filtre pas le fuseau lors de l'écriture des événements. Les
notifications utilisent déjà `Intl.DateTimeFormat` ; vérifier les deux alias
indiens dans la suite existante, sans modifier les fonctions de production.

## Fichiers concernés

- `wander/OutingPlan.swift` : validation partagée.
- `wanderTests/OutingPlanTests.swift` : tests de non-régression du brouillon.
- `wanderUITests/NaverImportUITests.swift` : retirer `TZ=Asia/Seoul`.
- `functions/src/notificationLogic.test.ts` : compatibilité des alias indiens.
- Ce plan : checklist et preuves de validation.
- `todos/082-pending-p2-accepter-alias-fuseaux-iana.md` : résultat de revue et résolution.
- `docs/solutions/2026-10-24-accepter-alias-fuseaux-iana.md` : cause et prévention.
- Vault `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/` :
  - `Backlog features.md`, publication depuis les adresses : correction terminée après validation.
  - `Documentation technique.md`, validation des événements et tests Naver : retirer la limitation active.
  - `Documentation UX.md`, sorties prévues : publication avec le fuseau système.
  - Actualiser `updated` et préserver les wikilinks de chaque note modifiée.

## Dépendances, risques et limites

- Réutiliser Xcode, les dépendances SPM locales et le seul simulateur autorisé,
  iPhone 18 Pro `CD1E7A76-F65E-495D-A525-F328746F152F`, iOS 27.0.
- Foundation peut reconnaître des formats refusés par Intl : garder le contrôle
  de forme pour les nouveaux alias et tester `GMT+0530` comme entrée rejetée.
- Les tests UI Debug prouvent la publication locale via la validation métier,
  pas des échanges Firebase authentifiés ni la livraison de notifications.
- Le runtime Node local peut différer du Node 22 déclaré en production ;
  consigner celui utilisé. Les tests serveur n'effectuent aucun déploiement.
- Si le vault est inaccessible en écriture, consigner les sections ci-dessus
  restant à mettre à jour, sans créer de copie ailleurs.

## Implémentation et validation

- [x] Diagnostic et approbation explicite.
- [x] Ajouter les tests Swift et observer l'échec de `Asia/Kolkata` avant correction.
- [x] Corriger le helper partagé et retirer le contournement UI.
- [x] Vérifier `Asia/Kolkata`, `Asia/Calcutta`, `Asia/Seoul`, UTC et les entrées invalides.
- [x] Vérifier l'heure des notifications pour les deux alias.
- [x] Compiler l'app et les tests, puis exécuter les parcours de publication Naver.
- [x] Simplifier et relire le diff ciblé, consigner les éventuels constats prioritaires.
- [x] Mettre à jour le ticket, la solution et les trois notes Obsidian.

## Critères d'acceptation

Les deux alias passent la validation sans modification de la date ni de
l'identifiant. Les entrées invalides et les formats hors périmètre sont rejetés.
Les tests de publication passent sans remplacement du fuseau système. Les
notifications des deux alias indiquent la même heure. Aucun avertissement Swift
introduit. Les preuves et les limites sont consignées avant clôture.

## Validation et revue

HEAD initial :
`317bd6ad33510d1e435638d49c17d514777e4120`, branche `main`, arbre déjà modifié.

- Rouge : `/private/tmp/wander-timezone-red.log`, 4 tests, 2 échecs
  `invalidTimeZone` avant correction : Kolkata et le groupe contenant UTC.
  Une sonde Foundation locale confirme que `UTC` et `Etc/UTC` sont interprétables
  mais absents de la liste, comme Kolkata. Calcutta et les entrées invalides
  donnent déjà le résultat attendu.
  La collecte des diagnostics Xcode est restée bloquée après les tests ; arrêt
  du processus de cette exécution, code 143. Le bundle rouge n'est pas utilisé
  comme preuve finalisée ; le journal contient les résultats.
- Serveur : `cd functions && npm test`, Node v24.19.0, 49 tests réussis,
  5 tests d'intégration ignorés, 0 échec. Les deux alias donnent 15:30 pour
  `2026-10-24T10:00:00Z`. Log `/private/tmp/wander-timezone-functions.log`.
- XcodeBuildMCP absent : validation CLI équivalente avec xcodebuild et simctl,
  conformément au recours manuel autorisé par AGENTS.md. Aucun nouveau simulateur.
- Vert : `/private/tmp/wander-timezone-green.xcresult`, commande terminée avec
  code 0. Résumé xcresulttool : 6 tests, 6 réussis, 0 échec, 0 ignoré, aucun
  runtime warning. Quatre tests Swift et deux tests UI Naver de publication.
- Sonde Foundation sur le même simulateur :
  `current=Asia/Kolkata known=false TZ=unset`, Kolkata interprétable, Calcutta
  interprétable et présent dans la liste. Les tests UI n'imposent plus de fuseau.
- Compilation app et tests réussie. Aucun avertissement Swift nouveau.
  Les diagnostics Xcode SDK/debugger et les avertissements de version des
  extensions (`15`/`27` contre `53` pour l'app) préexistent au correctif.
- Revue ce-simplify-code : aucune modification nécessaire. Revue ce-code-review
  ciblée : aucun constat, receipt
  `/private/tmp/wander-timezone-review/ce-code-review/20261024-timezone/review.json`.
  Les modifications préexistantes des pins sont exclues de cette revue.
- Lecture Firestore : helper commun inspecté, sans test direct de DocumentSnapshot.
  Les tests UI sont synthétiques ; aucune publication Firebase authentifiée ni
  livraison réelle de notification exercée.
- Les trois notes Obsidian prévues ont été mises à jour le 24 octobre 2026 à
  21:25:52 +05:30. Leur propriété `updated` est actualisée, leurs wikilinks sont
  identiques aux originaux ; sauvegardes dans `/private/tmp/wander-timezone-obsidian-before`.
- ce-compound, capture légère non interactive : solution créée, piste bug,
  vérification mécanique des chemins et liens sans signalement, frontmatter valide.
  CONCEPTS.md inspecté, aucun terme spécifique nouveau ; aucune modification.
  AGENTS.md référence déjà docs/solutions : aucune lacune de découvrabilité.
  Documentation complete.
- `git diff --check` réussit. Aucun Git mutatif, commit, push ou déploiement.

### Commande de validation iOS

```bash
xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'platform=iOS Simulator,id=CD1E7A76-F65E-495D-A525-F328746F152F' \
  -derivedDataPath /Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx \
  -disableAutomaticPackageResolution -parallel-testing-enabled NO \
  -collect-test-diagnostics never \
  -only-testing:wanderTests/OutingPlanTests \
  -only-testing:wanderUITests/NaverImportUITests/testCreateEventFromSavedAddressPrefillsPlaceAndCategory \
  -only-testing:wanderUITests/NaverImportUITests/testUnknownCategoryRequiresChoiceAndLongPlaceCanPublish \
  -resultBundlePath /private/tmp/wander-timezone-green.xcresult test
```

### Choix de revue

- Décision principale : garder la liste pour compatibilité et étendre seulement
  aux alias nommés reconnus, avec `UTC` explicite.
- Alternative rejetée : accepter tout résultat non nil de Foundation, ce qui
  admettrait des formats non compatibles avec Intl, notamment `GMT+0530`.
- Limite : les bases Foundation et Intl peuvent différer entre versions ; les
  tests couvrent les alias indiens et UTC, sans prétendre à une concordance exhaustive.

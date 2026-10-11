---
title: Importer une liste de favoris Naver
date: 2026-10-10
status: completed
approved_at: 2026-10-10
completed_at: 2026-10-10T13:18:30+09:00
---

# Résultat et approbation

Samuel a approuvé le plan dans le chat avec « je valide », après avoir demandé
une UX inspirée de sa capture, le logo Naver et un seul champ.
Depuis le +, « Importer adresse Naver » ouvre une feuille native : logo, titre,
champ avec Coller, bouton Importer la liste. Une prévisualisation permet de
confirmer les lieux et leurs avertissements avant l'enregistrement.
Les favoris restent privés sur cet appareil, apparaissent sur la carte et
ouvrent une fiche avec nom, adresse et lien Naver. Un réimport ne crée pas de
doublons. Aucun événement n'est créé.

## Périmètre et décisions

- Une liste par import, lien court ou texte partagé Naver accepté.
- Police système, contrôles iOS natifs, fond système, pas de dégradé décoratif.
- Lecture des pages publiques Naver sans compte, cookies ou SDK supplémentaire.
- Stockage SwiftData local, isolé par compte Wander ; aucune écriture Firebase.
- Import complet et vérification du compte annoncé, validation des coordonnées,
  avertissements pour lieux indisponibles ou position modifiée.
- Pas de synchronisation automatique, de multi-champs ni de création de groupes.
- Aucun Git mutateur, branche ou commit, conformément aux instructions de Samuel.

## Preuve de faisabilité

Le lien fourni redirige vers une liste partagée accessible sans connexion.
Le 10 octobre, le service public utilisé par le site Naver renvoie 143 favoris,
tous avec nom, adresse et coordonnées valides ; 11 lieux sont signalés
indisponibles et un lieu porte un avertissement de position.
Ne pas copier le contenu personnel de cette liste dans les fixtures ou les logs.

## Fichiers affectés

- `wander/CreationMenuView.swift`, `wander/ContentView.swift`.
- Nouveaux `wander/NaverListImport.swift`, `wander/SavedPlace.swift`,
  `wander/NaverImportView.swift`, `wander/SavedPlaceDetailView.swift`,
  `wander/SavedPlaceAnnotation.swift`.
- `wander/MapWithFogView.swift`, annotations de carte si nécessaire.
- `wander/WanderMigrationPlan.swift`, `wander/wanderApp.swift`.
- `wander/Info.plist` : déclarer le français déjà utilisé par l'app pour
  localiser aussi le contrôle système de collage.
- `wander/Assets.xcassets/NaverMapLogo.imageset/`.
- `wanderTests/NaverListImportTests.swift`, `wanderTests/SavedPlaceTests.swift`,
  `wanderTests/WanderMigrationPlanTests.swift`.
- `wander/DebugSocialMapScenario.swift`, `wanderUITests/NaverImportUITests.swift`.
- Ce plan ; `todos/` pour les constats et `docs/solutions/` si une leçon réutilisable émerge.
- Coffre Obsidian Wander : `Backlog features.md`, `Documentation technique.md`,
  `Documentation UX.md`, `00 - Wander.md`, avec propriété `updated`.

## Étapes

- [x] Service de lecture et validation des listes Naver, tests synthétiques.
- [x] Modèle local, migration et dédoublonnage, tests de conservation.
- [x] Feuille d'import à un champ, logo, progression, aperçu et erreurs.
- [x] Carte et fiche du favori, branchement au menu +.
- [x] Simplification, compilation, tests ciblés et revue.
- [x] Documentation et validation finale consignées.

## Risques

L'interface du site Naver n'est pas une API publique documentée. Tout changement
de format doit produire une erreur compréhensible, sans import silencieusement
tronqué. La migration ne doit pas modifier les cellules d'exploration existantes.
Le logo provient d'une ressource officielle Naver. Les adresses importées ne
doivent pas être visibles dans un autre compte local.

## Validation et acceptation

Compiler l'app et ses tests. Vérifier extraction du lien, refus des hôtes non
Naver, pagination, données invalides, liste inaccessible, doublons, conservation
après réouverture et migration de l'exploration. Vérifier la lecture réelle de
la liste de 143 favoris. Tester l'UX, clavier, collage, chargement et annulation
sur le seul iPhone 17 déjà démarré, sans nouveau simulateur. Aucun test dédié
d'accessibilité n'est demandé. Capturer l'écran final et noter les limites.

Le coffre Obsidian est hors des racines inscriptibles par défaut ; demander
l'accès système uniquement au moment de la mise à jour approuvée et consigner
les sections en attente si cet accès échoue.

## Résultats

- `build-for-testing` réussi sur iPhone 17 Pro, iOS 26.3, UUID
  `C0DADF07-7E14-4D5E-AE4B-B17844A9C454`, Xcode 27.0.
- Première passe : 14 tests natifs et 2 parcours UI réussis.
- Seconde passe : 8 tests d'import et 4 tests de stockage réussis, dont mise à
  jour d'un objet déjà chargé dans le contexte principal après réimport.
- Le véritable `NaverListImporter` compilé depuis les sources de production
  récupère 143 lieux, 11 indisponibles et 1 position à vérifier via le lien court.
- `bookmarkMismatchInfo.isMatched == false` couvre aussi `UNAVAILABLE` ; seule
  la présence de `GEOMETRY` dans `details` déclenche l'alerte de position.
- Le contrôle final est `PasteButton`, sans accès direct à `UIPasteboard.string`.
  Le français est déclaré dans `CFBundleLocalizations` pour le libellé natif.
  Le test de collage du texte partagé a réussi après cette correction ; la
  tentative précédente de lecture directe bloquait la boucle UI du simulateur.
- Simplification : trois lectures indépendantes, suppression du callback inutilisé
  et requête SwiftData limitée au compte actif. Extraction des affectations de
  l'initialiseur non retenue : pas de bénéfice suffisant pour ce modèle.
- Aucun warning Swift. Les avertissements Xcode `Metadata extraction skipped,
  no AppIntents.framework dependency found` concernent des cibles sans AppIntents.
- La revue externe Claude a été refusée par le contrôle automatique d'approbation,
  car le transfert de code privé n'était pas autorisé. Revue locale indépendante
  utilisée, aucun transfert externe effectué.
- Source du logo : ressource officielle
  `https://ssl.pstatic.net/static/maps/assets/icons/android-icon-192x192.png`.
- Revue locale close : le seul constat P2 concernait l'ambiguïté du nom de
  liste après dédoublonnage. Le libellé précise maintenant « Dernière liste
  importée », cohérent avec le stockage des adresses. Voir le constat résolu
  `todos/077-done-p2-clarifier-source-favori-naver.md`.
- Les quatre notes Obsidian prévues ont été mises à jour, avec frontmatter
  `updated` et wikilinks préservés, sans ouvrir Obsidian.
- Les enseignements sont consignés ici, dans les tests et dans la documentation
  technique ; aucun doublon de ces explications dans `docs/solutions/`.

### Validation finale

Le 10 octobre à 13:18, compilation et 20 tests réussis : 8 tests du lecteur,
4 du stockage, 4 des migrations, 3 parcours Naver et 1 régression du bouton
des événements. Le parcours UI vérifie aussi explicitement le libellé « Coller ».
`git diff --check` et `plutil -lint wander/Info.plist` réussis.

Commande :

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' \
  -disableAutomaticPackageResolution -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  -only-testing:wanderTests/NaverListImportTests \
  -only-testing:wanderTests/SavedPlaceTests \
  -only-testing:wanderTests/WanderMigrationPlanTests \
  -only-testing:wanderUITests/NaverImportUITests \
  -only-testing:wanderUITests/MotionDockUITests/testEventsButtonReplacesNavigationBar test
```

Journal local : `/tmp/wander-naver-verified.log`.
Résultat Xcode :
`/Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx/Logs/Test/Test-wander-2026.10.10_13-16-27-+0900.xcresult`.
Capture finale inspectée :
`/tmp/wander-naver-final-screens/1E2F2569-ED20-4F13-BB83-42166867A951.png`.
Le logo, le titre, le champ unique, « Coller », la fermeture et le bouton
d'import désactivé sont visibles sans débordement en taille de texte standard.

## Limites de validation

- Le parcours UI utilise une liste synthétique et un propriétaire de test.
  La lecture des 143 lieux réels est vérifiée séparément avec le service de
  production, sans enregistrer de données personnelles dans les fixtures.
- L'isolation des comptes est vérifiée au niveau du stockage ; aucun changement
  de compte Firebase réel n'a été exécuté dans le simulateur.
- Le déplacement de 143 pins pendant un pan/zoom n'a pas été mesuré. Le parcours
  UI vérifie un pin, sa fiche, sa réouverture et le réimport sans doublon.
- Naver n'offre pas de jeton de snapshot. Un changement de liste pendant la
  pagination qui conserve le même total peut échapper aux contrôles de compte
  et de doublons. L'import n'est pas une synchronisation continue.

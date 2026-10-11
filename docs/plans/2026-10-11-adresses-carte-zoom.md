---
title: Adresses compactes et libellés au zoom
date: 2026-10-11
status: completed
completed_at: 2026-10-11T10:10:00+09:00
approved_at: 2026-10-11
---

# Résultat approuvé

Samuel a validé dans le chat les marqueurs de 20 points, une cible tactile
confortable, le nom en gras et le type en dessous à droite dès le zoom 16,
avec masquage au dézoom et un seuil décalé contre les clignotements.
La catégorie est conservée localement après fermeture. Les adresses déjà
importées restent intactes et récupèrent leur catégorie au prochain réimport.

## Périmètre et fichiers

- `wander/SavedPlaceAnnotation.swift` : présentation compacte et libellés.
- `wander/MapWithFogView.swift` : suivre le zoom et actualiser les annotations.
- `wander/NaverListImport.swift` : libellé de catégorie Naver et présentation commune.
- `wander/SavedPlace.swift`, `wander/WanderMigrationPlan.swift` : champs optionnels
  de catégorie, snapshot V4 et migration V5 sans perte d'exploration ni favoris.
- Tests du lecteur, du stockage et des migrations, nouveaux tests des annotations,
  `wanderUITests/NaverImportUITests.swift` et scénario debug si nécessaire.
- Ce plan et `todos/` pour tout constat de revue.
- Obsidian Wander : `Backlog features.md`, `Documentation UX.md`,
  `Documentation technique.md` dans le coffre existant.

## Implémentation et acceptation

- [x] Persister le code et le nom de catégorie ; préserver les anciennes données.
- [x] Réduire le symbole à 20 pt avec cible de 44 pt ; nom et type à droite.
- [x] Afficher à zoom >= 16, masquer sous 15,7 ; actualiser aussi les nouveaux pins.
- [x] Vérifier catégories, réimport, réouverture, migration V4, seuils et noms longs.
- [x] Compiler et tester zoom/dézoom et ouverture sur l'iPhone 17 Pro déjà démarré.
- [x] Relire, simplifier, capturer le rendu et actualiser Obsidian.

Le type connu est traduit en français (café, restaurant). Pour les autres,
le libellé fourni par Naver est conservé ; « Adresse » si aucun type disponible.
Les noms longs sont tronqués dans la carte, conservés en entier dans la fiche.
L'icône reste ancrée à sa coordonnée lors de l'apparition du texte.

## Risques et méthode

Le snapshot du schéma V4 doit rester identique à la version installée.
Les mises à jour de caméra ne doivent recalculer les vues qu'au franchissement
d'un seuil. Aucun changement Firebase ni appel réseau supplémentaire.
Les tests existants sont renforcés et une vérification de migration est ajoutée.
Le rendu et les gestes sont vérifiés à taille de texte standard, sans test dédié
d'accessibilité. Implémentation native en place : le travail Naver précédent
est non committé et conservé ; aucun Git mutateur ni transfert externe.

## Revue locale

La revue compare uniquement cet incrément à la copie de travail prise avant
implémentation dans `/tmp/wander-map-labels-baseline`. Aucun constat bloquant
ni actionnable. Le snapshot V4 conserve les attributs précédents ; les catégories
V5 sont optionnelles. L'ancrage et les annotations créées alors que la carte est
déjà zoomée ont été relus. Ce dernier cas n'a pas de test UI dédié.

Les trois lectures de simplification n'ont pas justifié de modification
supplémentaire. Regrouper les notifications de taille et décalage dans le moteur
commun a été écarté : aucun problème mesuré et modification plus large que ce
besoin. Reçu de revue :
`/tmp/wander-map-labels-review-20261011/review.json`.
Le helper de revue ne prend pas en charge une base constituée de fichiers ;
la comparaison et la revue ont donc été faites localement, manuellement.
La validation Xcode utilise l'équivalent CLI, XcodeBuildMCP étant indisponible.

Les trois notes Obsidian prévues ont été mises à jour, propriété `updated`
comprise. Aucun constat à ajouter à `todos/` ; aucune leçon nouvelle justifiant
une note supplémentaire dans `docs/solutions/`.

## Validation finale

Les 24 tests distincts concernés passent sur l'iPhone 17 Pro déjà démarré
`C0DADF07-7E14-4D5E-AE4B-B17844A9C454` : 20 tests natifs et 4 scénarios UI,
au terme des exécutions ciblées ci-dessous. Compilation Debug réussie,
aucun avertissement Swift ; seul avertissement d'outillage préexistant concernant
l'absence de dépendance AppIntents. `git diff --check` réussit.

Commande commune :

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug   -destination 'id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454'   -disableAutomaticPackageResolution -parallel-testing-enabled NO   -maximum-concurrent-test-simulator-destinations 1   -only-testing:wanderTests/NaverListImportTests   -only-testing:wanderTests/SavedPlaceTests   -only-testing:wanderTests/WanderMigrationPlanTests   -only-testing:wanderTests/SavedPlaceAnnotationTests   -only-testing:wanderUITests/NaverImportUITests test
```

- Exécution 09:59:36, `/tmp/wander-map-labels-tests.log` : les 20 tests natifs
  et 3 scénarios UI passent. Le pincement entrant XCTest touche les contrôles
  flottants et déplace la carte ; le test du dézoom échoue.
- Exécution 10:05:24, `/tmp/wander-map-labels-retest.log` : les 5 tests de migration
  renforcés passent avec le constructeur utilisé par l'app. Le test V4 couvre les
  magasins versionnés et non versionnés, deux propriétaires, réouverture et
  enrichissement au réimport sans doublon. Un pincement réduit reste inadapté.
- Exécution 10:08:56, `/tmp/wander-map-labels-zoom-final.log` : le scénario UI
  zoom/dézoom passe. Seul son sélecteur `-only-testing` est retenu. Zoom par pincement,
  dézoom par le geste natif de bord existant pour éviter les contrôles flottants.
  Vérification de l'icône compacte, du nom/type visibles, du retour compact et
  de l'ouverture de la fiche. Aucun changement de production depuis la revue.

Les trois résultats `.xcresult` sont dans
`/Users/samuelbarraud/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx/Logs/Test/`,
sous les noms `Test-wander-2026.10.11_<heure>-+0900.xcresult` avec les heures
`09-59-36`, `10-05-24` et `10-08-56`.

Captures relues visuellement dans `/tmp/wander-map-labels-final-screens/` :
- avant zoom : `F4CFA4AE-83B3-48BA-B6F8-9082A238BC5D.png` ;
- nom et type : `F769870A-6D85-4A6C-9D1B-ECEE4D8A97AA.png` ;
- après dézoom : `72A1DF2A-FCF2-4351-859D-0A76615D9806.png`.

Limites : données de scénario synthétiques, pas de validation sur iPhone physique.
Le dézoom par pincement n'est pas validé par ce scénario, qui utilise le geste de
bord. Les gestes de production n'ont pas été modifiés. Les anciens favoris gardent
« Adresse » jusqu'au réimport de leur liste ; stockage local inchangé, sans Firebase.

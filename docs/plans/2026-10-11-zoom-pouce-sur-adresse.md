---
title: Zoom au pouce depuis une adresse
date: 2026-10-11
status: completed
completed_at: 2026-10-11T18:09:58+09:00
approved_at: 2026-10-11
---

# Résultat approuvé

Samuel a approuvé le plan présenté dans le chat avec « je valide ».
Un glissement vertical à un doigt commencé sur une adresse enregistrée dans
les 44 points d'un bord doit zoomer ou dézoomer. Un tap ouvre toujours sa fiche.

## Périmètre

- `wander/MapEdgeZoomController.swift` : accepter l'annotation d'adresse et ses
  descendants, tout en conservant l'exclusion des contrôles et autres annotations ;
  reconnaître l'intention verticale avec la vitesse initiale du geste.
- `wanderTests/MapEdgeZoomControllerTests.swift` : couvrir cette exception et
  préserver les contrôles, ornements et annotations sociales.
- `wanderUITests/NaverImportUITests.swift` : geste depuis une adresse sur les
  deux bords, dans les deux directions, et tap après le geste.
- Ce plan ; `todos/` uniquement pour d'éventuels constats de revue actionnables.
- Coffre `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Documentation UX.md` et `Documentation technique.md`, sections zoom aux bords ;
  `Backlog features.md`, suivi du zoom au pouce. Actualiser leur propriété `updated`.

Hors périmètre : sensibilité, recentrage, rendu, autres marqueurs, données et Firebase.
Aucune dépendance supplémentaire, aucune commande Git mutatrice.

## Cause et dépendances

`excludesTouch` exclut tout `MapAnnotationView`, dont `SavedPlaceAnnotationView`,
avant la détection du bord. L'adresse porte aussi le trait `.button` : l'exception
doit précéder ces deux filtres sans retirer son support d'accessibilité.
Le test existant couvre l'exclusion générique, mais pas le cas d'une adresse.
Le tap de l'adresse utilise déjà un `UITapGestureRecognizer`.
La validation a aussi révélé que `translation(in:)` peut être nulle dans
`gestureRecognizerShouldBegin`, malgré un geste vertical. La vitesse initiale
remplace la translation pour cette décision uniquement ; le seuil directionnel,
la sensibilité, le recentrage et les mises à jour de zoom restent identiques.

## Checklist

- [x] Reproduire l'exclusion avec un test ciblé avant le correctif.
- [x] Appliquer l'exception minimale pour les adresses.
- [x] Vérifier les tests natifs et les gestes UI prévus.
- [x] Simplifier et relire le diff ; consigner la validation exacte.
- [x] Mettre à jour les trois notes Obsidian.

## Risques, validation et acceptation

Risque principal : ouverture involontaire de la fiche pendant un glissement.
Vérifier aussi que les contrôles restent exclus et que les gestes hors des bandes
latérales gardent leur comportement. Tests fonctionnels à taille standard,
sans tests dédiés d'accessibilité ni nouveau simulateur.

Compiler et tester avec le schéma `wander`, sur l'iPhone 17 Pro déjà démarré
`C0DADF07-7E14-4D5E-AE4B-B17844A9C454`, parallélisme désactivé.
XcodeBuildMCP n'est pas disponible ; utiliser l'équivalent `xcodebuild`/`simctl`.
Les tests natifs doivent passer ; les glissements depuis l'adresse doivent
changer le zoom sans ouvrir la fiche, et le tap doit encore l'ouvrir.
L'accès au coffre sera effectué uniquement pour les trois notes approuvées,
sans ouvrir Obsidian. Toute limitation sera inscrite ici.

## État initial

HEAD : `72d43307b6f5cbb30086635e0c9406962c4249c7`. Arbre propre avant intervention.
Travail local sur la branche existante, sans commit ni changement Git,
conformément aux instructions de Samuel.

## Historique de validation

- Avant correctif : `/tmp/wander-thumb-address-red.xcresult`, test
  `testSavedAddressAllowsEdgeZoomThroughItsIconAndLabels`, échec attendu des
  cinq assertions d'acceptation de l'adresse et de ses sous-vues.
- Après correctif : `/tmp/wander-thumb-address-green.xcresult`, les 25 tests
  de `MapEdgeZoomControllerTests`, les 7 de `SavedPlaceAnnotationTests` et
  `testHorizontalDragStartingAtEdgeStillPansMap` passent. Les deux nouveaux
  scénarios UI échouent sur leur positionnement préparatoire, pas sur une
  ouverture involontaire. Le dézoom depuis l'icône gauche passe déjà.
- Deuxième essai : `/tmp/wander-thumb-address-ui.xcresult`. Le déplacement
  préparatoire est maintenant horizontal et reste dans l'écran. Les captures
  vidéo montrent un décalage d'environ 12 points dû au seuil du geste natif,
  alors que le point reste dans la bande de 44 points. L'assertion de mise en
  place vérifie désormais cette bande plutôt qu'une position exacte à 10 points.
  Aucun changement supplémentaire du code de production.
- Les trois passes `ce-simplify-code` séparées, réutilisation, qualité et
  efficacité, n'ont relevé aucun constat actionnable.
- Les trois notes Obsidian approuvées ont été actualisées sans ouvrir l'app.
  Les propriétés `updated` ont changé et les wikilinks sont conservés.
- Le troisième essai `/tmp/wander-thumb-address-ui-final.xcresult` atteint bien
  le geste vers le haut depuis l'adresse au bord, mais celui-ci peut devenir
  un panoramique. La trace temporaire confirme `excluded=false`, le bon bord,
  un seul doigt et une translation `(0, 0)` au moment de `shouldBegin`.
  Le contrôleur utilise désormais la vitesse initiale pour cette décision.
  La trace est conservée dans `/tmp/wander-thumb-address-probe-stream.log` ;
  les instructions de diagnostic ont été retirées du code.


## Validation finale

Résultat : PASS, 35 tests distincts ciblés réussis au terme des exécutions.
Projet `wander.xcodeproj`, schéma `wander`, configuration Debug, iPhone 17 Pro
`C0DADF07-7E14-4D5E-AE4B-B17844A9C454`, iOS 26.3, déjà démarré.
Compilation de l'application et des tests réussie. Aucun avertissement Swift ;
seul avertissement d'outillage préexistant concernant AppIntents.

| Vérification | Résultat | Preuve |
|---|---|---|
| Contrôleur de zoom, 25 tests | PASS | `/tmp/wander-thumb-address-validated.xcresult` |
| Annotations d'adresse, 7 tests | PASS | même résultat |
| Panoramique horizontal au bord | PASS | même résultat |
| Adresse au bord gauche : dézoom, zoom, tap | PASS | `/tmp/wander-thumb-address-final.xcresult`, 32,362 s |
| Adresse au bord droit : dézoom depuis le libellé, zoom depuis l'icône, tap après recentrage | PASS | même résultat, 35,537 s |
| Revue du diff et `git diff --check` | PASS | `/tmp/wander-thumb-address-review/review.json` |

Commande commune réellement utilisée :

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' \
  -disableAutomaticPackageResolution -parallel-testing-enabled NO \
  -maximum-concurrent-test-simulator-destinations 1 \
  -only-testing:wanderUITests/NaverImportUITests/testLeftEdgeZoomStartsOnSavedAddressIconAndStillAllowsTap \
  -only-testing:wanderUITests/NaverImportUITests/testRightEdgeZoomStartsOnSavedAddressLabelAndStillAllowsTap \
  -resultBundlePath /tmp/wander-thumb-address-final.xcresult test
```

L'exécution `validated` utilise les mêmes options avec les sélecteurs supplémentaires
`-only-testing:wanderTests/MapEdgeZoomControllerTests`,
`-only-testing:wanderTests/SavedPlaceAnnotationTests` et
`-only-testing:wanderUITests/MapSocialGestureUITests/testHorizontalDragStartingAtEdgeStillPansMap`.
Les logs portent le même nom que chaque résultat avec l'extension `.log`.
Le code de production n'a plus changé après `validated` ; seule l'assertion UI
sur le cadrage droit a été corrigée. Les traces temporaires ont été retirées.

Le dernier échec droit était une mauvaise attente du test : le zoom passe de
13,554 à 14,927 et l'adresse sort du champ, sans cible de focus à coordonnée
visible. Les traces `/tmp/wander-thumb-address-right-probe.log` le confirment.
Le test final vérifie cette sortie, puis recentre avant de tester le tap.
L'hypothèse intermédiaire d'un marqueur social interceptant ce dernier toucher
n'est pas retenue : la trace identifie bien `SavedPlaceAnnotationView`.

Captures exportées dans `/tmp/wander-thumb-address-final-screens/`.
Inspection visuelle du zoom gauche, du cadrage droit après zoom et du retour
après recentrage :
- `67771016-7431-47F5-A36C-1B9986A959D7.png` ;
- `5CB84382-D5D8-4C4B-82F5-E73E5DB3CD25.png` ;
- `BA0E137D-4ED2-4E60-9923-8D7BB5A877A4.png`.

Aucun crash observé dans les parcours. Les tests natifs de cartes locales
émettent les messages SDK de localisation indisponible déjà présents ; les
scénarios utilisent des données synthétiques. Vérifications humaines : 0.
Échecs restants : 0. Pas de validation sur iPhone physique ni des vibrations.
Aucun simulateur supplémentaire démarré ou créé.

## Revue et documentation

La revue `ce-code-review` porte sur le diff depuis
`72d43307b6f5cbb30086635e0c9406962c4249c7`, les critères de `AGENTS.md` et ce plan.
Le parcours lite vérifie le correctif, les deux sites d'appel du filtre,
l'arbitrage avec le pan natif, la sélection par tap et les tests. Aucun constat
justifié à inscrire dans `todos/`. Pas de revue externe ni publication.

L'exception pour les seules adresses préserve les contrôles et marqueurs sociaux.
Modifier les délégués Mapbox ou le système de sélection aurait élargi inutilement
le correctif. Le point le moins certain reste le ressenti sur téléphone réel.

Les trois notes Obsidian prévues, leurs propriétés `updated` et leurs wikilinks
ont été vérifiés après écriture. `ce-compound` ne crée pas de note supplémentaire :
la cause et la prévention sont déjà explicites dans le code, le test et ce plan.
Aucune commande Git mutatrice, aucun commit et aucun push.

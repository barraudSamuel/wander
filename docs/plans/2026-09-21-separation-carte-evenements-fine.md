---
title: Réduire la séparation noire entre la carte et les événements
status: in_progress
approved_at: 2026-09-21
---

## Première révision à 12 points, historique

Samuel a demandé de revenir au rendu initial et de réduire seulement l'épaisseur
avec « en fait fait comme avant, juste ça doit etre plus fin la separation ».
Il approuve le plan révisé avec « je valide ». Ce plan remplace la proposition
Liquid Glass. La bande noire passe de 44 à 12 points, avec la poignée blanche
et les arrondis d'origine. Aucun verre ni dégradé ajouté à la jonction.
La zone tactile conserve 44 points et les gestes restent identiques.

## Périmètre

- `wander/MapDetailSplitView.swift` : bande, poignée et réserve tactile.
- `wanderUITests/MapSocialGestureUITests.swift` : assertions géométriques existantes.
- Ce plan et `todos/059-ready-p2-valider-carrousel-evenements.md`.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md` : Fiches et carte partagée.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md` : split et poignée.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md` : validation de la liste événements.

Actualiser `updated` et conserver les wikilinks, sans ouvrir Obsidian.
Pas de modification des données, de la navigation, des profils ou des seuils
et raccourcis de redimensionnement. Aucun Git mutant, commit ou publication.

## Mise en œuvre

- [x] Retirer les ajouts de verre, dégradé et arrondis modifiés.
- [x] Réserver 12 points pour la bande noire, centrer la poignée blanche et
  garder sa cible tactile de 44 points. Dégager la première ligne et les
  commandes cartographiques de la portion superposée.
- [x] Adapter les assertions existantes et relire le diff.
- [x] Compiler app et tests, contrôler visuellement sur l'iPhone 17 déjà démarré.
- [x] Mettre à jour le suivi et les trois notes Obsidian avec preuves et limites.

## Risques et validation

La poignée ne doit pas masquer la première ligne ni les contrôles MapKit.
Carte et liste restent montées. La zone visible de la carte doit continuer de
changer sans redimensionner ses bounds natifs. Le coefficient d'animation doit
utiliser l'épaisseur de 12 points, indépendamment de la cible tactile de 44.
Compilation `xcodebuild build-for-testing`, puis `git diff --check` et revue.
Contrôle visuel clair/sombre sur l'iPhone 17 existant uniquement ; aucun autre
simulateur démarré ou créé. Aucun test dédié d'accessibilité.

Les tentatives UI de la version abandonnée sont conservées dans
`/tmp/wander-events-glass-ui*.xcresult`. Après correction des poignées invisibles,
les trois tests échouaient à ouvrir la liste via le calendrier sous XCTest,
alors que le clic direct l'ouvrait. Ce n'est pas une preuve de validation de
cette version. Une limitation persistante doit rester explicite dans le suivi.

## Critères d'acceptation

- Aspect initial, bande noire de 12 points et poignée blanche.
- Cible tactile de 44 points et contenu dégagé.
- App et tests compilés, revue effectuée, rendu inspecté.
- Toute validation gestuelle indisponible est consignée ; aucune réussite de
  test n'est déclarée sans preuve.
- Notes Obsidian actualisées ou limitation d'écriture précisément rapportée.

## Contexte de travail

Les seuls changements présents au démarrage de cette révision sont ceux de
la proposition abandonnée. Exécution native dans le checkout fourni, sur
`main`, sans commande Git mutante conformément aux instructions utilisateur.

## Validation réalisée

- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug
  -destination 'platform=iOS Simulator,id=6F13855D-10B8-45AF-9205-17C8393379E3'
  -disableAutomaticPackageResolution build-for-testing` : code 0,
  `TEST BUILD SUCCEEDED`. Journal `/tmp/wander-events-thin-build.log`.
- Avertissements AppIntents préexistants, aucune erreur de compilation.
- iPhone 17 déjà démarré, iOS 26.3. Aucun appareil supplémentaire créé/démarré.
  Captures inspectées : `/tmp/wander-events-thin-dark.png` et
  `/tmp/wander-events-thin-light.png`. Mode sombre initial restauré.
- Contrôle direct avec `computer-use` : ouverture calendrier, agrandissement
  par la poignée, second toucher qui ferme et restitue la carte entière.
- Pas de nouveau passage XCTest pour cette révision : le plan simplifié
  prévoit compilation et contrôle visuel. Le glissement et le défilement
  restent non validés ; aucun succès UI automatisé revendiqué.
- `ce-simplify-code` : trois passes réemploi/qualité/efficacité, aucune
  modification supplémentaire retenue. Les rayons dupliqués étaient déjà
  présents dans la version d'origine. Les valeurs 12/6/44 dans les assertions
  expriment le contrat visuel. La condition sur la poignée supérieure est
  conservée, car le passage précédent avait prouvé qu'une hauteur nulle ne
  suffisait pas à la rendre absente dans XCTest.
- `ce-code-review`, revue lite du diff et des exigences : aucune anomalie
  retenue ; limites gestuelles conservées dans 059. Reçu
  `/tmp/compound-engineering-501/ce-code-review/20260921-events-thin/review.json`.
- Pas de nouvelle solution dans `docs/solutions/` : ajustement visuel local,
  aucun apprentissage durable supplémentaire vérifié.

- Trois notes Obsidian mises à jour dans le coffre existant, `updated` actualisé
  et wikilinks vérifiés identiques, sans ouverture d'Obsidian.
- `git diff --check` : succès. Aucun commit ni commande Git mutante.

Décision principale : garder 12 points de bande visible et superposer uniquement
la zone tactile de 44 points. Réduire aussi cette zone aurait rendu la poignée
plus difficile à saisir. Les arrondis, couleurs et symbole initiaux sont conservés.
Le glissement reste la principale limite de validation, suivie explicitement
avec le défilement dans 059.

## Ajustement approuvé à 20 points

Samuel précise « 20 » puis approuve avec « oui » le passage de 12 à 20 points.
Même périmètre de fichiers, même apparence et cible tactile de 44 points.
Le débordement tactile calculé passe de 16 à 12 points de chaque côté.
La validation précédente ci-dessus concerne la version à 12 points.

- [x] Passer la métrique à 20 et les demi-épaisseurs attendues à 10.
- [x] Compiler app/tests.
- [ ] Inspecter le rendu sur l'iPhone 17 existant, actuellement éteint.
- [x] Relire le diff et synchroniser le suivi et les trois notes Obsidian.

Risque : alignement de la poignée et dégagement de la première ligne.
Acceptation : bande de 20 points, cible de 44, compilation réussie et rendu vérifié.

Validation du réglage à 20 points :

- `xcodebuild build-for-testing` avec la même destination iPhone 17 : code 0,
  `TEST BUILD SUCCEEDED`, journal `/tmp/wander-events-20-build.log`.
- Revue manuelle de cet ajustement numérique : métrique 20, demi-épaisseur 10
  dans les assertions, débordement calculé `(44 - 20) / 2 = 12`.
  Aucun changement supplémentaire requis, aucune anomalie retenue.
- `simctl list devices booted` ne liste que l'iPhone 16e. L'iPhone 17 autorisé
  est éteint. Aucun simulateur démarré et aucun nouveau contrôle visuel réalisé.
  Le plan reste `in_progress` pour cette validation ; les anciennes captures
  ne prouvent pas le rendu à 20 points.
- Notes UX, technique et backlog actualisées avec dates et wikilinks préservés.
- Aucun test UI exécuté pour cet ajustement.

---
title: Harmoniser les listes Amis et Événements
status: completed
date: 2026-09-23
approved_at: 2026-09-23
reapproved_at: 2026-09-23
completed_at: 2026-09-23
owner: Samuel Barraud
related:
  - 2026-09-23-corriger-reserve-dock-listes.md
tags: [plan, ux, listes]
---

# Harmoniser les listes Amis et Événements

## Décision initiale, remplacée par la correction ci-dessous

Les panneaux possèdent un titre fixe « Amis » ou « Événements » et une base
commune de présentation et de défilement. Les contenus et actions restent
propres à chaque liste. Amis conserve demandes reçues, amis puis demandes
envoyées. Les hauteurs initiales restent la moitié pour Amis et un tiers pour
Événements. Samuel a approuvé le plan présenté dans la conversation.

## Périmètre et approche

Ajouter l'en-tête hors de la zone défilante dans le conteneur partagé, garder
les deux listes montées et centraliser les réglages communs. Contrôler les
espacements au simulateur. Conserver la marge de fin de contenu sous le dock,
la poignée, les actions existantes et les modifications locales antérieures.
Aucun changement Firebase, modèle de données, hauteur initiale ou navigation.

## Fichiers concernés

- `wander/MapDetailSplitView.swift` : conteneur et présentation partagés.
- `wander/FriendsPanelView.swift` : intégration de la liste Amis.
- `wander/MapEventsPanelView.swift` : intégration de la liste Événements.
- `wander/DebugSocialMapScenario.swift` : alignement du scénario de validation
  sur les réglages partagés si nécessaire.
- `wanderUITests/MotionDockUITests.swift` : titres pendant le défilement et
  contrôles existants de géométrie, bas de liste et conservation d'état.
- Ce plan, et `todos/` uniquement pour les constats de revue éventuels.
- Vault Obsidian Wander : `Backlog features.md`, `Documentation UX.md`,
  `Documentation technique.md`, avec actualisation de `updated`.

## Dépendances et risques

Le correctif de réserve sous le dock est déjà présent dans les fichiers locaux.
Ne pas le remplacer. Risques : double marge, en-tête masqué par le débord tactile
de la poignée, perte de défilement à la commutation. La simulation Amis utilise
un contenu local distinct de la vue connectée : vérifier aussi son intégration
par lecture du code et compilation de la vue de production.
Les opérations Git restent strictement en lecture seule selon AGENTS.md.

## Implémentation

- [x] Ajouter l'en-tête fixe commun et harmoniser les réglages de liste.
- [x] Vérifier l'ordre des sections et préserver les états/actions.
- [x] Contrôler la simplicité du changement et adapter les vérifications UI.
- [x] Compiler et valider sur l'iPhone 17 déjà démarré.
- [x] Effectuer la revue et actualiser les trois notes Obsidian.

## Validation et acceptation

Titres toujours visibles et immobiles pendant le défilement, espaces cohérents
au sommet des panneaux, hauteurs initiales conservées, demandes reçues en haut
et envoyées en bas, dernière ligne accessible au-dessus du dock, défilement et
hauteur conservés lors des changements de liste et retours de profil.
Tests ciblés MotionDockUITests et captures sur l'iPhone 17 existant, taille de
texte standard ; aucun nouveau simulateur ni test d'accessibilité dédié.
Compilation sans nouveau diagnostic et `git diff --check`.
Cette modification de présentation sera vérifiée par les tests UI existants
renforcés et les captures, sans exécution rouge préalable dédiée au style.

## Revue et résultats de la première implémentation

- `listPanel` conserve les deux panneaux dans leurs emplacements du `ZStack`.
  Le titre est hors de la `List`, avec marges horizontales et verticales de
  16 points. Les réglages communs sont appliqués au contenu depuis l'enveloppe.
- Suppression du `NavigationStack` sans destination d'Amis et des anciens
  réglages dupliqués. Aucun changement aux services, sections, actions ou seuils.
- `ce-simplify-code` : trois relectures, une propriété d'environnement inutilisée
  supprimée dans le scénario ; aucun autre constat de réutilisation ou efficacité.
- Revue `ce-code-review` adaptée en lecture seule à la différence avec les copies
  de début de session. Le helper exige des références Git et ne représente pas
  cette base sans inclure le travail antérieur ou muter Git. Revue manuelle ciblée
  équivalente, aucun constat actionnable. Reçu :
  `/tmp/wander-list-parity-review/review.json`.
- Aucun fichier `todos/` ajouté : aucun défaut du changement restant en revue.
  Deux avertissements de configuration existants restent présents dans la première
  compilation : CFBundleVersion des extensions 15 et 27 contre 46 pour l'app.
  Aucun nouveau diagnostic Swift observé. Aucun réglage de version modifié.
- Notes Obsidian `Backlog features.md`, `Documentation UX.md` et
  `Documentation technique.md` actualisées le 23 septembre, propriété `updated`
  incluse. Wikilinks comparés avant/après et préservés. Obsidian non ouvert.
- Pas de nouvelle fiche de solution : le changement et le sélecteur du test sont
  explicites dans le code, sans apprentissage d'architecture à consigner séparément.

### Résultats exacts

Compilation de l'app et des tests réussie sur l'iPhone 17 déjà démarré,
`6F13855D-10B8-45AF-9205-17C8393379E3`, iOS 26.3.1.
XcodeBuildMCP absent : workflow `ce-test-xcode` remplacé par `xcodebuild` et
`simctl`, conformément au fallback du projet.

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'platform=iOS Simulator,id=6F13855D-10B8-45AF-9205-17C8393379E3' \
  -derivedDataPath /tmp/wander-derived-data -disableAutomaticPackageResolution \
  -parallel-testing-enabled NO \
  -only-testing:wanderUITests/MotionDockUITests/testBottomOfFriendsListClearsNativeDock \
  -only-testing:wanderUITests/MotionDockUITests/testBottomOfEventsListClearsNativeDock \
  -only-testing:wanderUITests/MotionDockUITests/testFriendsListKeepsRequestsHeightAndScrollAcrossEventsAndProfile \
  -only-testing:wanderUITests/MotionDockUITests/testEventsButtonSitsBesideNativeTabsAndTogglesList \
  test -quiet
```

- Premier résultat `Test-wander-2026.09.23_15-12-39-+0900.xcresult` sous
  `/tmp/wander-derived-data/Logs/Test/` : trois réussites ; test Amis en échec
  uniquement sur la nouvelle recherche du texte « Demande envoyée » séparé.
  Ses assertions de titre fixe et de dernière cellule au-dessus du dock passent.
- Diagnostic `ce-debug` : le `LabeledContent` du scénario expose un libellé
  combiné « Alex, Demande envoyée ». La tentative intermédiaire de lire `value`
  échoue également : `Test-wander-2026.09.23_15-17-55-+0900.xcresult`.
  Son arbre XCTest établit le libellé exact et une valeur vide pour « Alex ».
  L'assertion finale vérifie que le libellé combiné est touchable, sans changement
  de l'application ni suppression de contrôle.
- Relance de la même commande avec uniquement
  `-only-testing:wanderUITests/MotionDockUITests/testBottomOfFriendsListClearsNativeDock` :
  succès, code 0, un test réussi et zéro échec.
  Résultat `Test-wander-2026.09.23_15-20-25-+0900.xcresult`.
- Les quatre tests ciblés ont ainsi chacun un résultat réussi sur le code final.
  Les trois autres n'ont pas été répétés après la correction isolée du sélecteur Amis.
- `git diff --check` réussi. Aucun Git en écriture exécuté.
- Captures à l'ouverture et en fin de liste examinées en mode sombre :
  `/tmp/wander-list-parity-attachments/` pour Événements et
  `/tmp/wander-list-parity-final-attachments/` pour Amis. Titres alignés à gauche,
  fixes ; dernières lignes au-dessus du dock ; demandes envoyées sous les amis.

### Limites et choix de revue

Décision principale : placer les titres dans le conteneur partagé plutôt que
les répéter dans les listes. Les titres de section Amis gardent leur rôle propre.
Les hauteurs restent inchangées. L'option d'un simple titre de section pour
Événements ne garantirait pas un titre de panneau indépendant du contenu.

Le scénario utilise la vraie liste Événements et une liste Amis locale distincte.
L'intégration de `FriendsPanelView`, y compris ses alertes après retrait du
`NavigationStack`, est couverte par compilation et lecture du code, pas par un
compte Firebase réel. Les actions Firebase n'ont pas été modifiées ni validées
à distance. Aucun test d'accessibilité dédié n'a été ajouté ou exécuté.


## Correction approuvée après la capture utilisateur

Samuel a refusé le doublon « Amis » puis « Mes amis » et a explicitement
validé le correctif proposé : supprimer le bandeau ajouté, garder uniquement
l'en-tête natif existant « Mes amis » et ajouter un en-tête de section identique
« Événements ». Le comportement est celui des sections de `List(.plain)` :
le titre de la section courante s'accroche en haut pendant le défilement.
Les sections de demandes reçues et envoyées restent respectivement avant et
après les amis. Les hauteurs initiales et la réserve sous le dock sont conservées.

### Fichiers et étapes de la correction

- [x] `wander/MapDetailSplitView.swift` : supprimer les titres extérieurs et
  leur `VStack`, appliquer les réglages de liste au `ZStack` partagé.
- [x] `wander/MapEventsPanelView.swift` : englober états et événements dans
  `Section("Événements")`, identique à `Section("Mes amis")` côté amis.
- [x] `wanderUITests/MotionDockUITests.swift` : remplacer les assertions sur
  les anciens titres extérieurs par absence de doublon et en-têtes natifs,
  conserver les contrôles de dernière ligne et d'état entre listes.
- [x] Vérifier `wander/FriendsPanelView.swift` et le scénario local
  `wander/DebugSocialMapScenario.swift` ; ils possèdent déjà la bonne section.
- [x] Compiler, exécuter les quatre tests ciblés sur l'iPhone 17 existant et
  examiner les captures, dont une liste Amis sans demande reçue.
- [x] Mettre à jour les notes Obsidian `Backlog features.md`,
  `Documentation UX.md`, `Documentation technique.md`, leurs propriétés
  `updated` et la présente validation. Aucun nouveau fichier de sprint requis.

### Risques et acceptation de la correction

Ne pas confondre titre de panneau fixe et en-tête de section natif. Le titre
« Mes amis » s'affiche pour sa section ; les sections de demandes gardent leurs
propres en-têtes. Contrôler l'absence du bandeau « Amis » sur la capture,
le même style natif des deux titres, l'accroche au scroll, les demandes dans
l'ordre, le redimensionnement et le dégagement de la dernière ligne.
Les réglages partagés ne doivent pas être perdus en retirant le `VStack`.

### Validation de la correction

- Application et cibles de tests compilées ; aucun avertissement dans le journal
  de cette compilation incrémentale. Aucun changement de configuration effectué.
- Les quatre tests ciblés de la commande complète ci-dessus ont été réexécutés
  ensemble et passent : 4 réussis, 0 échec, 0 ignoré, code de sortie 0.
- Résultat :
  `/tmp/wander-derived-data/Logs/Test/Test-wander-2026.09.23_15-36-18-+0900.xcresult`.
- Journal : `/tmp/wander-native-list-headers-tests.log`.
- Captures examinées dans `/tmp/wander-native-list-headers-attachments/` :
  `0803C467-0769-499F-87B3-4248690247A0.png` montre Amis sans demande reçue et
  sans bandeau ; `E2A19C75-3699-47D2-8C7E-5BA688267FB7.png` montre le même
  en-tête natif pour Événements ; `07BF4221-C6E5-4479-B360-2843750F39B1.png`
  montre Mes amis accroché au sommet après défilement et redimensionnement.
  Les dernières lignes des deux listes restent au-dessus du dock.
- Tests effectués en mode clair à taille standard sur l'iPhone 17 existant.
  Le mode sombre initial a été rétabli après extraction des preuves.
- Trois relectures `ce-simplify-code` : aucun constat, aucun changement ajouté.
  Revue de correction et respect des instructions ciblée sur les trois fichiers
  modifiés, aucun défaut actionnable. Reçu :
  `/tmp/wander-native-list-headers-review/review.json`.
- Même adaptation de `ce-code-review` que précédemment pour exclure le travail
  local antérieur : comparaison avec les copies de début de correction,
  sans opération Git en écriture. Validation locale `xcodebuild` et `simctl`
  équivalente à `ce-test-xcode`, XcodeBuildMCP étant absent.
- `FriendsPanelView` et le scénario possédaient déjà `Section("Mes amis")` ;
  aucun changement supplémentaire dans ces fichiers pendant la correction.
- Trois notes Obsidian corrigées, `updated` actualisé et wikilinks préservés.
  Aucun rendu Obsidian ouvert. `git diff --check` réussi.
- Aucun constat restant du correctif à enregistrer dans `todos/`. Les limites
  du scénario Amis local et l'absence de validation Firebase réelle restent
  identiques. Aucun test d'accessibilité dédié.

La validation de la première implémentation ci-dessus reste historique. La
capture de Samuel a invalidé cette présentation à deux niveaux de titre ;
les captures et les tests de cette correction valident les en-têtes natifs seuls.

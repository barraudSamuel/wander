---
title: "Rétablir la barre native sous les panneaux Amis et Profil"
status: completed
date: 2026-09-10
approved_at: 2026-09-10
completed_at: 2026-09-10
owner: Samuel
tags: [plan, ios, navigation, regression]
---

# Barre native et panneaux

> Suite approuvée : [conserver la fiche carte sous les panneaux](2026-09-10-conserver-fiche-sous-panneaux.md).
> La barre et ses gestes restent identiques ; le nouveau correctif conserve aussi
> la sélection et la hauteur de la fiche déjà ouverte.

## Résultat et approbation

Samuel a approuvé le correctif présenté dans la conversation par « j’approuve ».
La barre système retrouve les assets TabIconExplore, TabIconFriends et
TabIconProfile, le Liquid Glass et les interactions natives d’appui maintenu puis
glissement. Les panneaux s’ouvrent au-dessus, avec une animation indépendante.
La carte reste montée et conserve sa caméra. Ce correctif remplace la décision
de barre personnalisée du plan `2026-09-10-panneaux-amis-profil.md`.

## Périmètre

- Utiliser un vrai composant de navigation système, sans recréer sa lentille,
  ses icônes ou ses reconnaisseurs avec des boutons SwiftUI.
- Héberger une seule carte et les panneaux au-dessus du contenu, sous la barre
  native. Si nécessaire, utiliser un conteneur UIKit public pour gérer cet ordre
  et les zones sûres, sans introspection de classes privées.
- Conserver les contenus et actions des panneaux, le brouillon du code ami,
  les fermetures et la protection des confirmations du profil.
- Ne modifier ni Firebase, ni les modèles, ni les assets d’origine.
- Aucun commit, branchement ou autre commande Git mutante.

## Fichiers concernés

- `wander/MotionDockView.swift` : panneau séparé de la barre native.
- `wander/NativeMapTabView.swift` si nécessaire : conteneur natif de navigation.
- `wander/ContentView.swift` et `wander/DebugSocialMapScenario.swift` : intégration.
- `wanderUITests/MotionDockUITests.swift` et `MapSocialGestureUITests.swift`.
- Ce plan, l’ancien plan et les constats de revue dans `todos/`.
- `docs/solutions/` uniquement pour un enseignement vérifié et réutilisable.
- Notes du vault `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Backlog features.md`, `Documentation technique.md`, `Documentation UX.md`,
  `00 - Wander.md`. Actualiser `updated` et conserver les wikilinks.

## Exécution

- [x] Enregistrer l’approbation et le périmètre des modifications existantes.
- [x] Ajouter une régression qui exige une barre native et tester son échec.
- [x] Rétablir la barre et les icônes avec une carte persistante.
- [x] Animer uniquement les panneaux et vérifier les gestes natifs.
- [x] Vérifier les parcours carte, clavier, confirmations, rotation et grande police.
- [x] Simplifier, relire et vérifier les captures, y compris pendant une transition.
- [x] Mettre à jour les quatre notes et consigner les résultats exacts.

## Risques et critères d’acceptation

- La superposition ne doit intercepter ni les gestes MapKit ni ceux de la barre.
- Les trois commandes gardent leur position lors des changements de panneau.
- L’appui maintenu puis le glissement sélectionne les onglets par le composant iOS.
- Un second appui ferme le panneau ; Explorer et le toucher extérieur le ferment.
- La carte conserve sa taille, son zoom et sa position ; les fiches et le rail
  restent utilisables après fermeture.
- La barre reste accessible avec clavier, en paysage et en Dynamic Type AX5.
- Tests uniquement sur l’iPhone 17 existant déjà autorisé, UUID
  `6F13855D-10B8-45AF-9205-17C8393379E3`. Aucun appareil/runtime ajouté.
- Contrôle vidéo des transitions, car les tests précédents ne vérifiaient que
  les états stabilisés et ont laissé passer la régression des icônes.

## Éléments de départ

Le checkout porte les changements non commités du premier plan, tous concernés
par ce correctif. La vidéo utilisateur montre le saut de l’icône active dans le
panneau. Les assets existent toujours ; leur usage a été remplacé par des SF
Symbols dans MotionDockView. Le TabView système a été remplacé par un HStack.
Les effets et interactions de la barre native doivent appartenir à UIKit/SwiftUI,
pas à une animation du conteneur du panneau.

Source Apple : https://developer.apple.com/videos/play/wwdc2025/284/.

## Diagnostic et validation

- Test rouge observé : `testUsesNativeTabBarAndSupportsPressThenSlide` échoue
  sur « La navigation doit utiliser la barre système », avant changement du code.
  Journal `/tmp/wander-native-tabs-red.log`.
- Conteneur UIKit public retenu : un seul hosting controller de carte/panneaux,
  sous la vraie tabBar. Les valeurs SwiftData nécessaires traversent le pont.
  Aucun placement de bouton ni effet de sélection n’est redessiné dans SwiftUI.
- Les trois relectures `ce-simplify-code` (réutilisation, qualité, efficacité)
  n’ont retenu aucun changement supplémentaire.
- Le premier essai UIKit a montré deux contraintes : la tabBar iOS 26 vit dans
  un conteneur intermédiaire, et le hosting persistant hors des onglets sélectionnés
  reçoit des safe areas nulles, même avec `additionalSafeAreaInsets`.
  Mesure : root top 62/bottom 34, guide `(0, 62, 402, 729)`, hosting zéro.
  Le placement cherche le parent direct de la barre via les API publiques ; les
  guides `contentLayoutGuide` et `keyboardLayoutGuide` sont transmis à SwiftUI
  par des `safeAreaInset`. Aucune classe privée n’est nommée ou interceptée.
- Une assertion vérifie que le bas de chaque panneau reste avant la tabBar.
  Le test de caméra maintient brièvement le doigt avant relâchement pour mesurer
  une position stabilisée, sans élargir la tolérance de deux points.
- Revue externe Grok via Cursor refusée par l’approbation automatique, faute
  d’autorisation explicite pour ce destinataire. Aucun envoi effectué ; revue
  poursuivie avec des agents locaux.

## Résultats finaux

- Build Debug et 7 tests UI réussis sur l’iPhone 17 iOS 26.3 autorisé :
  `MotionDockUITests` (6 cas) et
  `MapSocialGestureUITests/testMapFillsWindowBehindMotionDock` (1 cas).
  Journal `/tmp/wander-native-tabs-layout-guides.log` ; résultat
  `Test-wander-2026.09.10_13-29-16-+0900.xcresult` dans les Logs/Test du DerivedData Wander.
- Après le dernier retour de focus VoiceOver, nouveau build et test
  `testUsesNativeTabBarAndSupportsPressThenSlide` renforcé : deux appuis rapides
  pendant la transition, retour à Explorer, positions inchangées, puis maintien
  0,6 seconde et glissement vers Profil. Réussite dans
  `/tmp/wander-native-tabs-rapid.log`.
- Les tests vérifient aussi : fermeture par second appui et fond, caméra après
  zoom/pan stabilisé, brouillon avec clavier, défilement jusqu’au dernier réglage,
  confirmation locale, rotation AX5, fiches carte et rail après fermeture.
- Captures finales relues dans `/tmp/wander-native-tabs-verified-captures` :
  Profil portrait, paysage AX5, dernier réglage visible. Vidéo complète
  `/tmp/wander-native-tabs-verified-transitions.mp4` et extrait de 13 secondes
  `/tmp/wander-native-tab-panels.mp4`. Dix-huit images du passage Amis vers Profil
  relues : les icônes restent dans la barre.
- `ce-code-review` : huit retours locaux, aucun défaut retenu ; rapport
  `/tmp/wander-native-correction-review/review.json`. Les limites du scénario
  compte/notifications et du parcours VoiceOver restent dans le todo 044.
- Les quatre notes Obsidian ont été actualisées avec leur propriété `updated`
  et leurs wikilinks conservés. Aucun lancement d’Obsidian.
- `ce-compound` léger : enseignement des mesures UIKit/SwiftUI consigné dans
  `docs/solutions/2026-09-10-zones-sures-sous-tab-bar-native.md` ; validateurs de
  frontmatter et des références réussis. Aucun terme métier supplémentaire à
  ajouter à `CONCEPTS.md` ; les instructions rendent déjà `docs/solutions/` accessible.
- `git diff --check` réussi. Aucun asset, service Firebase ou modèle modifié,
  aucune commande Git mutante. Les avertissements d’extraction AppIntents
  sont préexistants ; aucun nouvel avertissement Swift dans les builds finaux.

La validation automatisée utilise les données locales du scénario DEBUG.
Elle ne prétend pas valider des mutations Firebase, une réauthentification Apple,
ni le parcours vocal VoiceOver sur appareil.

---
title: "Ouvrir Amis et Profil depuis la barre inférieure"
status: completed
date: 2026-09-10
approved_at: 2026-09-10
completed_at: 2026-09-10
owner: Samuel
tags: [plan, ios, navigation]
---

# Panneaux Amis et Profil

> La fermeture automatique de la fiche carte décrite dans cette première version
> est remplacée par sa conservation sous les panneaux, selon le
> [correctif approuvé](2026-09-10-conserver-fiche-sous-panneaux.md).

> Correctif approuvé le 10 septembre : la décision initiale de barre personnalisée
> ci-dessous est remplacée par une vraie barre système, avec les assets et gestes
> d’origine. Voir [le plan de rétablissement de la barre native](2026-09-10-retablir-barre-native.md).
> Les validations de ce document décrivent la première version ; les tests
> complémentaires du correctif couvrent aussi les gestes natifs et les transitions.

## Outcome

La carte reste montée et conserve sa caméra. Amis et Profil ouvrent un panneau
SwiftUI intégré à une barre inférieure qui s'agrandit vers le haut. Samuel a
explicitement approuvé le plan présenté dans la conversation le 10 septembre.

## Scope and decisions

- Une seule livraison : panneau, contenus existants, coordination et validation.
- Une navigation personnalisée limitée à ce composant est autorisée par la
  demande et le plan approuvé. Contrôles, couleurs, typographie et matériaux iOS.
- Explorer, un second appui sur la commande active ou le fond ferment le panneau.
- Changer de commande remplace le contenu. Les longues listes défilent dans une
  hauteur bornée à l'espace disponible, y compris clavier et Dynamic Type.
- Firebase, schémas, règles et logique des actions de compte restent hors scope.
- Référence : https://github.com/rit3zh/expo-motion-tabs ; adapter le principe,
  sans dépendance React ni changement de page derrière le panneau.

## Affected files

- `wander/ContentView.swift` : carte persistante et coordination des présentations.
- `wander/MotionDockView.swift` : nouveau composant et état de sélection.
- `wander/FriendsPanelView.swift` : extraction du contenu et des actions Amis.
- `wander/ProfilePanelView.swift` : extraction du profil et de ses confirmations.
- `wanderUITests/` : tests ciblés du composant et de la carte.
- `wander/DebugSocialMapScenario.swift` : utiliser le composant réel dans le
  scénario local existant pour valider sans authentification ni données privées.
- Ce plan et `todos/` pour les constats de revue ; `docs/solutions/` seulement
  si un enseignement réutilisable est vérifié.
- Notes du vault `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Backlog features.md` (avancement), `Documentation technique.md` (navigation
  et composants), `Documentation UX.md` (navigation, Amis, Profil, accessibilité),
  `00 - Wander.md` (état du projet). Mettre à jour `updated` et les wikilinks.

## Implementation

- [x] Enregistrer l'approbation et l'état initial propre du dépôt.
- [x] Extraire les contenus Amis et Profil.
- [x] Construire la barre extensible et conserver la surface MapKit.
- [x] Coordonner les fiches, notifications, clavier et accessibilité.
- [x] Simplifier, compiler, tester les parcours autorisés et relire le diff.
- [x] Actualiser les quatre notes Obsidian et consigner les limites connues.

## Risks and validation

- Gestes concurrents : le fond du panneau absorbe le toucher de fermeture.
- Présentations imbriquées : fermer le panneau avant une fiche de carte ; garder
  les confirmations de compte attachées au profil tant qu'elles sont affichées.
- Rendu MapKit : ne pas conditionner ni identifier de nouveau la carte au changement
  de commande ; vérifier géométrie et caméra avant/après ouverture.
- Vérifier ouverture, fermeture, changement Amis/Profil, défilement, clavier,
  paysage, grande police, accessibilité et Réduire les animations/transparence.
- Compiler le schéma wander pour iOS Simulator et tester uniquement sur l'iPhone 17
  existant. Démarrage autorisé explicitement par Samuel dans la conversation.
  Aucun téléchargement ni nouvel appareil autorisé.
- Les quatre notes approuvées du vault ont été mises à jour avec extension
  d’accès accordée. Aucune copie ni vault de substitution créé.

## Review notes

- Décision principale : animation de la barre tout en conservant le slot MapKit.
- Alternative écartée : sheet système, qui ne transforme pas la barre de la vidéo.
- Incertitudes à lever : clavier dans le panneau et présentations sociales réelles.

## Résultats intermédiaires

- `ce-work` exécuté dans le checkout courant, sans commande Git mutante.
- `ce-simplify-code` : trois revues indépendantes. Dimensions du dock centralisées
  et constante UIKit utilisée dans le test AX5. Proposition de mutualiser les
  TimelineView existants écartée, car antérieure au changement et hors objectif.
- XcodeBuildMCP absent ; validation équivalente avec xcodebuild et simctl.
- Samuel a autorisé le démarrage de l'iPhone 17 installé, UUID
  `6F13855D-10B8-45AF-9205-17C8393379E3`, iOS 26.3. Aucun appareil créé/téléchargé.
- Première compilation : visibilité de `GhostModeStatusView` corrigée après son
  usage depuis le fichier Profil extrait. Compilations suivantes réussies.
- Les cinq tests MotionDock passent après plafonnement des symboles à xxxLarge et
  attente de la géométrie réelle après rotation. La police des contenus reste libre.
- Échec intermédiaire du test de rail en paysage : le test touchait Explorer
  pendant l’animation puis poursuivait avec Amis encore ouvert. Attendre le champ
  Code ami présent puis absent rétablit le test. Le hit-test UIKit reçoit bien le
  geste après fermeture ; les deux fichiers du rail restent inchangés.
- Contrôle visuel : titre de navigation doublé corrigé en masquant la barre à
  l’intérieur de chaque NavigationStack. Les six tests finaux passent.
- `ce-code-review` terminé, reçu `/tmp/ce-code-review/20260910-wander-motion-dock/review.json`.
  Deux P2 corrigés et relus : protection du flux de compte contre les notifications,
  et focus sur le titre du panneau. Revue externe indisponible ; examen adversarial
  local effectué. Les limites runtime sont consignées dans `todos/044-...`.
- Quatre notes Obsidian mises à jour, avec `updated` et ancres existantes conservées.

## Compound

Évaluation `ce-compound` : pas de nouvelle fiche dédiée. La propriété du brouillon,
la garde des confirmations et les attentes de test sont explicites dans le code,
les tests et ce plan. Une fiche supplémentaire répéterait ces sources sans ajouter
de raisonnement durable. Documentation skipped : aucun enseignement supplémentaire
ne franchit le seuil du skill.

## Validation finale

Commande exécutée le 10 septembre 2026 sur l’iPhone 17 installé :

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'platform=iOS Simulator,id=6F13855D-10B8-45AF-9205-17C8393379E3' \
  -disableAutomaticPackageResolution -parallel-testing-enabled NO \
  -only-testing:wanderUITests/MotionDockUITests \
  -only-testing:wanderUITests/MapSocialGestureUITests/testMapFillsWindowBehindMotionDock \
  test
```

Résultat : **TEST SUCCEEDED**, 6 tests, 0 échec, 115,861 secondes.
Journal : `/tmp/wander-motion-final.log`.
Résultat Xcode : `Test-wander-2026.09.10_12-42-38-+0900.xcresult` dans
`~/Library/Developer/Xcode/DerivedData/wander-gqqcsoaimwgfxrfahhazmsrqzcqx/Logs/Test/`.

- Ouverture Amis/Profil, remplacement du contenu, fermeture par commande active.
- Toucher extérieur consommé, vrai zoom et déplacement MapKit, caméra conservée.
- Clavier, changement de panneau pendant la saisie, brouillon conservé.
- Défilement jusqu’au dernier élément, confirmation annulée sans quitter Profil.
- Dynamic Type AX5, rotation et commandes accessibles dans les limites de la fenêtre.
- Carte plein écran, fiches redimensionnables et geste du rail après fermeture.
- Titres contrôlés, sans barre de navigation doublée.

Les captures portrait Amis et Profil ont été relues dans
`/tmp/wander-motion-final-captures/`. `app.screenshot()` tronquait les captures
paysage sur ce simulateur. Les helpers utilisent désormais `XCUIScreen.main`.
Les deux tests paysage ont été rejoués avec succès puis leurs captures relues
dans `/tmp/wander-motion-screen-captures/` : panneau Profil AX5 entièrement dans
la fenêtre, trois commandes visibles et rail ouvert dans la zone utile.
Journal : `/tmp/wander-motion-screen-captures.log` ; résultat
`Test-wander-2026.09.10_12-47-15-+0900.xcresult` dans le même dossier Xcode.

`git diff --check` passe. Aucun changement Git de l’index, des refs ou de l’historique.

Les avertissements déjà présents concernent les versions des extensions 15/27
face à l’app 38, l’initialiseur `init(traitsFrom:)` dans `MapDetailFittingText`,
et l’extraction AppIntents ignorée. Aucun nouveau warning de code dans le dock.

Le scénario local ne valide pas Firebase, la réauthentification Apple ni VoiceOver
vocal. Contrôles complémentaires dans `todos/044-ready-p2-valider-dock-sur-compte-reel.md`,
avec Réduire les animations et Réduire la transparence sur appareil. Aucun compte
réel supprimé ni règle Firebase modifiée.

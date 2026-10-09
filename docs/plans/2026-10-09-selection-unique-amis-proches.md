---
title: "Sélectionner un seul ami par toucher sur la carte"
status: completed
date: 2026-10-09
approved_at: 2026-10-09
completed_at: 2026-10-09
owner: Samuel
tags: [plan, mapkit, friends, gestures]
related:
  - ../solutions/2026-09-02-rendre-interactions-mapkit-immediates.md
---

# Sélectionner un seul ami par toucher sur la carte

## Résultat attendu

Toucher un ami parmi deux avatars proches ouvre uniquement son profil et ne
demande que sa position. Un deuxième toucher volontaire sur l'autre ami reste
possible immédiatement. Samuel a approuvé ce plan dans le chat le 9 octobre.

## Contexte

La vidéo fournie montre les deux indicateurs de chargement et une transition
entre deux fiches. L'observateur passif et le delegate MapKit activent les
annotations séparément. La protection actuelle absorbe uniquement un callback
du même objet annotation. Le service de localisation cible un seul ami par
appel. L'ordre réel des callbacks de la vidéo reste inconnu.

État initial : branche main, HEAD 9076c1047b9b1c82e8ae3b36312ee9d0706dcb72,
arbre propre. Aucune commande Git modifiante ne sera exécutée, conformément
aux consignes de Samuel. Aucun commit ni changement de branche n'est prévu.

## Périmètre et approche

Reproduire les deux ordres de livraison des callbacks au niveau du véritable
Coordinator. Attribuer un seul ami à chaque toucher avant les effets de
sélection et ignorer les activations concurrentes de ce toucher. Préserver
les nouvelles interactions, les groupes et les sélections programmatiques.
Ne pas modifier Firebase, les règles, les services de synchronisation ni les
temporisations des demandes de position.

## Fichiers concernés

- `wander/MapWithFogView.swift` : arbitrage des sélections d'un toucher.
- `wander/DebugSocialMapScenario.swift` : amis proches distincts et historique
  local des sélections du scénario de test.
- `wanderTests/MapSocialProximityControllerTests.swift` : régression utilisant
  le Coordinator de production et ses callbacks.
- `wanderUITests/MapSocialGestureUITests.swift` : toucher réel sur avatars proches.
- Ce plan, une solution réutilisable dans `docs/solutions/`, et un suivi
  priorisé dans `todos/` si la revue laisse des défauts ou validations en attente.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md` : correction des sélections d'amis.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md` : carte, arbitrage des callbacks et tests.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md` : un ami actualisé par toucher.

Mettre à jour `updated` pour chaque note Obsidian modifiée, préserver les
wikiliens. Aucun changement de vision ou de liens ne nécessite `00 - Wander.md`.

## Checklist

- [x] Approbation explicite du plan.
- [x] Reproduire les deux sélections et observer le test échouer avant correction.
- [x] Corriger l'arbitrage du toucher sans bloquer un nouveau toucher.
- [x] Ajouter et vérifier le scénario UI avec avatars proches distincts.
- [x] Simplifier puis relire les modifications.
- [x] Compiler et exécuter les tests ciblés et les régressions voisines ; résultats et limites ci-dessous.
- [x] Mettre à jour les notes Obsidian et enregistrer les preuves et enseignements.

## Risques et acceptation

- Filtrage trop large : vérifier les deux touchers successifs A puis B, les
  sélections programmatiques et les gestes de carte annulant un toucher.
- Ordre variable des callbacks : couvrir MapKit avant et après l'observateur.
- Test trop isolé : utiliser les callbacks de production et compter les IDs
  fictifs sortants, pas seulement le dernier profil visible.
- Aucun identifiant réel, secret ou position précise n'est journalisé.

La correction est acceptée lorsque chaque toucher produit un seul ami et
que les tests ciblés passent. Le résultat doit distinguer les tests réellement
exécutés des vérifications non disponibles.

## Validation prévue

XcodeBuildMCP indisponible : utiliser `xcodebuild`, `simctl` et les résultats
XCTest. L'iPhone 17 Pro déjà démarré est C0DADF07-7E14-4D5E-AE4B-B17844A9C454,
iOS 26.3. Ne démarrer, créer ou télécharger aucun simulateur ou runtime.
Exécuter sans parallélisme de simulateurs, avec taille de texte standard.
Pas de tests dédiés d'accessibilité.

## Revue et preuves

### Correction et reproduction

Les tests ont reproduit `[first, second]` et `[second, first]` pour un seul
toucher avec le Coordinator d'origine, selon l'ordre des callbacks natifs.
Le journal `/private/tmp/wander-nearby-red.log` contient ces assertions en
échec. Ce premier lancement a ensuite été interrompu pendant la collecte de
diagnostics consécutive à un plantage de nettoyage ; il ne constitue pas une
exécution complète réussie.

Le Coordinator attribue désormais la cible dès le début du toucher, la valide
au relâchement et absorbe les callbacks natifs concurrents. La protection dure
au maximum une seconde et ne se consomme pas au premier callback. Un nouveau
toucher, une annulation, un geste de carte, un démontage ou une autre sélection
explicite la libère. L'écho SwiftUI du même profil la conserve. Une sélection
native du voisin est rétablie vers la cible pour préserver le focus.

Huit tests de régression utilisent le vrai Coordinator, un MKMapView et les
callbacks de son observateur. Ils couvrent les deux ordres, l'unicité, deux
touchers successifs, l'annulation, les demandes programmatiques, le toucher
répété et l'expiration. Le test UI vérifie des cibles tactiles qui se
chevauchent et compte les sélections sortantes A puis B, avec une attente
détectant une éventuelle seconde activation tardive.

### Validation exécutée

Xcode 27, iPhone 17 Pro déjà démarré, iOS 26.3. Aucun nouveau simulateur ou
runtime installé ou démarré. Aucun test dédié d'accessibilité exécuté ; le
test existant consacré à la présentation accessible a été explicitement exclu.

Dernière commande exécutée sur les sources corrigées :

```bash
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'platform=iOS Simulator,id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' \
  -parallel-testing-enabled NO -disableAutomaticPackageResolution \
  -collect-test-diagnostics never \
  -resultBundlePath /private/tmp/wander-nearby-verified.xcresult \
  -only-testing:wanderTests/MapSocialProximityControllerTests \
  -skip-testing:wanderTests/MapSocialProximityControllerTests/testRefreshingSourcesPreservesGroupIdentityAndExpandedAccessibility \
  -only-testing:wanderUITests/MapSocialGestureUITests/testNearbyFriendTapSelectsOnlyThatFriendAndAllowsNextFriendTap \
  -only-testing:wanderUITests/MapSocialGestureUITests/testMixedGroupOpensFriendSheetOverMap \
  -only-testing:wanderUITests/MapSocialGestureUITests/testOpeningGroupAndClosingOnBackground \
  -only-testing:wanderUITests/MapSocialGestureUITests/testNativePanClosesGroupAndMovesMap \
  -only-testing:wanderUITests/MapSocialGestureUITests/testNativePinchAndDoubleTapZoom test
```

Résultats de `/private/tmp/wander-nearby-verified.log` :

- Compilation des cibles app et tests réussie, sans nouvel avertissement Swift.
- `git diff --check` réussit après les dernières modifications de documentation.
- Les 30 tests sélectionnés de `MapSocialProximityControllerTests` passent,
  dont les huit nouvelles régressions.
- Quatre parcours UI passent : amis proches (24,945 s), déplacement, zoom par
  pincement et double toucher, ouverture du groupe et fermeture sur le fond.
- `testMixedGroupOpensFriendSheetOverMap` ouvre la fiche mais échoue sur
  `Itinéraire.isHittable`, ligne 574. Ce cas précis n'a pas été comparé
  individuellement à la version d'origine : sa cause reste à établir.
- La commande complète termine donc avec **TEST FAILED**, code 65 :
  30 tests unitaires réussis et 4 parcours UI réussis sur 5. La suite élargie
  n'est pas déclarée verte.

Le lancement précédent `/private/tmp/wander-nearby-final.log` confirme les
mêmes 30 tests et quatre parcours réussis. Il révèle aussi deux défauts de la
classe caméra (assertion de géométrie et plantage mémoire), ainsi que
`testOwnProfileFromGroupThenFriendProfile` en échec sur `Itinéraire.isHittable`,
ligne 142. Les totaux après redémarrage du runner ne représentent pas toute
cette commande.

La comparaison à HEAD a repris les sources d'origine de `MapWithFogView.swift`
et des tests unitaires, en conservant les assertions UI existantes :

```bash
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'platform=iOS Simulator,id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' \
  -parallel-testing-enabled NO -disableAutomaticPackageResolution \
  -collect-test-diagnostics never \
  -resultBundlePath /private/tmp/wander-nearby-baseline-comparison.xcresult \
  -only-testing:wanderTests/MapFriendCameraControllerTests \
  -only-testing:wanderUITests/MapSocialGestureUITests/testOwnProfileFromGroupThenFriendProfile test
```

Elle reproduit exactement ces trois échecs avec le code d'origine, code 65.
Les sources corrigées ont ensuite été restaurées à l'identique et la dernière
commande ci-dessus les a recompilées. Aucune commande Git modifiante utilisée.

Capture du parcours des deux amis réussi :
`/private/tmp/wander-nearby-success-captures/BA1403F9-CB1A-4ADE-AF91-12BBE83EB975.png`.
Les journaux, captures et bundles `.xcresult` sont des preuves locales
temporaires. Les tests comptent les callbacks de sélection ; aucun envoi push
réel entre appareils n'a été exercé. Les services et leurs appels par ami
restent inchangés.

### Revue, limites et documentation

- Simplification : revues de réutilisation, qualité et efficacité effectuées ;
  retrait d'une variable inutilisée, accès privé à l'état interne, commentaire
  durable et vérification rapide de la sélection avant le parcours des annotations.
- Revue de correction et revue contradictoire locale : aucun défaut actionnable
  trouvé dans les quatre fichiers Swift. Reçu :
  `/private/tmp/compound-engineering-501/ce-code-review/20261009-022517-0011ce09/review.json`.
  Ce verdict porte sur le correctif, pas sur les défauts de validation existants.
- Le contrôle automatique a refusé l'export du diff privé vers Claude faute
  d'autorisation pour ce destinataire. Aucun travail externe n'a démarré ; la
  seconde revue s'est faite localement.
- [Suivi P2 caméra et destruction du cache](../../todos/073-ready-p2-diagnostiquer-tests-carte-xcode27.md) :
  la fixture conserve un Coordinator pour le processus et réinitialise l'état
  entre tests afin d'éviter le plantage de destruction observé. Sa cause reste
  inconnue et aucune correction de cache n'est incluse.
- [Suivi P2 Itinéraire après profil de groupe](../../todos/074-ready-p2-valider-itineraire-apres-profil-groupe.md) :
  distingue le cas reproduit avant correction du cas supplémentaire non comparé.
- Les avertissements préexistants AppIntents et de versions d'extensions restent
  hors périmètre ; le second point est déjà suivi dans
  [054](../../todos/054-ready-p2-aligner-build-extensions.md).
- Les trois notes Obsidian prévues ont été mises à jour dans le vault original,
  avec `updated: 2026-10-09T11:28:45+09:00` et les wikiliens préservés. Aucune
  ouverture d'Obsidian. `00 - Wander.md` reste inchangé.
- La solution existante sur les interactions MapKit a été enrichie ; sa
  validation de frontmatter et de références réussit. Aucun nouveau concept
  métier ni règle générale ne justifie une modification du glossaire ou d'AGENTS.md.

Le périmètre approuvé est terminé : unicité de la sélection et sélection
immédiate du second ami vérifiées. Les défauts distincts ci-dessus nécessitent
leur propre diagnostic et plan approuvé.

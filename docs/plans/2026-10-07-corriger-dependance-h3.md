---
title: Corriger la dépendance H3 refusée par Xcode
status: completed
date: 2026-10-07
approved_at: 2026-10-07
completed_at: 2026-10-07
owner: Samuel
tags: [plan, ios, dependencies, h3]
---

# Résultat attendu

Compiler Wander avec la même version de H3, sans l'erreur
`The package product 'H3-product' cannot be used as a dependency of this target because it uses unsafe build flags.`
Samuel a approuvé le plan présenté dans la conversation par « vasy ».

## Cause et périmètre

H3Swift 1.0.1, révision `f7c2e092dfd8b070458ffc05f599836fc6b09d18`,
déclare `.unsafeFlags(["-w"])` sur sa cible C `Ch3`. Le produit `H3`
en dépend. Xcode 27.0 refuse ce produit lors de la préparation du build.
Le journal `/private/tmp/wander-location-permissions-tests.log:481`
contient la reproduction initiale. Les versions publiées 1.0.0 et 1.0.1
contiennent ce réglage ; aucune version corrigée n'a été trouvée.

Copier les sources de cette révision dans `Vendor/H3Swift/`, retirer le
réglage de masquage des avertissements et ne conserver dans le manifeste
que le produit et les cibles de bibliothèque utilisés. Conserver les licences,
les en-têtes et la provenance. Les calculs H3, les appels Swift et les données
stockées ne changent pas. Aucun fork ni publication externe n'est nécessaire.

Hors périmètre : refonte de l'exploration, changement de version H3,
évolution Firebase, validation des dialogues de localisation sur appareil réel,
modification des préférences utilisateur, commit et push automatiques.

## État initial et contraintes

- HEAD : `4c07eed244b2b9365f6927d9d93c9cdb82f31487`, branche `main`.
- Modifications utilisateur préexistantes : `wander.xcodeproj/project.pbxproj`
  et `wander/Info.plist`, build 51 et déplacement de clés vers les réglages
  de build. Les conserver intégralement.
- Aucune commande Git mutante. Les règles du dépôt priment sur les branches,
  commits et mises à jour de plan automatiques des skills.
- Exécution native dans le checkout existant. Pas de configuration CE locale.
- Utiliser uniquement le simulateur iPhone 17 déjà démarré, sans démarrer,
  créer ou télécharger un appareil ou runtime. Pas de test dédié d'accessibilité.
- `Package.resolved` est actuellement ignoré ; Xcode peut l'actualiser localement
  pour retirer la dépendance distante H3. Ne pas modifier la politique des autres dépendances.

## Fichiers concernés

- `Vendor/H3Swift/Package.swift`, `Sources/**`, licences et notice de provenance.
- `wander.xcodeproj/project.pbxproj` : référence au paquet local.
- Le présent plan.
- `docs/plans/2026-10-07-autorisation-localisation-arriere-plan.md` : résultats du build débloqué.
- `todos/071-ready-p2-valider-autorisation-arriere-plan.md` : validation restante précise.
- `todos/072-done-p2-eliminer-avertissements-macros-h3.md` : constat de revue corrigé dans le manifeste.
- `docs/solutions/2026-10-07-h3swift-unsafe-build-flags.md` : cause, correction et entretien.
- Dans `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/` :
  `Backlog features.md`, `Documentation technique.md`, `Documentation UX.md`.
  Actualiser les sections de dépendances/validation et leur propriété `updated`,
  conserver les wikiliens, ne pas ouvrir Obsidian.

## Mise en œuvre

- [x] Diagnostiquer en lecture seule et obtenir l'approbation.
- [x] Confirmer le build en échec avant correction.
- [x] Copier les sources et licences, documenter la révision et le delta du manifeste.
- [x] Remplacer la référence distante par le paquet local dans Xcode.
- [x] Vérifier l'identité des sources copiées, les licences, le manifeste et le diff.
- [x] Compiler en Debug pour simulateur et Release pour appareil sans signature.
- [x] Exécuter `wanderTests/LocationTrackerTests` dans l'application complète.
- [x] Vérifier l'ouverture de la carte sur le simulateur existant et conserver une capture.
- [x] Simplifier, relire et documenter les résultats et les limites.
- [x] Actualiser les trois notes Obsidian autorisées.

## Risques et validation

La copie locale représente environ 465 Ko de sources. Les futures mises à jour
de H3 devront être explicites et conserver la provenance et les licences.
Retirer `-w` peut exposer des avertissements C : examiner les diagnostics,
sans masquer globalement les avertissements. Conserver exactement les sources
de calcul, vérifier leurs empreintes et maintenir les chemins d'en-têtes.

Pas de nouveau test unitaire du manifeste : la compilation Xcode est le contrôle
qui détecte réellement ce défaut de dépendance. Réutiliser les sept tests de
localisation existants sans extraire la logique dans un paquet temporaire.
Les tests de logique ne prouvent pas que les dialogues iOS et l'autorisation
« Toujours » fonctionnent sur un téléphone réel.

Acceptation : absence de l'erreur H3, builds simulateur et appareil réussis,
tests de localisation intégrés réussis, carte ouverte sans régression visible,
sources H3 identiques à la révision approuvée et documentation à jour.

## Revue

- Décision : conserver le moteur existant dans un paquet local débarrassé du réglage refusé.
- Alternative écartée : épingler une révision en conservant `unsafeFlags` ; l'exception
  SwiftPM ne garantit pas le comportement de la cible Xcode.
- Alternative écartée : modifier le cache DerivedData, changement non reproductible.
- Incertitude avant validation : autres diagnostics de compilation éventuellement révélés.

## Preuves

Reproduction avant correction :

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build
```

Échec 65 avec le message H3 exact, ligne 396 de
`/private/tmp/wander-h3-fix/baseline.log`. Xcode 27.0, build 27A266a.
Les 46 fichiers de `Sources/` copiés ont été comparés octet par octet
au checkout propre de la révision approuvée. Empreintes de contrôle :
`/private/tmp/wander-h3-fix/source-checksums.json`.

Première compilation locale Debug : réussie (`debug-build.log`). Elle révèle
37 avertissements C `-Wambiguous-macro` auparavant masqués par `-w`.
Les constantes `M_PI` et `M_PI_2` sont définies par les fallbacks H3 avant
l'import du module Darwin. Les deux écritures ont les mêmes valeurs binary64.
Une compilation ciblée de `polygon.c`, avec les options exactes du build,
reproduit deux avertissements ; les deux `CSetting.define` correspondants
les suppriment sans changer les sources ni masquer les diagnostics.
Preuves : `before-defines.log` et `with-defines.log` dans le dossier de validation.
Le manifeste définit désormais ces deux constantes avec les littéraux Darwin.

Premier passage des tests intégrés : sept tests de localisation et un test UI
de carte réussis, résultat `integration-tests.xcresult`. Relance effectuée après
la correction des avertissements dans le manifeste.

### Validation finale

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'platform=iOS Simulator,id=C0DADF07-7E14-4D5E-AE4B-B17844A9C454' -parallel-testing-enabled NO -disableAutomaticPackageResolution -resultBundlePath /private/tmp/wander-h3-fix/final-tests.xcresult -only-testing:wanderTests/LocationTrackerTests -only-testing:wanderUITests/MotionDockUITests/testEventsButtonStaysCenteredAcrossRepeatedListToggles test
xcodebuild -project wander.xcodeproj -scheme wander -configuration Release -destination 'generic/platform=iOS' -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
```

- Debug : compilation réussie et `TEST SUCCEEDED`, huit tests effectivement
  exécutés, huit réussis, zéro échec, zéro test ignoré. Sept tests de localisation
  et `testEventsButtonStaysCenteredAcrossRepeatedListToggles` en 19,902 s.
- Release appareil : `BUILD SUCCEEDED`, sans signature. Ce n'est pas une archive
  signée, une installation sur téléphone ni une publication.
- Les 19 fichiers C H3 ont été recompilés dans les deux passages finaux.
  Aucun avertissement C/Swift H3 ni aucune erreur de build. Les diagnostics
  AppIntents sans dépendance et les versions d'extensions 15/27 face à l'app 51
  sont préexistants ; ces derniers restent suivis dans `todos/054-ready-p2-aligner-build-extensions.md`.
- Journaux : `/private/tmp/wander-h3-fix/final-tests.log` et `release-build.log`.
- Résultat XCTest : `/private/tmp/wander-h3-fix/final-tests.xcresult`.
- `plutil -lint wander.xcodeproj/project.pbxproj` et `git diff --check` : succès.
- Comparaison structurée du projet avec le snapshot avant travail : seul
  l'objet de référence H3 change. `wander/Info.plist` est inchangé octet par octet.
- Les 46 empreintes des sources correspondent à la révision approuvée.
  `Package.resolved` local ne contient plus de dépendance distante H3.

### Résultats simulateur

- Projet : `wander.xcodeproj`. Scheme : `wander`.
- Simulateur : iPhone 17 Pro déjà démarré, UUID
  `C0DADF07-7E14-4D5E-AE4B-B17844A9C454`, iOS 26.3.1.
- Build : succès. Écrans vérifiés : carte et liste d'événements, scénario local.
- Carte : PASS, vrai composant `MapWithFogView` / `MKMapView`.
- Ouvertures/fermetures de liste : PASS, quatre cycles et assertions de centrage.
- Captures extraites et inspectées dans `/private/tmp/wander-h3-fix/captures/` :
  `D43F51FC-55FD-44E3-918B-796782C70A65.png` et
  `E8864B35-3742-414E-8B38-4722881F1C39.png`.
- Erreurs console attribuables à ce parcours dans le journal capturé : 0.
  Aucun runtime warning signalé par le résumé XCTest.
- Vérifications humaines demandées : 0. Échecs résiduels : 0. Résultat : PASS.
- Limites : données locales, pas de parcours authentifié ni de nouvelles
  positions réelles ou de dialogues de permission. Ces derniers restent
  dans le constat 071, hors du périmètre de correction H3.

### Revue et documentation

- `ce-simplify-code` : précontrôle terminé, uniquement dépendance/configuration,
  sources tierces inchangées et documentation ; rien à simplifier.
- `ce-code-review` : revue légère du delta H3 et des documents autorisés, avec
  critères `AGENTS.md`, contrôle de provenance, chemins et builds réels.
  Une lecture indépendante du manifeste a trouvé les avertissements de macros,
  corrigés puis revalidés ; constat clos dans le todo 072. Aucun autre défaut
  exploitable ni constat restant introduit par ce correctif.
- Reçu de revue : `/private/tmp/compound-engineering-501/ce-code-review/h3-local-package-20261007/review.json`.
- `ce-compound` en mode léger non interactif : note de résolution créée,
  frontmatter valide, chemins/liens vérifiés. Le SHA cité appartient au dépôt
  upstream et a été vérifié dans son checkout et les tags publics. Pas de
  nouvelle entrée de vocabulaire : seuls des termes généraux de compilation.
  Les règles existantes rendent déjà `docs/solutions/` découvrable.
- Trois notes Obsidian mises à jour à `2026-10-07T16:38:44+09:00`, wikiliens
  préservés. Obsidian n'a pas été ouvert.
- Aucune source Swift de l'application modifiée ; aucune commande Git mutante,
  aucun commit ou push effectué.

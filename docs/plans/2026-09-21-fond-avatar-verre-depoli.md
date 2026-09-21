---
title: Fond de l’avatar avec flou léger
status: completed
date: 2026-09-21
approved_at: 2026-09-21
completed_at: 2026-09-21
approval: "je valide"
owner: Samuel
---

## Résultat et périmètre

Remplacer le fond illustré des fiches utilisateur par la carte topographique colorée fournie
par Samuel. Conserver un flou léger de 3 points sur l’image seulement,
pour faire ressortir l’avatar sans le flouter.
Conserver les dimensions, le recadrage centré et la découpe autour du nom.
Aucun changement de navigation, de données ou de contrôles.

## Ajustement approuvé : carte topographique colorée

Samuel a fourni une illustration topographique colorée et approuvé son
remplacement par « je valide » le 21 septembre. Remplacer uniquement le PNG
de l’asset existant, conserver le flou de 3 points, le recadrage et le masque.
Actualiser ce plan et la note Obsidian `Documentation UX.md`.

- [x] Plan de remplacement présenté et explicitement approuvé.
- [x] Copier l’image topographique à l’identique dans l’asset existant.
- [x] Vérifier l’asset et compiler sans lancer le simulateur.
- [x] Actualiser la note UX et consigner les contrôles.

Le recadrage visuel reste non vérifié, conformément à la demande de ne pas
tester sur simulateur. Aucun changement Swift ni nouveau test nécessaire.

Validation du fond topographique :

- SHA-256 source et asset identiques :
  `f21965af479afc555e3cec21c1d0e280ceea611d251396085fc60a2cd37b69cd`.
- Manifeste JSON valide, fichier référencé présent, flou de 3 points conservé.
- Compilation avec la commande `xcodebuild ... build` documentée ci-dessous :
  `BUILD SUCCEEDED`, sortie 0, journal `/tmp/wander-avatar-topography-build.log`.
  Seuls les avis AppIntents préexistants apparaissent.
- `git diff --check` réussi. Note UX actualisée avec la propriété `updated`,
  wikilinks conservés, sans ouvrir Obsidian.
- Revue manuelle de ce remplacement d’asset : aucun défaut actionnable, aucun
  code à simplifier, aucun constat à ajouter dans `todos/` et aucun nouvel
  apprentissage justifiant une note de solution.
- Aucun test, lancement ou capture sur simulateur ; rendu visuel non vérifié.

## Ajustement précédent : illustration de ville

Samuel a fourni une illustration de ville nocturne et approuvé explicitement
son remplacement par « je valide » le 21 septembre. Seuls l’asset et les
documents de suivi changent ; le Swift conserve le flou de 3 points, le
recadrage centré et le masque actuels.

- [x] Plan de remplacement présenté et explicitement approuvé.
- [x] Copier l’illustration de ville à l’identique dans l’asset existant.
- [x] Vérifier le hash, le manifeste et compiler sans lancer le simulateur.
- [x] Actualiser la note UX et consigner les contrôles.

Le recadrage et l’intensité du flou ne seront pas vérifiés en exécution.

Validation de ce remplacement :

- SHA-256 source et asset identiques :
  `f1705bad0be81aa61f7d698cdb0751e4c20096312c2dcb5fa53fac334a1c15ff`.
- Manifeste JSON valide et fichier référencé présent. Aucun changement Swift
  pendant cet ajustement ; flou de 3 points et masque conservés.
- Même commande `xcodebuild ... build` que ci-dessous : `BUILD SUCCEEDED`,
  sortie 0, journal `/tmp/wander-avatar-city-build.log`. Seul l’avis AppIntents
  préexistant apparaît ; aucun nouvel avertissement lié à l’asset.
- `git diff --check` réussi. Note UX actualisée, propriété `updated` comprise,
  sans modifier les wikilinks ni ouvrir Obsidian.
- Revue manuelle du remplacement d’asset : aucun défaut actionnable, aucun
  code à simplifier, aucun constat à créer dans `todos/` ni nouvelle leçon
  réutilisable. Aucun test, lancement ou capture sur simulateur.

## Ajustement approuvé : flou à la place du verre dépoli

Samuel a demandé de remplacer le verre dépoli par un flou léger, puis a
explicitement approuvé le plan avec « je valide » le 21 septembre.
Cet ajustement remplace uniquement l’overlay de matériau par `.blur(radius: 3)`
avant le masque existant. Le fichier image reste identique.

- [x] Présenter puis approuver le plan d’ajustement avant modification.
- [x] Remplacer le matériau par un flou de 3 points sur le fond.
- [x] Relire le placement du flou et du masque, puis compiler sans simulateur.
- [x] Mettre à jour la note UX et consigner les contrôles.

Changement trivial d’un modificateur visuel : simplification et revue locales,
sans nouveau test automatisé. Le rendu en exécution n’est pas vérifié,
conformément à la demande de Samuel de ne pas tester sur simulateur.

## Fichiers concernés

- `wander/Assets.xcassets/ProfileCardBackground.imageset/ProfileCardBackground.png`
- `wander/FriendProfileSheet.swift`
- `docs/plans/2026-09-21-fond-avatar-verre-depoli.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`
  : présentation de la fiche utilisateur et propriété `updated`.

## Mise en œuvre initiale du verre dépoli

- [x] Plan proposé puis approuvé explicitement avant toute modification.
- [x] Copier l’image fournie sans modifier ses pixels.
- [x] Superposer le verre dépoli sous l’avatar, avant le masque existant.
- [x] Simplifier et relire le changement.
- [x] Compiler et vérifier l’asset ainsi que le diff.
- [x] Actualiser la note UX et consigner la validation.

## Risques et validation

Le flou doit rester limité au fond découpé. Le masque est appliqué après
le flou afin de préserver le contour du nom. L’avatar et le nom restent hors
de cet effet. L’intensité visuelle reste à apprécier.

Samuel a précisé après approbation : « pas besoin de tester sur le simulateur ».
Validation par compilation iOS Simulator générique uniquement, contrôle du hash
de l’image et revue du diff. Aucun lancement, capture ni test sur simulateur.
Le rendu visuel ne sera donc pas affirmé comme vérifié.
Pas de test ajouté pour ce changement purement visuel ; les tests existants de
`FriendProfilePresentationTests` concernent la mesure et la présentation,
dont les contrats sont conservés.

Exécution native inline dans le checkout courant, propre au démarrage.
Les instructions du projet interdisent les commandes Git modificatrices :
aucune branche créée, aucun commit et aucune publication.

## Critères d’acceptation

- L’asset embarqué est identique à l’image fournie.
- Le flou ne couvre que le fond et conserve le masque du nom.
- La compilation réussit sans nouvel avertissement lié au changement.
- La documentation reflète le résultat et les limites de validation.

## Validation initiale du verre dépoli, avant remplacement

- Image copiée à l’identique, SHA-256 source et asset :
  `b5d036891a6a49948ca96a576baecb68328da113163d5c38aa21198babb98997`.
  Manifeste JSON valide et nom d’asset conservé.
- `ce-simplify-code` : trois passes indépendantes de réutilisation, qualité et
  efficacité, aucun constat ni changement supplémentaire.
- Compilation autorisée, exécutée sans test ni lancement de simulateur :
  `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug
  -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution
  -skipPackageUpdates CODE_SIGNING_ALLOWED=NO build`.
  `BUILD SUCCEEDED`, sortie 0, journal `/tmp/wander-avatar-frost-build.log`.
  La première tentative était bloquée par les accès aux caches Xcode ;
  la relance avec les accès nécessaires a réussi.
- Aucun avertissement Swift. Avis préexistants AppIntents sans dépendance et
  versions d’extensions 27/15 différentes de celle de l’application 42.
- `git diff --check` réussi. Aucun changement Git modificatif.
- Note Obsidian `Documentation UX.md` actualisée, propriété `updated` comprise,
  sans ouvrir Obsidian ni modifier les wikilinks.
- Aucun test ou rendu sur simulateur, conformément à la précision de Samuel.
  L’intensité visuelle du matériau n’est pas validée en exécution.
- `ce-code-review` terminé : correction, règles du projet et SwiftUI,
  aucun constat actionnable. Reçu `status: complete` dans
  `/tmp/wander-avatar-frost-review/review.json`.
  Aucun constat à ajouter dans `todos/`.
- Compound : aucune nouvelle leçon réutilisable pour ce remplacement d’asset
  et cet overlay natif ; pas de note de solution supplémentaire.

## Validation de l’ajustement au flou

- Overlay de matériau supprimé. Le seul effet restant sur l’image est
  `.blur(radius: 3)`, avant le masque. Avatar et nom sont des vues sœurs
  du fond et ne reçoivent pas ce modificateur. Dimensions conservées.
- Simplification et revue manuelles du changement trivial : aucune abstraction
  supplémentaire utile, aucun défaut actionnable et aucun constat à ajouter
  dans `todos/`. Le reçu de revue précédent concerne le verre dépoli seulement.
- Compilation avec la même commande `xcodebuild ... build` ci-dessus :
  `BUILD SUCCEEDED`, sortie 0. Journal `/tmp/wander-avatar-blur-build.log`.
  Aucun nouvel avertissement lié au changement.
- `git diff --check` réussi. Note Obsidian `Documentation UX.md` mise à jour,
  propriété `updated` comprise et wikilinks conservés.
- Aucun test, lancement ou capture sur simulateur. Rendu visuel non vérifié.
- Pas de nouvel apprentissage réutilisable justifiant une note de solution.

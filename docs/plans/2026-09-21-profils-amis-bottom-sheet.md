---
title: "Profils amis en bottom sheet native"
status: completed
date: 2026-09-21
owner: Samuel
approved_at: 2026-09-21
completed_at: 2026-09-21T11:02:54+09:00
approval: "je valide, dans la conversation Codex"
tags: [plan, ios, friends]
---

# Profils amis en bottom sheet native

## Résultat et périmètre

Remplacer le profil d'ami qui découpe la carte par une feuille native superposée,
ouverte depuis les pins et la liste Amis. Avatar visible, nom et statut, informations
de localisation en deux colonnes et bouton Itinéraire pleine largeur. Hauteur initiale
adaptée au contenu, agrandissement et fermeture par glissement. La carte conserve
ses dimensions derrière la feuille et reste interactive à la hauteur compacte.

Composition inspirée de la référence fournie, avec les composants et couleurs iOS.
Aucun changement au profil du compte, au modèle de données, à Firebase ou au contenu
des événements. Le découpage propre aux événements est conservé.

## Fichiers concernés

- `wander/ContentView.swift` : présentation unique, sélection et passage vers Itinéraire.
- `wander/FriendProfileSheet.swift` : contenu partagé, mesure et présentation native.
- `wander/MapDetailSplitView.swift` : masquer temporairement les événements sans réinitialiser leur hauteur, correctif d’intégration issu de la revue.
- `wander/DebugSocialMapScenario.swift` : même présentation avec données locales.
- `wanderUITests/MapSocialGestureUITests.swift` et `wanderUITests/MotionDockUITests.swift` : adapter les attentes existantes qui décrivaient le découpage remplacé.
- `docs/plans/2026-09-21-profils-amis-bottom-sheet.md` : suivi et validation.
- `todos/` : constats prioritaires éventuels lors de la revue.
- `docs/solutions/` : enseignement réutilisable si confirmé.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md` : état de la refonte des fiches amis.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md` : fiches et carte partagée, ouverture depuis Amis.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md` : carte, présentation des profils et sélection.

## Mise en œuvre

- [x] Remplacer les deux contenus par une fiche réutilisable et sa présentation native.
- [x] Unifier les points d'entrée et supprimer l'activation du découpage pour les amis.
- [x] Adapter le scénario local et conserver les états fantôme, ancien, indisponible.
- [x] Simplifier et relire les changements.
- [x] Compiler l’application et les cibles de tests, sans exécution selon la restriction de Samuel.
- [x] Mettre à jour les trois notes Obsidian et leur propriété `updated`.

## Risques et critères d'acceptation

- Fermer la feuille avant le choix d'application Itinéraire ; revérifier que la position
  et l'amitié sont toujours disponibles au moment de l'action.
- Maintenir le pin sélectionné en cohérence avec la fiche ; supporter le changement
  d'ami, la fermeture interactive et la transition vers les événements.
- Le mode fantôme ne révèle aucune localisation et désactive Itinéraire.
- Une position ancienne reste utilisable avec une explication explicite.
- Aucun texte coupé à la taille standard ; bouton Itinéraire visible à l'ouverture.
- Ouverture compacte, extension et fermeture natives ; carte sans panneau de profil intégré.

## Validation autorisée

Samuel a choisi « Non, limiter la validation à la compilation ». Les critères
visuels et gestuels décrivent le comportement visé ; ils ne font pas l’objet
d’une validation exécutée dans ce travail. Aucun simulateur n’est démarré, aucun
test ni capture n’est exécuté. Compiler l’application et les cibles de tests
existantes dont les attentes de présentation ont été adaptées. Les contrôles
fonctionnels à taille standard restent consignés pour une validation ultérieure
explicitement autorisée ; aucun contrôle d’accessibilité dédié n’est ajouté.

## Validation et revue

- État initial : arbre de travail propre.
- Aucun simulateur n’était démarré. Samuel a confirmé la restriction à la compilation.
- Les tests UI existants sont adaptés et compilés ; aucun résultat fonctionnel n’est revendiqué.
- Aucun commit ni autre commande Git modificatrice dans ce travail.

### Simplification

Trois revues indépendantes `ce-simplify-code` terminées. Suppression d’un relais
inutile entre les points d’entrée ; constante unique pour la hauteur de départ.
Aucun problème d’efficacité identifié. Le regroupement des paramètres dans un
nouveau type de présentation est écarté : les deux appels existants restent
explicites et cohérents, sans nouvelle abstraction nécessaire.

### Documentation

Les trois notes Obsidian prévues ont été mises à jour avec leur propriété
`updated`. L’accès en écriture ciblé a été accordé. Aucun problème d’accès
ne subsiste. Obsidian n’a pas été ouvert.

### Capitalisation

Évaluation `ce-compound` : pas de nouvelle note de solution. La sélection unique
et le passage par `onDismiss` sont explicités dans le code et la documentation
technique. Le rendu n’est pas vérifié en exécution ; aucune conclusion gestuelle
ne peut devenir un enseignement validé.

### Compilation

- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution -skipPackageUpdates CODE_SIGNING_ALLOWED=NO build` : `BUILD SUCCEEDED`.
- Même commande avec `build-for-testing` : `TEST BUILD SUCCEEDED` pour l’application, `wanderTests` et `wanderUITests`.
- Une dernière compilation `build-for-testing` après simplification et correction de la restauration de hauteur réussit aussi, le 21 septembre à 10:56:48 KST.
- Journaux : `/tmp/wander-friend-sheet-build.log`, `/tmp/wander-friend-sheet-test-build.log`, `/tmp/wander-friend-sheet-final-build.log`.
- Aucun avertissement Swift. Avertissements d’extraction AppIntents sans dépendance au framework ; versions d’extensions 15/27 contre 42 déjà suivies dans `todos/054-ready-p2-aligner-build-extensions.md`. Aucun fichier de versions modifié.
- `git diff --check` : succès.
- XcodeBuildMCP n’est pas exposé dans cette session ; le contrôle de compilation utilise directement Xcode CLI. Aucun test ni lancement de simulateur, conformément à la restriction de Samuel.
- Couverture fonctionnelle différée consignée dans `todos/060-ready-p2-valider-profils-bottom-sheet.md`.

### Correction issue de la revue

La liaison qui masquait les événements en exposant `false` déclenchait leur
réinitialisation à la hauteur du tiers. Le conteneur distingue désormais
`areEventsObscured` de l’état d’ouverture réel. Le masquage conserve la hauteur
et le défilement, conformément au périmètre approuvé. Le test existant de
restauration utilise maintenant une hauteur personnalisée pour couvrir ce cas.
Il est compilé sans exécution.

### Revue finale

`ce-code-review` : revue locale du diff, avec contrôles indépendants de correction,
Swift/iOS, tests, standards, maintenance et enseignements existants. La régression
de hauteur des événements identifiée pendant la revue est corrigée et sa correction
est confirmée par la validation de source indépendante. Aucun autre défaut
actionnable retenu. L’ancienne branche générique de détail reste dans le conteneur
partagé pour éviter un nettoyage étendu sans lien nécessaire avec cette refonte.

Reçu de revue : `/tmp/compound-engineering-501/ce-code-review/friend-bottom-sheet-761929b4/`.
La compilation réussie ne valide pas le rendu ni les gestes. Le plan est terminé
dans le périmètre de validation restreint par Samuel ; le suivi 060 conserve
la couverture fonctionnelle non exécutée.

Décision principale : une sélection d’ami unique pilote le pin et la feuille.
Le panneau intégré et le formulaire séparé sont remplacés par le même contenu.
Incertitude restante : hauteur réelle de présentation et transitions natives
sur appareil, sans observation en exécution dans cette session.

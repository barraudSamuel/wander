---
title: Liste des amis sous la carte
status: completed
approved_at: 2026-09-22
completed_at: 2026-09-22
---

# Résultat approuvé

Samuel approuve le plan avec « je valide » le 22 septembre. Amis ouvre une
liste pleine largeur dans la moitié basse de l’écran ; la carte reste active
au-dessus. Réutiliser la séparation et les gestes des événements. Gérer demandes
reçues, acceptation/refus, invitations en attente et amis dans cette liste.
Le code ami et l’ajout restent dans le profil, conformément au travail précédent.

## Périmètre

Une seule étape d’implémentation, dans le checkout existant. Aucun changement Git
mutatif ni publication. Préserver tous les changements non commités de la tâche
précédente. Copie de référence du début de cette tâche dans
`/tmp/wander-friends-split-baseline` pour isoler les nouvelles modifications.

### Fichiers

- `wander/MapDetailSplitView.swift` : séparation commune et hauteur par liste.
- `wander/MotionDockView.swift` : barre native, suppression du panneau superposé.
- `wander/ContentView.swift` : sélection de liste, routage et actions sociales.
- `wander/FriendsPanelView.swift` : liste et demandes dans la zone basse.
- `wander/DebugSocialMapScenario.swift` : scénario local de la nouvelle navigation.
- `wanderUITests/MotionDockUITests.swift`, `MapSocialGestureUITests.swift`,
  `wanderTests/MapViewportViewTests.swift` : navigation et géométrie.
- Ce plan et les constats de revue nécessaires dans `todos/`.
- Vault `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Backlog features.md`, `Documentation UX.md`, `Documentation technique.md`,
  `00 - Wander.md`, propriété `updated` comprise.

## Approche

Utiliser une sélection exclusive de liste basse : aucune, événements ou amis.
Conserver la carte et les deux listes montées pour préserver leur état. Une
seule liste est visible et interactive. Amis s’ouvre à 50 % de la hauteur utile,
Événements garde sa hauteur initiale actuelle. Conserver la hauteur choisie de
chaque liste pendant les passages de l’une à l’autre. Explorer, un second appui
sur Amis ou la poignée ferment la liste ; un toucher sur la carte ne la ferme pas.
Une fiche individuelle masque temporairement la liste puis retrouve son état.
Les notifications de demandes ouvrent la liste Amis. Services et modèles inchangés.

## Travail

- [x] Partager la séparation et supprimer le panneau Amis qui bloque la carte.
- [x] Intégrer les amis, leurs actions et les transitions avec les événements/profils.
- [x] Adapter le scénario, les tests de navigation et de géométrie existants.
- [x] Simplifier et relire localement le diff ; compiler app et cibles de tests.
- [x] Mettre à jour les quatre notes Obsidian et consigner les validations.

## Risques et validation

La carte doit conserver sa taille native de rendu pendant le changement de
fenêtre visible. Vérifier cadrage, gestes, fermeture, défilement indépendant et
retour après une fiche. Préserver les demandes et confirmations en cours.
Tester alternance Amis/Événements, hauteur propre à chaque liste, absence de
superposition, demandes reçues/en attente, retrait et navigation depuis un ami.

Compilation par `xcodebuild ... build-for-testing`, cache existant, sans nouvelle
dépendance. Au début du travail, `simctl list devices booted` confirme uniquement
l’iPhone 16e. Aucun iPhone 17 démarré : ne pas démarrer ni utiliser un autre
simulateur. Les tests sont adaptés et compilés ; aucune exécution UI ni cycle
rouge/vert n’est revendiqué sans appareil autorisé. Aucun test d’accessibilité dédié.

## Acceptation

- Amis occupe environ la moitié basse à l’ouverture avec une carte interactive.
- Poignée, réduction/agrandissement et fermeture fonctionnent comme les événements.
- Une seule liste visible ; états, hauteurs et défilements préservés au changement.
- Invitations et amis gardent leurs actions ; code et ajout restent dans le profil.
- App et cibles de tests compilent ; limites UI et revue documentées.

## Validation et revue

Les quatre notes Obsidian ont été mises à jour avec `updated` au
2026-09-22T17:22:05+09:00. La validation fonctionnelle restante est suivie dans
`todos/062-ready-p2-valider-amis-sous-carte.md` ; elle couvre les gestes, les
transitions et les actions sociales avec de vrais comptes de test.

La simplification locale a conservé la structure native de la carte, rendu la
sélection de liste exclusive et réduit les états du scénario d’invitation.
Les calculs de résumés d’amis existaient déjà avant cette tâche : aucune couche
de cache supplémentaire n’est ajoutée.

Compilation finale du code et des cibles de tests réussie :

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build-for-testing
```

Résultat : `TEST BUILD SUCCEEDED`, code de sortie 0, journal
`/tmp/wander-friends-split-build.log`. Aucun diagnostic Swift ; un avertissement
de l’outil de métadonnées AppIntents pour une cible sans cette dépendance.
`git diff --check` passe. Les propriétés `updated` et les liens au plan des
quatre notes Obsidian ont été vérifiés.

Les sept relectures locales (correction, SwiftUI, tests, standards, structure,
contre-analyse et solutions antérieures) ne retiennent aucun défaut à corriger.
Synthèse :
`/tmp/compound-engineering-501/ce-code-review/20260922-friends-split/synthesized-findings.json`.
Reçu final : `review.json` dans le même dossier. Le coordinateur a rencontré
une limite de capacité du modèle après la synthèse complète ; le reçu a été
enregistré directement depuis cette synthèse par l’agent principal, sans
revendiquer de vérification supplémentaire.
La revue porte sur les huit fichiers de cette tâche, comparés à leur copie
initiale pour exclure le déplacement antérieur des invitations dans le profil.
Aucun code exporté, aucun service externe de revue utilisé. Aucune exécution
de tests sur simulateur ni capture UI n’est revendiquée. L’implémentation est
terminée ; les vérifications fonctionnelles restantes sont consignées dans le
constat 062.

Un constat P2 sur les tests a été corrigé : la liste native reste montée
lorsqu’elle est masquée ; les assertions attendent désormais son état interactif
au lieu d’exiger sa disparition de l’arbre XCTest. Ce point reprend la solution
existante `docs/solutions/2026-09-10-conserver-liste-sous-fiche-carte.md`.
Constat corrigé : `todos/063-done-p2-attendre-visibilite-liste-amis.md`.
Aucune nouvelle solution distincte n’est nécessaire pour ce même principe.

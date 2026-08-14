---
status: completed
approved_at: 2026-08-14
completed_at: 2026-08-14
---

# Avatars dans les pins de carte

## Outcome

Afficher l’avatar prédéfini de chaque utilisateur au centre de sa pin de carte, à la place de la couleur de profil et de l’initiale.

## Scope

- Afficher l’avatar du compte courant dans sa pin.
- Afficher l’avatar synchronisé de chaque ami dans sa pin.
- Actualiser une pin quand l’avatar correspondant change.
- Conserver la forme, l’ombre, le texte circulaire de présence et l’opacité des positions anciennes.
- Utiliser un avatar embarqué valide comme solution de repli.

## Non-goals

- Modifier les avatars disponibles ou leur stockage Firestore.
- Modifier les couleurs des zones explorées ou des sorties prévues.
- Déployer Firebase ou publier une version TestFlight.

## Dependencies

- Le catalogue `ProfileAvatar` et ses assets embarqués.
- Le champ `avatarID` déjà synchronisé dans les profils Firestore.

## Affected files

- `wander/MapWithFogView.swift`
- `wander/ContentView.swift`
- `wander/FriendSyncService.swift`
- `docs/solutions/2026-08-14-afficher-avatars-dans-pins-carte.md`

## Implementation checklist

- [x] Faire porter `avatarID` par les positions d’amis publiées.
- [x] Transmettre l’avatar local à `MapWithFogView`.
- [x] Remplacer la vue d’initiale par une image circulaire.
- [x] Mettre à jour les vues réutilisées lorsque l’avatar change.
- [x] Préserver les états de fraîcheur, les callouts et l’accessibilité.
- [x] Compiler l’app sans avertissement nouveau.
- [x] Vérifier le rendu sur l’iPhone 17 Simulator déjà démarré.
- [x] Effectuer la revue finale et documenter la solution.

## Risks

- Une annotation MapKit réutilisée pourrait conserver l’avatar d’un autre utilisateur si sa configuration n’est pas réinitialisée.
- Un identifiant absent pendant le chargement pourrait laisser une pin vide.
- Le changement d’avatar doit rafraîchir une annotation existante sans exiger un changement de position.

## Validation

- `xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/wander-derived-data -disableAutomaticPackageResolution build` : succès.
- Vérification statique : `avatarID` est propagé pour le compte et les positions d’amis, et les anciennes vues d’initiale ne sont plus référencées.
- Contrôle visuel sur l’iPhone 17 Simulator iOS 26.3 : avatar circulaire net dans la pin, bordure blanche et ombre conservées, aucune initiale.
- `git diff --check` : succès.
- Revue finale : aucun défaut nécessitant un fichier `todos/` supplémentaire.

## Acceptance criteria

- La pin du compte courant affiche son avatar sélectionné.
- Les pins d’amis affichent leurs avatars synchronisés.
- Aucun fond coloré ni initiale ne reste au centre des pins utilisateur.
- Les avatars invalides ou absents utilisent une image embarquée valide.
- Les comportements existants de sélection, callout, présence et position ancienne sont conservés.

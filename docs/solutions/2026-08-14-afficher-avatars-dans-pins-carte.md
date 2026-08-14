# Afficher les avatars embarqués dans les pins MapKit

## Contexte

Les pins de position utilisaient une couleur de profil et l’initiale du nom. Les profils disposent désormais d’un `avatarID` stable, synchronisé par Firestore et résolu vers un asset embarqué.

## Solution

`FriendLocation` transporte aussi l’`avatarID` résolu par le listener de profil. Cela fait évoluer la valeur publiée même si la position géographique ne change pas, ce qui provoque la mise à jour SwiftUI puis la reconfiguration de l’annotation MapKit existante.

`MapWithFogView` reçoit directement l’avatar local et lit celui des amis depuis leurs positions. `UserLocationAnnotationView` utilise une `UIImageView` circulaire en `scaleAspectFill` au centre du support blanc existant. Le cache `configuredAvatarID` évite de recharger l’image à chaque rafraîchissement tout en empêchant une vue MapKit réutilisée de conserver l’avatar précédent.

Un identifiant local absent ou invalide se replie sur `cyclops-horns`. Pour les amis, le service de profil fournit déjà un avatar déterministe basé sur l’UID lorsque Firestore ne contient pas encore de valeur valide.

## Comportements préservés

- La bordure blanche, l’ombre et le texte circulaire de présence restent inchangés.
- Une position ancienne réduit toujours l’opacité de toute la pin, avatar compris.
- Les callouts, les actions d’ami et l’accessibilité restent attachés à l’annotation.
- `profileColorHex` reste disponible pour les zones explorées et les sorties prévues.
- Aucun changement Firebase ni Storage n’est nécessaire.

## Validation

- Build Debug iOS Simulator réussi.
- Rendu vérifié sur l’iPhone 17 Simulator iOS 26.3 avec un asset réel.
- Absence confirmée des anciennes vues d’initiale dans le code actif.

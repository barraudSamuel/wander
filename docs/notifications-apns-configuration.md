# Configuration APNs et FCM

Cette configuration est nécessaire pour valider les notifications du Sprint 4
sur un appareil physique. Elle ne déploie ni les règles ni la Cloud Function.

## Apple Developer

1. Vérifier que l’App ID explicite `com.iterar.wander.wander` possède la
   capacité **Push Notifications**.
2. Créer ou sélectionner une clé APNs ayant accès à Apple Push Notifications.
3. Télécharger le fichier `.p8` une seule fois et conserver son **Key ID** et
   le **Team ID** hors du dépôt.
4. Régénérer les profils de développement et de distribution après
   l’activation de la capacité Push.

Ne jamais ajouter au dépôt une clé `.p8`, un profil `.mobileprovision` ou un
autre secret de signature.

## Firebase Console

Dans les réglages du projet Firebase, ouvrir **Cloud Messaging**, sélectionner
l’application iOS `com.iterar.wander.wander`, puis téléverser la clé APNs avec
son Key ID et son Team ID. Une clé d’authentification APNs peut servir aux
environnements de développement et de production.

## Xcode

Le target `wander` doit conserver :

- la capacité **Push Notifications** ;
- le mode d’arrière-plan **Remote notifications** ;
- `FirebaseMessaging` dans les produits Swift Package Manager ;
- `aps-environment` dans les entitlements signés par le profil actif.

Avant un archive de distribution, vérifier que le profil embarqué autorise
l’environnement APNs de production. Le build simulateur ne valide pas cette
partie de la signature.

## Backend

Les fonctions `notifyAcceptedFriendsOfEvent`,
`notifyRecipientOfFriendRequest`,
`notifyEventParticipantsOfAttendance`, `cleanupEventAttendances` et
`cleanupReplacedEventAttendances` ainsi que `cleanupExpiredEvents` sont
préparées pour la région
`asia-northeast3`. Avant le premier déploiement, confirmer que cette région est
adaptée à l'emplacement Firestore du projet ; changer une région après
déploiement crée une nouvelle fonction au lieu de déplacer l'existante.

Le broadcast de participation utilise le payload minimal suivant :

- `type: eventAttendanceCreated` ;
- `eventOwnerId` ;
- `eventId` ;
- `publicationId`.

Le participant qui vient de rejoindre est exclu. L'organisateur et les autres
participants encore amis avec lui reçoivent « Nouvelle participation — Léa va
vous rejoindre pour Namsan. ». Le backend relit la participation, le profil,
l’événement et les amitiés avant l'envoi. L'identité de dispatch inclut
`eventId`, `publicationId` et le timestamp serveur de l'inscription : une
relance du même événement ne duplique pas le push, tandis qu'un véritable
départ suivi d'une nouvelle arrivée constitue une nouvelle participation.

Les événements sont stockés dans `users/{ownerId}/events/{eventId}` sans champ
`expiresAt` ni TTL. La fonction planifiée `cleanupExpiredEvents`, déployée dans
`asia-northeast3`, s’exécute toutes les heures et supprime les événements dont
`publishedAt` date d’au moins 12 heures. Une modification renouvelle ce timestamp
serveur : la nouvelle publication dispose donc de 12 heures supplémentaires.
La suppression intervient en pratique entre 12 et 13 heures après la dernière
publication. La modification nettoie les participations de l’ancienne
publication ; la suppression, manuelle ou planifiée, nettoie toute la
sous-collection `attendees` via `cleanupEventAttendances`.

La requête planifiée utilise l’index collection-group déclaré dans
`firestore.indexes.json`. Cet index ne change pas avec la nouvelle durée : seul
`cleanupExpiredEvents` doit être redéployé pour passer de 24 à 12 heures.

La fonction déjà déployée conserve son ancienne rétention de 24 heures jusqu’au
redéploiement manuel de `cleanupExpiredEvents` avec cette version.

Installer et valider localement le backend :

```sh
cd functions
npm install
npm test
npm audit --audit-level=moderate
```

Valider les règles avec le JDK 21 déjà installé :

```sh
cd firebase-tests
JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home \
  npm run test:rules
```

Le déploiement des règles, de la fonction et de la configuration APNs reste
hors du Sprint 4 et nécessite l’approbation indépendante du Sprint 5.

## Validation sur appareil physique

- Activer « Sorties de mes amis » depuis le compositeur ou le profil.
- Vérifier la création de `users/{uid}/devices/{deviceId}` avec uniquement
  `token`, `platform` et `updatedAt`.
- Depuis un deuxième compte accepté, publier deux événements.
- Vérifier une seule notification, sans adresse ni coordonnées.
- Toucher chaque notification et confirmer le recentrage sur le bon événement.
- Avec trois comptes, faire rejoindre B puis C : A reçoit les deux arrivées, B
  reçoit celle de C, et aucun compte ne reçoit sa propre arrivée.
- Confirmer que les participants voient les mêmes avatars dans la callout et
  qu'un ami non participant ne voit pas la liste.
- Refaire les essais avec une demande en attente, un non-ami, une amitié
  révoquée, un refus de permission, une déconnexion et une suppression de
  compte.

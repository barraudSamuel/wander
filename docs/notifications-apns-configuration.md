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

La fonction `notifyAcceptedFriendsOfOuting` est préparée pour la région
`asia-northeast3`. Avant le premier déploiement du Sprint 5, confirmer que cette
région est adaptée à l’emplacement Firestore du projet ; changer une région
après déploiement crée une nouvelle fonction au lieu de déplacer l’existante.

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
- Depuis un deuxième compte accepté, publier une sortie.
- Vérifier une seule notification, sans adresse ni coordonnées.
- Toucher la notification et confirmer le recentrage sur la sortie.
- Refaire les essais avec une demande en attente, un non-ami, une amitié
  révoquée, un refus de permission, une déconnexion et une suppression de
  compte.

---
id: "006"
title: "Finaliser la suppression de compte côté serveur"
status: ready
priority: P2
source: review
created: 2026-08-09
tags: [todo, authentication, firebase, reliability]
---

# Finaliser la suppression de compte côté serveur

## Finding

Le client rend la suppression Firestore reprenable grâce à
`deletionRequestedAt`, puis supprime le profil et l'utilisateur Firebase Auth.
Firestore et Firebase Auth ne partagent toutefois aucune transaction côté iOS.
Une fermeture forcée dans l'intervalle très court entre le dernier lot
Firestore et `User.delete()` peut donc laisser le compte Auth sans profil.

Le client réduit cette fenêtre en exécutant les deux opérations à la suite,
mais seule une fonction backend ou une extension de suppression pilotée par
l'événement Auth peut garantir la finalisation sur plusieurs appareils.

## Evidence

- `FriendSyncService.deleteCurrentAccountData()` termine par la suppression du
  profil Firestore et du code ami.
- `FirebaseService.finishAccountDeletion(authorizationCode:)` révoque Apple et
  supprime ensuite Firebase Auth dans un service distinct.
- Aucun projet Cloud Functions ni finaliseur équivalent n'existe dans le dépôt.

## Acceptance criteria

- [ ] La suppression Auth déclenche un nettoyage serveur idempotent de toutes
      les collections associées à l'UID.
- [ ] Une fermeture forcée entre chaque étape converge vers zéro donnée et zéro
      compte actif sans recréer le profil.
- [ ] Le mécanisme couvre plusieurs appareils et consigne les échecs sans
      enregistrer d'UID ou de localisation en clair dans les logs applicatifs.
- [ ] Les règles et la documentation de déploiement sont mises à jour et testées
      dans l'émulateur Firebase.

## Resolution notes

Amélioration de durcissement distribuée ; elle nécessite une infrastructure
backend et des droits de déploiement absents de cette tâche client.

---
title: "Déconnexion et suppression complète du compte"
status: completed
date: 2026-08-09
owner: "Samuel Barraud"
related:
  - "./2026-08-09-authentification-apple.md"
  - "./2026-08-09-restauration-compte-multi-appareil.md"
  - "../../todos/001-ready-p1-add-account-deletion.md"
tags: [plan, authentication, firebase, apple, privacy]
---

# Déconnexion et suppression complète du compte

## Outcome

Le profil propose deux actions distinctes : une déconnexion réversible qui ne
supprime aucune donnée et une suppression définitive qui retire les données
Firestore, révoque l'autorisation Apple, supprime l'utilisateur Firebase Auth,
puis efface les données locales.

Le résultat est atteint lorsque :

- une déconnexion renvoie à l'écran Apple sans modifier les données locales ou
  distantes ;
- une reconnexion au même compte restaure le profil, les amis et l'exploration ;
- une suppression exige une confirmation et une authentification Apple récente ;
- les cellules, la position, les relations, le code ami et le profil Firestore
  sont supprimés avant l'utilisateur Firebase Auth ;
- les données locales sont effacées seulement après le succès distant ;
- une interruption de la suppression ne peut pas déclencher une republication
  silencieuse des données en cours d'effacement.

## Context

- `wander/ContentView.swift` ne propose actuellement qu'un effacement local.
- `wander/FirebaseService.swift` sait connecter avec Apple et fermer une session
  révoquée, mais n'expose ni déconnexion volontaire ni suppression.
- `wander/FriendSyncService.swift` maintient une union monotone entre SwiftData
  et Firestore ; ce comportement doit être suspendu pendant une suppression.
- `firestore.rules` interdit au demandeur de supprimer une demande d'amitié
  encore en attente.
- Firebase exige une authentification récente pour supprimer un utilisateur
  et un authorization code Apple récent pour révoquer le jeton.

## Scope

- Included:
  - boutons natifs « Se déconnecter » et « Supprimer mon compte » ;
  - confirmation et réauthentification Apple pour la suppression ;
  - suppression par lots de toutes les données Firestore connues ;
  - marqueur de suppression Firestore pour bloquer les écritures concurrentes ;
  - reprise idempotente après erreur ou interruption ;
  - révocation Apple et suppression Firebase Auth ;
  - effacement de SwiftData, UserDefaults et du cache Firestore après succès ;
  - messages d'erreur et états de progression accessibles.
- Not included:
  - suppression de l'identifiant Apple personnel ;
  - déploiement des règles dans le projet Firebase distant ;
  - ajout d'un autre fournisseur d'identité ;
  - conservation légale ou export des données.

## Proposed approach

`FirebaseService` reste propriétaire des opérations Apple et Firebase Auth. Il
génère un nonce dédié, réauthentifie l'utilisateur, conserve l'authorization
code jusqu'à la fin du nettoyage, révoque le jeton, puis supprime l'utilisateur.

`FriendSyncService` orchestre la suppression Firestore. Il marque d'abord le
profil comme `deletionRequestedAt`, suspend tous ses listeners et uploads, puis
supprime par lots les cellules et relations, la position, et enfin le profil et
le code ami dans une même écriture. Les règles refusent les nouvelles écritures
du propriétaire dès que le marqueur est présent. Les opérations sont
idempotentes afin qu'une nouvelle authentification Apple puisse reprendre le
parcours.

`ContentView` conserve l'orchestration UI et le `LocationTracker` requis pour
effacer SwiftData. Après succès Firebase Auth, il nettoie les préférences et le
cache Firestore. La déconnexion simple appelle uniquement `signOut()`.

## Affected files

- `wander/FirebaseService.swift` — déconnexion, nonce de suppression,
  réauthentification, révocation et suppression Firebase Auth.
- `wander/FriendSyncService.swift` — marqueur, suspension et nettoyage Firestore
  reprenable.
- `wander/ContentView.swift` — actions, confirmations, état et orchestration.
- `wander/LocationTracker.swift` — réutilisation de l’effacement local complet
  existant, sans modification nécessaire.
- `firestore.rules` — marqueur, blocage des écritures et suppression des
  relations en attente.
- `todos/001-ready-p1-add-account-deletion.md` — résolution du constat.
- `docs/solutions/` — leçon réutilisable après validation.

## Implementation

- [x] Ajouter les primitives de déconnexion et réauthentification/suppression.
- [x] Ajouter la suppression Firestore idempotente et la suspension de sync.
- [x] Adapter les règles Firestore au marqueur et au nettoyage des relations.
- [x] Remplacer l'effacement local par les deux parcours natifs.
- [x] Effacer toutes les données locales seulement après succès distant.
- [x] Compiler, simplifier, relire et consigner les résultats.

## Edge cases and risks

- Annulation Apple — aucune donnée n'est modifiée avant le credential récent.
- Hors ligne — la suppression échoue avant le premier changement serveur et
  reste disponible à la nouvelle tentative.
- Interruption après le marqueur — les règles et le service bloquent les uploads
  puis la suppression reprend de façon idempotente.
- Plus de 500 documents — les cellules et relations sont supprimées par lots
  inférieurs à la limite Firestore.
- Échec après révocation Apple — la réauthentification récente réduit le risque
  que `User.delete()` échoue ; l'erreur reste visible et actionnable.
- Plusieurs appareils — le marqueur distant bloque les nouvelles écritures du
  compte dès le début de la phase destructive. Une transaction stricte entre
  le dernier lot Firestore et Firebase Auth nécessiterait un finaliseur backend.

## Validation

- [x] Le build Debug simulateur réussit sans nouvel avertissement du code.
- [x] Les règles couvrent le marqueur, les suppressions et les écritures bloquées.
- [x] La revue confirme qu'une déconnexion ne touche ni SwiftData, ni
      UserDefaults, ni Firestore.
- [x] La reconnexion réutilise le parcours de restauration existant sans
      effacement local ou distant à la déconnexion.
- [x] La revue confirme qu'une annulation Apple n'a aucun effet.
- [x] Le chemin de succès revient à l'écran de connexion après nettoyage du
      cache local.
- [x] Une erreur réseau avant ou pendant Firestore conserve un état reprenable
      sans republication sur l'appareil qui a reçu le marqueur.
- [ ] Le parcours est validé sur appareil réel avec Apple et Firebase configurés.
- [x] L'interface reste native, accessible et compatible Dynamic Type.

## Review notes

- Hardest decision: interrompre la synchronisation monotone dès qu'un marqueur
  serveur de suppression est confirmé, tout en ignorant un marqueur provenant
  seulement du cache afin de ne pas bloquer le bootstrap hors ligne.
- Rejected alternatives: supprimer uniquement Firebase Auth aurait laissé les
  documents Firestore orphelins ; effacer d'abord SwiftData aurait pu détruire
  la seule copie locale avant qu'une panne réseau n'interrompe le distant ; une
  simple déconnexion suivie d'un nettoyage aurait permis une restauration
  involontaire au prochain login.
- Least certain: la réauthentification et la révocation Apple ne peuvent être
  exercées sur simulateur sans configuration distante. La frontière finale
  entre le dernier lot Firestore et `User.delete()` reste non atomique sans
  backend et fait l'objet d'un suivi séparé.

---
title: "Retirer une amitié sans alerte Firestore"
status: in_progress
date: 2026-08-15
approved_at: "2026-08-15"
completed_at:
owner: "Samuel Barraud"
related:
  - "../solutions/2026-08-15-revocation-listeners-firestore.md"
tags: [plan, friends, firestore, listeners]
---

# Retirer une amitié sans alerte Firestore

## Outcome

Quand un utilisateur retire un ami, l'ancien ami disparaît automatiquement de
la liste et ses données sociales sont nettoyées sans afficher l'alerte technique
« Accès Firestore refusé ». Une véritable incohérence de règles continue d'être
signalée.

## Context

Les listeners du profil, de la position et de l'exploration sont autorisés par
la relation d'amitié. Firestore peut révoquer ces listeners avant que le listener
principal des `friendships` ait livré la suppression. Dans cette fenêtre, le
client interprète actuellement le `permissionDenied` attendu comme une erreur
globale et l'expose dans la vue Amis.

Le propriétaire a approuvé ce plan explicitement le 15 août 2026.

## Scope

- Inclus :
  - reconnaître un refus d'accès sur une ressource sociale dépendante ;
  - confirmer côté serveur si la relation déterministe existe toujours ;
  - nettoyer silencieusement une relation réellement révoquée ;
  - conserver les erreurs actionnables quand la relation est toujours valide ;
  - protéger le flux contre les réponses obsolètes et les vérifications en
    double.
- Non inclus :
  - modifier l'interface ou le texte des alertes ;
  - modifier ou déployer les règles Firestore ;
  - changer le schéma des documents ;
  - modifier les sorties prévues, qui retirent déjà silencieusement une donnée
    devenue inaccessible.

## Dependencies

- Le document d'amitié garde son identifiant déterministe composé des deux UID.
- Les règles existantes permettent à un participant de lire ce chemin direct
  même après la suppression du document.
- FirebaseFirestore reste la source des codes d'erreur typés.

## Proposed approach

Centraliser dans `FriendSyncService` le traitement des erreurs des listeners
dépendants. Les erreurs ordinaires conservent le comportement actuel. Pour un
`permissionDenied`, retrouver la relation locale correspondante et effectuer
une seule lecture serveur du document d'amitié.

Si le document a disparu ou n'est plus une relation valide pour les deux
utilisateurs, retirer la relation locale, réconcilier tous les listeners et
reconstruire les listes publiées sans renseigner `errorMessage`. Si le document
confirme encore la relation, présenter l'erreur existante afin de ne pas masquer
une régression de règles ou de données.

## Affected files

- `wander/FriendSyncService.swift` — classification, confirmation et nettoyage
  des révocations.
- `docs/plans/2026-08-15-revocation-amitie-sans-alerte.md` — suivi du sprint.
- `docs/solutions/2026-08-15-revocation-listeners-firestore.md` — apprentissage
  réutilisable après validation.
- `todos/` — uniquement si la revue découvre un problème non résolu.

## Implementation checklist

- [x] Ajouter la détection typée de `FirestoreErrorCode.permissionDenied`.
- [x] Dédupliquer les confirmations de révocation par relation.
- [x] Confirmer le document d'amitié depuis le serveur avec des gardes de
  session et de génération.
- [x] Nettoyer la relation et toutes ses données dérivées sans alerte lorsqu'elle
  est absente ou invalide.
- [x] Brancher le traitement sur les listeners de profil, position et
  exploration.
- [x] Préserver le signalement des autres erreurs et des refus inattendus.
- [x] Simplifier et revoir le diff.
- [x] Exécuter les validations disponibles et consigner les résultats exacts.

## Edge cases and risks

- Une règle réellement cassée peut aussi produire `permissionDenied` — la
  lecture serveur de la relation doit confirmer la révocation avant de supprimer
  silencieusement l'état local.
- Plusieurs listeners peuvent échouer ensemble — une déduplication par
  `pairID` évite les lectures et alertes concurrentes.
- Une réponse peut arriver après une déconnexion — les gardes d'UID et de
  génération doivent l'ignorer.
- Le listener principal peut gagner la course — l'opération doit rester
  idempotente si la relation a déjà disparu localement.
- Le dépôt contient des changements non liés — ne pas les modifier ni les
  restaurer.

## Validation

- [x] Le build Debug générique iOS Simulator réussit sans nouvel avertissement.
- [ ] A retire B : A disparaît chez B sans alerte Firestore.
- [ ] Le profil, la position, l'exploration et la sortie de A disparaissent chez
  B.
- [x] Un refus Firestore alors que la relation existe encore reste signalé par
  la branche vérifiée statiquement.
- [x] Les erreurs réseau et les actions d'amitié conservent leur comportement.
- [x] L'apparence iOS native, l'accessibilité et Dynamic Type ne changent pas.

La validation sur deux comptes peut nécessiter l'appareil ou l'intervention du
propriétaire. L'environnement local ne possède que Java 17 alors que la version
Firebase CLI du dépôt exige Java 21 pour démarrer l'émulateur ; aucune
installation de runtime n'est incluse dans ce sprint.

## Validation results

- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug
  -destination 'generic/platform=iOS Simulator' ... build` : succès avec Xcode
  26.3 le 15 août 2026 ; aucun avertissement ajouté par le correctif.
- Le build a été installé et lancé sur l'iPhone 17 Simulator déjà démarré. Il
  atteint correctement l'écran de connexion Apple, mais aucune session n'y est
  disponible pour reproduire le parcours à deux comptes.
- `npm --prefix firebase-tests run test:rules` : non démarré, Firebase CLI
  15.26 refuse Java 17 et exige Java 21. Les règles Firestore ne font pas partie
  du diff.
- `git diff --check` : succès.
- Revue ciblée : aucun constat de priorité P1, P2 ou P3 ; aucun fichier ajouté
  dans `todos/`.

## Acceptance criteria

- La révocation distante ne déclenche plus d'alerte technique chez l'ancien ami.
- Toutes les données dépendantes de l'amitié sont retirées de l'état publié.
- Une erreur de permission indépendante d'une révocation reste visible.
- Aucun changement de règles, de schéma, d'interface ou de déploiement n'est
  effectué.

## Review notes

- Hardest decision: distinguer une révocation attendue d'une vraie régression de
  règles sans masquer cette dernière. La lecture serveur du document
  d'autorisation fournit cette distinction.
- Rejected alternatives: ignorer tous les `permissionDenied` masquerait des
  erreurs réelles ; ajouter un délai arbitraire dépendrait de l'ordre réseau ;
  supprimer immédiatement l'état local réagirait mal à une règle cassée.
- Least certain: validation de bout en bout à deux comptes depuis le seul
  simulateur disponible. Le plan reste `in_progress` jusqu'à ce parcours.

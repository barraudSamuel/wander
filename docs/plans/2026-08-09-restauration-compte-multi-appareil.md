---
title: "Restauration du compte sur un nouvel appareil"
status: completed
date: 2026-08-09
owner: "Samuel Barraud"
related:
  - "./2026-08-09-authentification-apple.md"
  - "../solutions/2026-08-09-migrer-auth-anonyme-vers-apple.md"
tags: [plan, firebase, sync, swiftdata, authentication]
---

# Restauration du compte sur un nouvel appareil

## Outcome

Après une connexion Apple sur une installation vierge, Wander restaure les
cases découvertes, le pseudo et la couleur du compte avant de présenter un
historique vide ou d'envoyer des valeurs locales par défaut. Les cases locales
et distantes sont fusionnées sans suppression afin que la carte, la progression
et les relations du compte réapparaissent sans perte de données.

Le résultat est considéré comme atteint lorsque :

- un compte Apple existant récupère ses identifiants H3 Firestore dans
  SwiftData ;
- l'union des cases locales et distantes est conservée des deux côtés ;
- un pseudo distant n'est jamais remplacé par `Explorer` pendant le bootstrap ;
- une installation vierge distingue chargement, erreur et historique vide ;
- un appareil possédant déjà des données locales reste utilisable hors ligne.

## Context

- `FriendSyncService` charge actuellement les cases du propriétaire uniquement
  dans `uploadedExplorationCellIDs`, sans les publier ni les réinsérer dans
  SwiftData.
- `LocationTracker` et la carte lisent exclusivement le
  `DiscoveredCellStore` local.
- le profil distant est comparé aux valeurs `UserDefaults` avant que le serveur
  ne soit établi comme autorité initiale, ce qui permet à `Explorer` d'écraser
  un pseudo existant sur un nouvel appareil.
- les règles Firestore autorisent déjà le propriétaire Apple à lister
  `explorations/{uid}/cells` ; aucune modification de règles n'est prévue.

## Scope

- Included:
  - restauration bidirectionnelle des identifiants de cases ;
  - fusion monotone Firestore/SwiftData ;
  - conservation des métadonnées locales existantes ;
  - date `sharedAt` comme repli pour une case uniquement distante ;
  - état explicite de chargement, succès et échec de l'exploration ;
  - hydratation distante initiale du pseudo et de la couleur ;
  - onboarding adapté à un profil Firebase existant ;
  - chargement, erreur et nouvelle tentative avec des composants iOS natifs.
- Not included:
  - avatar dans Firebase Storage ;
  - synchronisation de `duration` et `visitCount` ;
  - suppression du compte ou des données Firestore ;
  - plusieurs comptes locaux simultanés ;
  - CloudKit ou déploiement Firebase.

## Proposed approach

Firestore reste la source durable du compte et SwiftData le cache local rendu
par la carte. La réconciliation applique uniquement l'union suivante :

`cases finales = cases locales ∪ cases Firestore`

Le listener du propriétaire attend son premier snapshot serveur avant de
calculer les cases manquantes. Il publie ensuite les documents distants avec
leur éventuel `sharedAt`. `ContentView` injecte les cases distantes dans le
`DiscoveredCellStore`, actualise `LocationTracker`, puis remet l'union au
service Firebase. Une suppression distante ordinaire n'efface pas le cache
local ; elle est réparée par l'union tant que la suppression de compte n'est pas
explicitement engagée.

Le profil suit une règle remote-first au bootstrap : les écritures sortantes
sont bloquées jusqu'à un snapshot serveur valide. Le pseudo et la couleur du
serveur hydratent ensuite `UserDefaults`. Un profil déjà présent est identifié
par la transaction de création afin d'adapter le texte d'onboarding sans
contourner la configuration locale de la localisation.

## Affected files

- `wander/FriendSyncService.swift` — snapshot du propriétaire, état de sync,
  retry, origine et hydratation du profil.
- `wander/DiscoveredCellStore.swift` — fusion distante idempotente.
- `wander/LocationTracker.swift` — import distant et republication de la carte.
- `wander/ContentView.swift` — orchestration de la fusion et états natifs.
- `wander/wanderApp.swift` — bootstrap d'une installation vierge.
- `wander/OnboardingView.swift` — variante pour un profil existant.
- `docs/solutions/` — leçon réutilisable après validation.
- `todos/` — constats non résolus découverts pendant la revue, le cas échéant.

## Implementation

- [x] Publier les cases du propriétaire avec `sharedAt` et un état de sync.
- [x] Attendre le premier snapshot serveur et exposer une action de retry.
- [x] Ajouter une fusion SwiftData idempotente qui préserve les cellules locales.
- [x] Répercuter l'import dans `LocationTracker`, la carte et la progression.
- [x] Renvoyer l'union locale/distante vers Firestore sans suppression.
- [x] Bloquer les écritures de profil jusqu'à l'hydratation serveur.
- [x] Restaurer le pseudo et la couleur dans `UserDefaults`.
- [x] Identifier un profil existant et adapter le bootstrap/onboarding.
- [x] Présenter chargement, erreur et nouvelle tentative avec SwiftUI natif.
- [x] Exécuter le build et les validations accessibles.
- [x] Simplifier puis revoir le diff par rapport au plan.
- [x] Consigner les constats et la leçon réutilisable.

## Edge cases and risks

- Snapshot cache vide — ne jamais le traiter comme la vérité initiale ; attendre
  un snapshot serveur.
- Upload avant restauration — conserver les cases locales comme désirées, mais
  ne calculer les écritures qu'après le premier snapshot serveur.
- Doublons — utiliser l'identifiant H3 unique et une fusion idempotente.
- Document ancien — accepter `sharedAt` absent côté client et utiliser la date
  courante comme dernier repli.
- Gros historique — insérer par lots cohérents et limiter les republications.
- Snapshot supprimant une case — préserver la sémantique monotone et renvoyer
  la case locale ; la suppression réelle appartient au futur flux de compte.
- Appareil existant hors ligne — afficher immédiatement SwiftData et ne réserver
  l'attente serveur qu'au bootstrap d'une installation locale vierge.
- Métadonnées détaillées — préserver les valeurs locales, sans prétendre les
  restaurer tant que leur schéma cloud n'existe pas.

## Validation

- [x] Le build Debug pour un simulateur iOS réussit sans nouvel avertissement.
- [x] La revue confirme que l'envoi local attend le premier snapshot serveur.
- [ ] Une installation vierge restaure les cases du même compte Apple sur un
  second appareil réel.
- [x] La carte et la progression sont republiées après l'import SwiftData.
- [x] La fusion implémente l'union locale/distante sans écraser les métadonnées
  locales.
- [x] Le pseudo distant est hydraté avant toute écriture sortante de profil.
- [x] Le code ami et les relations restent chargés depuis leurs listeners
  existants, sans modification de schéma.
- [x] Un snapshot initial issu du cache ne publie pas un faux état vide.
- [x] La racine ouvre immédiatement le contenu si SwiftData et l'onboarding
  local existent déjà, sans attendre le serveur.
- [x] Une installation vierge hors ligne présente une erreur ou une attente,
  jamais une progression vide déclarée comme synchronisée.
- [x] L'effacement local n'appelle aucune suppression de données Firebase.
- [x] L'interface conserve les contrôles, couleurs et espacements iOS natifs.

## Review notes

- Hardest decision: distinguer « chargé et vide » de « cache local vide en
  attente du serveur », puis appliquer une union monotone avant tout calcul
  d'upload. Cette séquence évite qu'un nouvel appareil présente ou propage un
  faux historique vide.
- Rejected alternatives: CloudKit en parallèle de Firebase, restauration fondée
  sur le seul cache Firestore, et suppression bidirectionnelle implicite.
- Least certain: le parcours Apple/Firebase réel sur deux appareils et le temps
  de restauration d'un très gros historique n'ont pas pu être mesurés sans
  session Apple de test. Le flux d'authentification a été lancé et inspecté sur
  simulateur, mais la case correspondante reste volontairement non cochée.
- Follow-ups: les statistiques détaillées, l'avatar et les tests automatisés
  sont suivis dans `todos/003-ready-p2-sync-exploration-metadata.md`,
  `todos/004-ready-p2-sync-profile-avatar.md` et
  `todos/005-ready-p2-add-account-sync-tests.md`.

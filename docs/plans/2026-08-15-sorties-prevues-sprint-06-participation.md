---
title: "Sorties prévues — Sprint 6 — Participation aux sorties"
status: in_progress
sprint: 6
date: 2026-08-15
approved_at: "2026-08-15T16:57:24+09:00"
in_progress_at: "2026-08-15T16:57:24+09:00"
revised_approved_at: "2026-08-15T17:43:17+09:00"
revised_in_progress_at: "2026-08-15T17:43:17+09:00"
depends_on:
  - "Sprint 1 completed"
  - "Sprint 2 completed"
  - "Sprint 3 completed"
  - "Sprint 4 completed"
  - "Sprint 5 completed for its approved TTL scope"
tags: [plan, sprint, firestore, mapkit, friends, participation, notifications]
---

# Sprint 6 — Participer à une sortie prévue

## Status

Ce sprint révisé a été approuvé explicitement par le propriétaire le
2026-08-15 avec avatars partagés entre participants et broadcast automatique.
Il est désormais `in_progress`. Toute opération distante,
notamment le déploiement des règles ou la création d'une politique TTL, exige
une autorisation distincte au moment concerné.

## Outcome

Un ami accepté peut indiquer « Je participe » depuis la callout d'une sortie
prévue, retrouver cet état après une relance et retirer sa participation.
L'organisateur et chaque participant voient en temps réel le nombre de
participants ainsi que quatre avatars au maximum, suivis de `+N` lorsque la
liste est plus longue. À chaque arrivée, l'organisateur et les participants
déjà inscrits reçoivent une notification nominative automatique.

Le parcours est réussi lorsque la participation reste liée à une publication
précise, disparaît de l'interface après annulation, expiration ou révocation,
et ne révèle l'identité des participants qu'aux membres de la sortie courante.

## Scope

- Included:
  - action native « Je participe » sur la sortie active d'un ami accepté ;
  - état réversible « Vous participez » / « Je ne participe plus » ;
  - résumé visible par l'organisateur et les participants avec nombre, quatre
    avatars maximum et indicateur `+N` ;
  - broadcast nominatif à l'organisateur et aux participants déjà inscrits lors
    d'une arrivée, sans confirmation préalable ;
  - ouverture sécurisée de la sortie depuis la notification ;
  - documents de participation déterministes liés à `publicationId` ;
  - écouteurs incrémentaux limités à la participation personnelle, à la propre
    sortie et aux sorties effectivement rejointes ;
  - règles Firestore, tests de sécurité et nettoyage de compte ;
  - filtrage local systématique des publications expirées ou remplacées ;
  - politique TTL distincte pour les participations, seulement après une
    autorisation distante séparée.
- Not included:
  - notification au départ d'un participant ;
  - liste ou avatars visibles par les amis qui ne participent pas ;
  - invitation ciblée, réponse « Peut-être », capacité maximale ou discussion ;
  - nouveau moteur d'itinéraire, redesign ou composant UI tiers ;
  - déploiement Firebase implicite.

## Data contract

Chaque participation utilise le chemin :

`plans/{ownerID}/attendees/{publicationID}__{participantID}`

Le document contient exactement :

- `participantId`, égal à l'utilisateur authentifié et au suffixe du chemin ;
- `publicationId`, égal à la publication active du parent ;
- `displayName` et `avatarID`, instantané du profil vérifié à l'inscription ;
- `joinedAt`, timestamp serveur de création ;
- `expiresAt`, égal à l'expiration du plan parent.

L'existence du document signifie que l'ami participe. Une participation n'est
jamais mise à jour : elle est créée ou supprimée. L'identifiant de publication
dans le chemin empêche une ancienne réponse de bloquer ou contaminer une sortie
remplacée. Le pseudo et l'avatar sont dupliqués uniquement pour permettre leur
lecture bornée aux membres de la sortie ; aucun lieu, adresse ou coordonnée ne
l'est.

## Privacy and authorization

- Seul un ami `accepted` peut créer sa propre participation à un plan actif.
- Le participant peut lire et supprimer son propre document, y compris après
  une révocation afin de permettre le nettoyage.
- L'organisateur peut lire et supprimer les participations sous son plan.
- Un participant actif peut lister uniquement les participations de la
  publication courante ; la règle exige son document déterministe et une
  amitié toujours `accepted` avec l'organisateur.
- Les amis non participants, anciennes participations, demandes en attente,
  inconnus et sessions déconnectées ne peuvent pas lister la collection.
- Le pseudo et l'avatar écrits doivent correspondre au profil Firestore du
  participant afin d'empêcher toute usurpation.
- Les journaux ne doivent contenir aucun UID, lieu ou coordonnée.

## Proposed approach

Un modèle Swift valide l'identité déterministe et les timestamps. Un service
`@MainActor` observe directement, pour chaque sortie d'ami, le seul document de
participation du compte courant. Une fois la participation confirmée, il ouvre
un second écouteur borné au `publicationId` courant pour recevoir la liste ; un
ami non participant n'ouvre jamais cet écouteur. L'organisateur conserve son
écouteur limité à sa publication.

La présentation MapKit enrichit l'annotation de sortie avec l'état personnel
et les participants visibles. Sa callout conserve les libellés natifs actuels,
ajoute un bouton système à droite sur les sorties d'amis et une rangée compacte
d'avatars pour l'organisateur et les participants. VoiceOver annonce l'état,
le nombre et les noms complets indépendamment de la limite visuelle de quatre
avatars.

Une Cloud Function réagit uniquement à la création d'une participation, relit
le plan et les amitiés actuels, exclut le nouvel arrivant et diffuse
« Nouvelle participation — Léa va vous rejoindre pour Namsan. » à
l'organisateur et aux autres participants valides. Un identifiant de dispatch
déterministe et les claims par appareil existants empêchent les doublons. Le
payload ne contient que le type, l'owner et le `publicationId`.

## Affected files

- `wander/OutingAttendance.swift` — modèle validé de participation.
- `wander/OutingAttendanceService.swift` — création, suppression et écouteurs.
- `wander/OutingPlan.swift` — conservation de la valeur exacte de publication.
- `wander/OutingPlanService.swift` — coordination du cycle de vie si nécessaire.
- `wander/MapWithFogView.swift` — bouton, état et avatars dans la callout.
- `wander/ContentView.swift` — rapprochement des profils et actions asynchrones.
- `wander/NotificationService.swift` — routage du nouveau type de push.
- `wander/FriendSyncService.swift` — nettoyage des participations du compte.
- `firestore.rules` — contrat et matrice d'autorisation.
- `firebase-tests/tests/outing-attendances.rules.test.mjs` — tests dédiés.
- `firebase-tests/package.json` — exécution séquentielle des suites partageant
  le même projet d'émulation.
- `functions/src/index.ts` — trigger et diffusion de l'arrivée.
- `functions/src/notificationLogic.ts` — sélection, contenu, route et identité
  de dispatch purs.
- `functions/src/notificationLogic.test.ts` — tests unitaires du broadcast.
- `docs/notifications-apns-configuration.md` — contrat APNs du nouveau type.
- `docs/plans/2026-08-15-sorties-prevues-sprint-06-participation.md` — suivi.
- `docs/solutions/2026-08-15-sequencer-suites-regles-firestore.md` — isolation
  déterministe des suites partageant l'émulateur.
- `docs/solutions/2026-08-15-lister-firestore-par-appartenance.md` — preuve
  déterministe d'appartenance pour une requête bornée.
- `todos/` — uniquement pour les anomalies de revue non résolues.
- `docs/solutions/` — uniquement si un apprentissage réutilisable est vérifié.

Le projet utilise un groupe Xcode synchronisé ; les nouveaux fichiers Swift ne
doivent pas nécessiter d'entrée manuelle dans `project.pbxproj`.

## Implementation checklist

- [x] Marquer le sprint `in_progress` avant la première modification produit.
- [x] Ajouter le modèle et les références Firestore déterministes.
- [x] Ajouter les règles de lecture, création et suppression strictes.
- [x] Couvrir la matrice positive et négative dans l'émulateur.
- [x] Observer et modifier la participation du compte courant.
- [x] Observer les participants de la propre publication.
- [x] Réconcilier les écouteurs lors des changements de plan et d'amitié.
- [x] Ajouter l'action et son état à la callout d'une sortie d'ami.
- [x] Afficher quatre avatars maximum, `+N` et le nombre pour l'organisateur et
      les participants.
- [x] Ajouter les libellés VoiceOver et les erreurs utilisateur natives.
- [x] Nettoyer les participations lors de la suppression du compte.
- [x] Étendre le contrat avec un pseudo et un avatar vérifiés.
- [x] Autoriser la liste courante à un participant actif seulement.
- [x] Observer et afficher les avatars pour chaque participant actif.
- [x] Ajouter le broadcast nominatif, ses destinataires et son idempotence.
- [x] Router le nouveau push vers la sortie après relecture autorisée.
- [x] Couvrir les règles et la logique de notification révisées.
- [x] Simplifier, relire et valider le périmètre révisé.
- [ ] Demander une autorisation distincte avant le déploiement des règles.
- [ ] Demander une autorisation distincte avant la politique TTL distante.

## Edge cases and risks

- Firestore ne supprime pas les sous-collections avec leur parent — le client
  filtre immédiatement et une politique TTL indépendante nettoie le stockage.
- Une sortie peut être remplacée pendant une action — le chemin, les règles et
  la relecture exigent tous le même `publicationId`.
- Une amitié peut être révoquée — les écouteurs sont retirés, toute nouvelle
  création est refusée, la liste devient illisible et le backend exclut le
  compte des destinataires.
- Plusieurs touches rapides pourraient créer des courses — désactiver l'action
  pendant l'écriture et rendre la création/suppression idempotente.
- Les écouteurs pourraient croître avec le nombre d'amis — observer uniquement
  un chemin déterministe par plan actif et les réconcilier incrémentalement.
- Un participant peut changer d'avatar après son inscription — l'instantané
  reste valable seulement pour cette sortie courte et sera renouvelé lors de
  la prochaine inscription.
- Deux arrivées quasi simultanées peuvent se notifier mutuellement selon
  l'ordre de traitement ; chacune reste un événement unique et aucun arrivant
  ne reçoit sa propre arrivée.

## Validation

- [x] Le build Debug générique pour simulateur réussit sans nouvel avertissement.
- [x] L'analyse statique Xcode réussit.
- [x] Tous les tests de règles existants et nouveaux réussissent avec JDK 21.
- [x] Propriétaire et participant réussissent uniquement leurs accès attendus.
- [x] Ami tiers, demande en attente, inconnu et session déconnectée sont refusés.
- [x] Identité usurpée, publication obsolète, expiration incorrecte, mise à jour
      et champ supplémentaire sont refusés.
- [x] Les tests unitaires Functions couvrent les destinataires, le contenu, le
      payload minimal et l'identité de dispatch d'une arrivée.
- [x] L'audit npm du backend ne signale aucune vulnérabilité.
- [ ] Le remplacement, l'annulation, l'expiration et la révocation retirent
      immédiatement l'état visible.
- [ ] Le parcours réel à trois comptes/appareils réussit, en utilisant seulement
      l'iPhone 17 Simulator déjà démarré pour la validation simulateur.
- [ ] La callout montre au plus quatre avatars, `+N` et le total exact.
- [ ] Organisateur et participants voient les mêmes avatars, tandis qu'un ami
      non participant ne peut pas lire la liste.
- [ ] Une arrivée notifie une fois l'organisateur et les participants existants,
      mais jamais le nouvel arrivant, un ex-participant ou un ami révoqué.
- [ ] Le push ne contient ni adresse, ni coordonnées, ni UID visible et ouvre
      uniquement une publication encore autorisée.
- [ ] VoiceOver, Dynamic Type et mode sombre sont vérifiés.
- [ ] La suppression de compte retire les participations possédées et rejointes.
- [x] `git diff --check` réussit.
- [x] Aucun log ajouté ne contient UID, adresse ou coordonnées.

## Acceptance criteria

- Une personne ne peut avoir qu'une participation par publication.
- Seul un ami accepté peut rejoindre une sortie encore active.
- L'organisateur et les participants voient le total et les avatars autorisés
  en temps réel ; les non-participants ne les voient pas.
- Chaque arrivée produit au plus un broadcast nominatif par appareil éligible.
- Le participant retrouve et peut retirer son état après relance.
- Aucune participation obsolète n'est affichée pour une nouvelle publication.
- Aucun déploiement ni TTL distant n'a lieu sans approbation dédiée.

## Review notes

- Hardest decision: permettre la visibilité entre participants sans rendre les
  profils lisibles par tous les amis. Le document déterministe du demandeur et
  le filtre de publication bornent la requête à une seule sortie active.
- Rejected alternatives: ouvrir directement tous les profils ne permettrait pas
  aux règles de prouver l'appartenance à une sortie ; un tableau intégré au plan
  créerait des écritures concurrentes. L'instantané validé dans la participation
  garde la lecture locale au bon périmètre.
- Least certain: la disposition réelle de la callout avec quatre avatars et le
  parcours bidirectionnel nécessitent deux comptes après déploiement des règles.
  Le lancement signé déconnecté ne permet pas de fabriquer cet état de façon
  représentative.

## Local validation record

Validations exécutées le 2026-08-15 avant toute mutation distante :

- `npm --prefix firebase-tests run test:rules` avec le JDK 21 de RustRover —
  52 tests réussis sur 52, incluant l'accès des participants, le refus des
  non-participants, le départ et la révocation ;
- `npm --prefix functions test` — 13 tests réussis sur 13, dont la sélection
  des destinataires, le message nominatif, le payload et l'idempotence ;
- `npm --prefix functions audit --audit-level=moderate` — aucune vulnérabilité ;
- `xcodebuild ... build` Debug générique pour simulateur — succès ;
- `xcodebuild ... analyze` Debug générique pour simulateur — succès ;
- installation et lancement réussis sur l'iPhone 17 Simulator déjà démarré,
  avec arrivée sur l'authentification Apple sans crash ;
- `git diff --check` — succès ;
- validation JSON de `firebase.json` et `firebase-tests/package.json` — succès ;
- revue sécurité, confidentialité, expiration, changement de compte et
  accessibilité statique terminée sans finding restant à créer dans `todos/`.

Les règles et `notifyOutingParticipantsOfAttendance` ne sont pas déployées, la
politique TTL `attendees.expiresAt` n'est pas créée et la validation réelle à
trois comptes/appareils reste donc en attente.

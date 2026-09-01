---
title: "Afficher l’organisateur et les participants dans la fiche événement"
status: in_progress
date: 2026-08-31
approved_at: "2026-08-31T18:10:57+09:00"
in_progress_at: "2026-08-31T18:12:00+09:00"
revision_approved_at: "2026-08-31T18:49:59+09:00"
revision_in_progress_at: "2026-08-31T18:50:33+09:00"
revision_validated_at: "2026-08-31T18:55:50+09:00"
overlap_revision_approved_at: "2026-08-31T22:25:52+09:00"
overlap_revision_in_progress_at: "2026-08-31T22:25:52+09:00"
overlap_revision_validated_at: "2026-08-31T22:28:40+09:00"
roster_visibility_revision_approved_at: "2026-09-01T08:41:33+09:00"
roster_visibility_revision_in_progress_at: "2026-09-01T08:41:33+09:00"
revocation_cleanup_revision_proposed_at: "2026-09-01T08:58:08+09:00"
revocation_cleanup_revision_approved_at: "2026-09-01T09:23:59+09:00"
revocation_cleanup_revision_in_progress_at: "2026-09-01T09:24:07+09:00"
revocation_cleanup_revision_validated_at: "2026-09-01T09:39:30+09:00"
rsvp_decline_revision_proposed_at: "2026-09-01T10:34:00+09:00"
rsvp_decline_revision_approved_at: "2026-09-01T10:45:27+09:00"
rsvp_decline_revision_in_progress_at: "2026-09-01T10:45:27+09:00"
rsvp_decline_revision_validated_at: "2026-09-01T11:06:00+09:00"
owner: "Samuel Barraud"
related:
  - "2026-08-15-sorties-prevues-sprint-06-participation.md"
  - "2026-08-15-sorties-prevues-sprint-07-fiche-evenement.md"
tags: [plan, events, participants, avatars, accessibility, security]
---

# Afficher l’organisateur et les participants dans la fiche événement

## Outcome

La fiche d’un événement présente l’organisateur comme première personne, avec
son véritable avatar, puis les personnes inscrites. Le total compte toutes les
personnes visibles : un organisateur accompagné d’un seul inscrit affiche donc
deux personnes et deux avatars, sans donner l’impression que l’inscrit vient
seul. Jusqu’à six avatars légèrement chevauchés restent visibles avant `+N`.
Tout ami actuellement accepté par l’organisateur voit ce groupe dans la fiche,
même avant de rejoindre la sortie, tandis que son propre état de participation
reste explicite.

## Context

Le résumé actuel est construit exclusivement depuis les documents de
participation. L’organisateur ne peut volontairement pas créer un tel document
et reste donc absent de la pile d’avatars et du total, même si son nom apparaît
dans la ligne « Organisée par… ».

Le plan a été présenté en statut `proposed` puis approuvé explicitement par
Samuel le 2026-08-31.

Le 2026-09-01, Samuel a demandé que les amis acceptés voient les participants
avant de rejoindre. Cette révision matérielle de la frontière de confidentialité
a été présentée puis approuvée explicitement avant toute modification produit.

La revue de cette révision a confirmé le finding P2 historique `todos/012` :
supprimer une amitié ne supprime pas ses documents de participation. La
prévisualisation élargit leur visibilité résiduelle aux autres amis acceptés de
l’organisateur. Un filtre client ne peut pas corriger cette fuite, car le
spectateur ne peut pas connaître les relations des autres participants. La
révision backend ci-dessous a donc été présentée, explicitement approuvée le
2026-09-01, puis implémentée et validée localement sans déploiement distant.

## Scope

- Included:
  - transporter l’identité et l’avatar déjà chargés de l’organisateur dans le
    modèle de présentation cartographique ;
  - afficher l’organisateur en premier, puis les inscriptions actives ;
  - dédupliquer les personnes par identifiant utilisateur ;
  - compter l’organisateur dans un total formulé en « personne(s) » ;
  - afficher jusqu’à six avatars légèrement chevauchés et calculer `+N` sur le
    groupe total ;
  - séparer les avatars superposés avec une fine bordure sémantique native ;
  - distinguer l’organisation et les participants dans l’annonce VoiceOver ;
  - rendre la liste filtrée de la publication courante lisible par tout ami
    encore `accepted` de l’organisateur, même non inscrit ;
  - n’ouvrir le listener de prévisualisation que pour la fiche sélectionnée ;
  - distinguer chargement, disponibilité et indisponibilité du groupe sans
    présenter un faux total transitoire ;
  - retirer immédiatement listener et données dérivées après révocation.
- Not included:
  - créer une participation Firestore pour l’organisateur ;
  - rendre la liste publique, ou visible aux demandes en attente, relations
    révoquées et comptes sans amitié acceptée ;
  - modifier le schéma persistant d’une participation ou les notifications ;
  - précharger les listes de toutes les sorties d’amis ;
  - redesign de la fiche ou nouveau composant visuel ;
  - déployer implicitement les règles vers un projet Firebase distant.

## Proposed approach

Enrichir `MapOutingPlan` avec un `MapOutingAttendee` représentant
l’organisateur. `ContentView` le construit depuis le profil local pour sa
propre sortie et depuis `FriendContact` pour celle d’un ami, sans nouvelle
lecture distante. La fiche compose ensuite une liste locale avec
l’organisateur en premier et les inscriptions dont l’identifiant diffère du
sien. Cette liste pilote les avatars, le total et l’accessibilité, tandis que
`attendees` conserve sa sémantique de documents d’inscription.

La pile utilise un chevauchement horizontal de douze points. Les avatars restent
ordonnés avec l’organisateur en premier, une bordure de couleur système préserve
leur séparation en clair et sombre, et `+N` reste à l’extérieur de la zone
chevauchée.

Pour une sortie d’ami, `OutingAttendanceService` conserve le listener direct du
document déterministe du compte courant afin de calculer sa participation. Le
listener filtré du groupe complet reste actif si le compte participe ou si la
fiche correspondante est sélectionnée. Firestore autorise cette requête sur la
publication courante aux amis `accepted`, mais conserve les lectures directes
de documents tiers interdites. Le premier snapshot pilote un état explicite de
chargement, disponibilité ou indisponibilité.

## Affected files

- `wander/MapWithFogView.swift` — enrichir le modèle de présentation.
- `wander/ContentView.swift` — fournir l’identité et l’avatar organisateur.
- `wander/OutingPlanDetailCardView.swift` — composer et rendre le groupe total.
- `wander/OutingAttendanceService.swift` — observer à la demande le groupe de
  la fiche sélectionnée et publier son état de chargement.
- `firestore.rules` — autoriser la liste courante aux amis acceptés.
- `firebase-tests/tests/outing-event-attendances.rules.test.mjs` — couvrir la
  nouvelle matrice d’autorisation et ses refus.
- `wander/FriendSyncService.swift` — proposer une révocation en deux phases.
- `functions/src/index.ts` — déclencher le nettoyage après passage à
  `revoking`.
- `functions/src/friendshipCleanupLogic.ts` — implémenter le calcul et le
  nettoyage idempotent des participations révoquées.
- `functions/src/friendshipCleanupLogic.test.ts` — couvrir la logique de
  nettoyage, le cutoff et les reprises.
- `firebase-tests/tests/friendships.rules.test.mjs` — couvrir le tombstone
  `revoking` et l’arrêt immédiat des accès sociaux.
- `docs/plans/2026-08-31-afficher-organisateur-fiche-evenement.md` — suivre le
  travail et sa validation.
- `docs/notifications-apns-configuration.md` — actualiser le scénario social
  multi-compte devenu obsolète.
- `docs/solutions/2026-08-15-lister-firestore-par-appartenance.md` — conserver
  l’historique et signaler la nouvelle frontière produit approuvée.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md`
  — préciser le comportement et les scénarios restant à valider.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`
  — documenter l’ordre, le total, l’accès avant inscription et l’accessibilité.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md`
  — documenter la matrice Firestore et le cycle de vie du listener sélectionné.
- `todos/` — uniquement si la revue découvre une anomalie non résolue.

## Révision approuvée — nettoyage des participations révoquées

### Outcome

La révocation coupe immédiatement tous les accès sociaux, puis retire de façon
idempotente les participations reliant les deux anciens amis dans les deux sens.
Après nettoyage, propriétaire et spectateurs autorisés voient le même roster,
sans avatar ni total résiduel.

### Scope

- remplacer la suppression directe d’une amitié `accepted` par une transition
  atomique vers `revoking`, horodatée avec `revokedAt` ;
- conserver toutes les autorisations sociales strictement limitées à
  `accepted`, afin de couper l’accès dès cette transition ;
- ajouter une Cloud Function qui supprime en lots les participations où A est
  propriétaire et B participant, puis l’inverse ;
- ne supprimer que les documents dont `joinedAt <= revokedAt`, pour protéger
  une nouvelle amitié et une nouvelle inscription contre une exécution tardive ;
- supprimer conditionnellement le tombstone `revoking` après un nettoyage
  réussi et rendre les reprises idempotentes ;
- réutiliser la primitive de nettoyage pour identifier les éventuels documents
  orphelins antérieurs, sans exécuter de mutation distante dans cette tâche ;
- résoudre le timeout de type-check introduit dans `ContentView` en extrayant
  la synchronisation de sélection hors du grand `body`, sans changer l’UX.

### Non-goals

- ne pas déployer les règles ou fonctions, ni exécuter un nettoyage distant,
  sans une approbation dédiée ;
- ne pas rendre les relations d’amitié tierces lisibles par le client ;
- ne pas modifier le schéma d’un événement ou d’une participation ;
- ne pas ajouter de nouveau parcours visuel de révocation.

### Implementation steps

1. Ajouter et tester le statut `revoking` immuable et sa transition autorisée
   depuis une relation `accepted`.
2. Adapter `FriendSyncService.removeFriend` pour écrire ce tombstone et traiter
   l’opération comme une révocation locale immédiate.
3. Implémenter une logique pure de sélection des participations à supprimer,
   avec cutoff `revokedAt`, puis l’orchestration Firestore en lots et la
   suppression conditionnelle du tombstone.
4. Tester les deux directions, plusieurs événements, les retries, les données
   tierces et une réinscription postérieure au cutoff.
5. Vérifier dans l’émulateur que `revoking` coupe immédiatement lecture et
   création, puis que le roster de l’organisateur et celui d’un spectateur ne
   contiennent plus l’ancien ami après nettoyage.
6. Simplifier `ContentView`, recompiler, analyser, relire l’ensemble et mettre à
   jour le plan, le todo et les documentations maintenues.

### Risks

- la Cloud Function reste asynchrone : le statut `revoking` coupe l’ancien ami
  immédiatement, mais un spectateur peut conserver le document résiduel jusqu’à
  la fin du trigger ; les tests doivent borner et rendre cette fenêtre visible ;
- une exécution tardive ne doit jamais supprimer une participation créée après
  une nouvelle amitié ; le cutoff serveur est obligatoire ;
- un échec partiel doit être reprenable sans supprimer le tombstone trop tôt ;
- les documents orphelins historiques demandent un audit et une éventuelle
  opération distante séparément approuvée.

### Validation and acceptance

- tests de règles : transition valide, mutations interdites, accès coupés dès
  `revoking`, listes toujours bornées à la publication courante ;
- tests Functions : nettoyage bidirectionnel, lots, idempotence, cutoff,
  données tierces intactes et tombstone supprimé seulement après succès ;
- scénario A organisateur, B révoqué, C spectateur : B disparaît du roster et
  le total devient identique chez A et C après nettoyage ;
- build et analyse Xcode réussis, sans timeout de type-check ni nouvel
  avertissement ;
- aucun déploiement ou nettoyage distant effectué par cette tâche.

## Implementation

- [x] Passer le plan en `in_progress` avant la première modification produit.
- [x] Ajouter l’organisateur au modèle de présentation.
- [x] Composer le groupe organisateur-en-premier sans doublon.
- [x] Utiliser le groupe pour les avatars, le total et VoiceOver.
- [x] Mettre à jour le backlog et la documentation UX Obsidian.
- [x] Simplifier et relire le changement.
- [x] Exécuter les validations et consigner leurs résultats.
- [x] Passer la révision approuvée en `in_progress` avant le changement visuel.
- [x] Porter la pile à six avatars et ajouter le chevauchement léger.
- [x] Actualiser les deux notes Obsidian avec la nouvelle limite.
- [x] Recompiler, analyser et relire la révision.
- [x] Consigner la validation révisée et ses limites interactives.
- [x] Enregistrer l’approbation du chevauchement renforcé et démarrer la révision.
- [x] Porter le chevauchement horizontal de huit à douze points.
- [x] Actualiser la documentation UX Obsidian avec la valeur retenue.
- [x] Recompiler, analyser et relire la révision du chevauchement.
- [x] Consigner la validation et sa limite interactive.
- [x] Enregistrer l’approbation de la visibilité avant inscription et démarrer
      cette révision.
- [x] Étendre et tester la règle de liste Firestore pour les amis acceptés.
- [x] Observer le groupe de la fiche sélectionnée sans précharger les autres.
- [x] Propager les états de chargement, disponibilité et indisponibilité.
- [x] Afficher le groupe et l’état personnel avant comme après inscription.
- [x] Actualiser la documentation du dépôt et les trois notes Obsidian.
- [x] Recompiler, analyser, exécuter les tests de règles et relire la révision.
- [x] Consigner les validations et leurs éventuelles limites interactives.
- [x] Obtenir l’approbation explicite de la révision de révocation avant toute
      modification de `FriendSyncService`, des Functions ou du schéma d’amitié.
- [x] Implémenter et tester la transition `accepted` vers `revoking`.
- [x] Implémenter et tester le nettoyage backend bidirectionnel et idempotent.
- [x] Résoudre le timeout de type-check de `ContentView` et revalider le client.
- [x] Actualiser `todos/012` et les documentations concernées.

## Edge cases and risks

- Une donnée de participation invalide pourrait répéter le propriétaire — la
  composition filtre systématiquement son identifiant.
- L’avatar local peut être vide pendant la préparation du profil —
  `ProfileAvatarView` conserve son repli SF Symbol existant.
- L’organisateur doit rester visible lorsque plus de six personnes sont
  prévues — il occupe toujours la première place et `+N` reflète le reste.
- Le chevauchement pourrait fusionner visuellement deux illustrations — une
  fine bordure de couleur système conserve leur séparation sans effet décoratif.
- Un ami accepté voit désormais les identifiants, pseudos, avatars et dates
  d’inscription stockés dans les documents téléchargés, même lorsque ces
  personnes ne sont pas ses propres amis ; cette extension produit est
  explicitement approuvée et reste bornée à l’amitié avec l’organisateur.
- Une écoute ouverte pour chaque événement augmenterait inutilement les lectures
  Firestore — une simple prévisualisation non rejointe est limitée à la fiche
  actuellement sélectionnée.
- Un snapshot encore absent ou refusé ne doit pas être présenté comme un groupe
  vide — la fiche affiche un état de chargement ou d’indisponibilité.
- Une révocation doit fermer le listener et effacer immédiatement les personnes
  dérivées, même si Firestore signale d’abord une erreur de permission.
- Le vault Obsidian peut nécessiter une autorisation d’écriture distincte — si
  elle manque, signaler précisément les notes et sections non mises à jour.

## Validation

- [x] Le build Debug générique pour simulateur réussit sans nouvel avertissement.
- [x] `git diff --check` réussit.
- [ ] L’organisateur seul apparaît comme une personne avec son avatar.
- [ ] Un ami seul inscrit voit deux personnes et les deux avatars.
- [ ] Rejoindre ou quitter actualise le total sans dupliquer l’organisateur.
- [ ] Six personnes affichent six avatars légèrement chevauchés sans `+N`.
- [ ] Plus de six personnes conserve l’organisateur en premier et un `+N` exact.
- [ ] Un ami accepté non inscrit voit le groupe complet tout en conservant
      « Vous ne participez pas » et « Je participe ».
- [ ] Rejoindre puis quitter ne masque ni ne duplique le groupe sélectionné.
- [ ] Une arrivée ou un départ tiers actualise la fiche ouverte en direct.
- [ ] Chargement et refus n’affichent jamais un faux total d’une personne.
- [x] Pending, non-ami et relation révoquée ne peuvent pas lister le groupe.
- [x] Une requête non filtrée ou visant une ancienne publication reste refusée.
- [ ] VoiceOver distingue l’organisation des inscriptions.
- [ ] Dynamic Type et les modes clair/sombre restent lisibles.
- [x] Les trois notes Obsidian rendent correctement leurs propriétés, wikiliens
      et contenu dans Reading View.

### Résultats de validation — révision six avatars

- `xcodebuild ... build` réussit sur la destination générique iOS Simulator.
- `xcodebuild ... analyze` réussit. Le seul diagnostic est l’avertissement
  préexistant de `CFBundleVersion` : extension `15`, application `27`.
- `git diff --check` réussit.
- La revue statique confirme la limite à six, le chevauchement de huit points,
  le calcul `+N` à partir de la septième personne et la conservation de
  l’organisateur en première position. Aucun finding P1 à P3 n’a été relevé.
- La fine bordure s’appuie sur `systemBackground`, et l’annonce VoiceOver
  continue de décrire le groupe complet indépendamment de la limite visuelle.
- `Backlog features.md` et `Documentation UX.md` ont été contrôlés dans Obsidian
  1.13.7 en mode Aperçu : propriétés, wikiliens et passages révisés sont rendus.
- Le simulateur reste arrêté sur l’écran de connexion Apple. Sans session
  authentifiée et sans cible XCTest, les cas organisateur seul, 2, 6 et plus de
  6 personnes, ainsi que VoiceOver, Dynamic Type et clair/sombre, restent à
  valider interactivement. Le plan conserve donc le statut `in_progress`.

### Résultats de validation — chevauchement renforcé

- Le chevauchement passe de huit à douze points. Chaque avatar de 32 points
  conserve 20 points visibles, et six avatars occupent 132 points avant le
  séparateur externe de `+N`.
- `xcodebuild ... build`, `xcodebuild ... analyze` et `git diff --check`
  réussissent. Le seul diagnostic reste l’avertissement `CFBundleVersion`
  préexistant : extension `15`, application `27`.
- La revue ciblée confirme que la taille, la limite de six, l’ordre avec
  l’organisateur en premier, la bordure système, le calcul `+N` et VoiceOver
  sont inchangés. Aucun finding P1 à P3 n’a été relevé.
- `Documentation UX.md` a été contrôlé dans Obsidian 1.13.7 en mode Aperçu :
  propriété `updated`, wikiliens et passage « douze points » sont rendus.
- Le contrôle visuel de la fiche reste bloqué par l’écran de connexion Apple du
  simulateur ; le plan conserve donc le statut `in_progress`.

### Résultats de validation — visibilité et révocation

- Les tests Firestore Emulator réussissent : 52 tests sur 52, dont la lecture
  du groupe par un ami accepté non inscrit, les requêtes mal bornées, la
  transition `accepted` vers `revoking` et la coupure immédiate des accès.
- Les tests Functions réussissent : 43 tests actifs sur 43 ; un test
  d’intégration préexistant reste explicitement ignoré. Ils couvrent les deux
  directions, plusieurs événements, les lots, le cutoff inclusif, les reprises
  après échec, l’idempotence et la finalisation conditionnelle du tombstone.
- `swiftc -parse` réussit sur les fichiers Swift modifiés. `xcodebuild ... build`
  et `xcodebuild ... analyze` réussissent sans timeout de type-check. Le seul
  diagnostic reste l’avertissement préexistant `CFBundleVersion` : extension
  `15`, application `27`.
- `git diff --check` réussit. La revue statique finale ne relève aucun finding
  P1 à P3 dans le périmètre modifié.
- Les trois notes Obsidian ont leur propriété `updated` actualisée et leurs
  passages révisés ont été contrôlés dans Obsidian 1.13.7 en Reading View.
- Aucun déploiement de règles ou de Functions et aucun nettoyage distant n’ont
  été exécutés. Le scénario physique A organisateur, B révoqué, C spectateur,
  ainsi que les contrôles UI, VoiceOver, Dynamic Type et clair/sombre restent à
  valider ; le plan conserve donc le statut `in_progress`.

## Acceptance criteria

- Le groupe visible commence toujours par l’organisateur et utilise son avatar.
- Le total correspond à l’organisateur plus les inscriptions actives uniques.
- Aucune participation propriétaire ni modification Firestore n’est créée.
- La confidentialité, l’édition, l’itinéraire et la participation ne régressent
  pas.
- Tout ami encore `accepted` de l’organisateur peut voir le groupe avant de
  rejoindre, avec son propre état de participation séparé.
- Aucun listener de prévisualisation n’est conservé après fermeture de la fiche,
  sauf si le compte participe déjà à la sortie.
- Un lecteur non autorisé ne reçoit ni groupe en cache présenté comme actuel, ni
  accès Firestore à la liste.
- Aucun déploiement Firebase distant n’a lieu sans approbation dédiée.

## Review notes

- Hardest decision: préserver la différence entre une inscription Firestore et
  une personne visible tout en présentant un total social compréhensible.
- Rejected alternatives: créer une inscription propriétaire modifierait le
  contrat et les règles ; afficher seulement un avatar dans la ligne
  organisateur laisserait le total social ambigu.
- Least certain: rendu complet avec Dynamic Type et VoiceOver avant validation
  sur le simulateur déjà autorisé.
- Les skills Compound Engineering ne sont pas disponibles dans cette session ;
  le workflow équivalent est appliqué manuellement.
- Le finding P2 `todos/012` est corrigé localement par le tombstone `revoking`
  et le nettoyage backend. Il reste en statut `ready` tant que la Function et
  les règles ne sont pas déployées et que le scénario A/B/C n’est pas validé.
- Compound: la solution existante
  `docs/solutions/2026-08-15-lister-firestore-par-appartenance.md` documente le
  nouvel apprentissage durable sur les révocations asynchrones et leur cutoff.
- Privacy revision: l’ancienne frontière participant/spectateur est remplacée
  par une frontière ami accepté/autre compte. Les anciens plans restent
  historiques et la solution durable reçoit une mention de supersession.

## Validation results

- Le build Debug générique et l’analyse statique Xcode réussissent le
  2026-08-31 avec les dépendances résolues. Le seul avertissement est la
  divergence préexistante de `CFBundleVersion` entre l’extension (`15`) et
  l’application (`27`).
- `git diff --check` réussit.
- Deux revues indépendantes du diff Swift ne trouvent aucun finding P1, P2 ou
  P3 sur la compilation, l’ordre, la déduplication, le total, `+N`, la
  confidentialité, VoiceOver ou le rendu natif.
- `Backlog features.md` et `Documentation UX.md` sont vérifiés dans Obsidian en
  mode Aperçu/Lecture : propriétés `updated`, wikiliens, liste imbriquée,
  passages « résumé social » et « absence de doublon », ainsi que le code
  inline `+N`, sont rendus correctement.
- Le build est installé et lancé sur l’iPhone 17 Simulator déjà démarré. Il
  affiche l’écran « Bienvenue sur Wander » sans session Apple ; la fiche
  événement, VoiceOver, Dynamic Type et les modes clair/sombre ne peuvent donc
  pas être validés en exécution sans connexion du propriétaire.
- Le plan reste `in_progress` jusqu’à la validation interactive des scénarios
  encore décochés ; aucun simulateur supplémentaire n’a été démarré.

## Révision approuvée — réponse négative explicite

Le 2026-09-01, Samuel a demandé deux choix persistants pour chaque ami autorisé :
« Je participe » et « Non, je ne participe pas ». Il a précisé que les
réponses négatives doivent être visibles par toutes les personnes ayant accès
à l’événement, dans une liste d’avatars séparée, et déclencher une
notification vers l’organisateur et les participants actuels. Cette révision a
été présentée puis explicitement approuvée avant toute modification.

### Outcome

La fiche distingue « pas encore répondu », participation positive et réponse
négative. Deux groupes d’avatars séparés affichent les participants et les amis
ayant répondu non. Une nouvelle réponse négative notifie l’organisateur et les
participants actuels, sauf son auteur, avec une route minimale vers
l’événement.

### Scope

- Included:
  - document négatif déterministe, lié à l’événement et à sa publication ;
  - transition atomique et exclusive entre participation et refus ;
  - lecture du groupe négatif par l’organisateur et ses amis encore `accepted` ;
  - deux listes d’avatars accessibles et deux actions natives persistantes ;
  - broadcast du refus vers l’organisateur et les participants actuels ;
  - nettoyage lors d’une suppression d’événement, d’amitié ou de compte ;
  - règles Firestore, tests de sécurité et tests de notifications.
- Not included:
  - notification des amis qui voient l’événement sans y participer ;
  - réponse « Peut-être », commentaires ou justification du refus ;
  - déploiement distant implicite des règles ou des Functions.

### Affected files

- `wander/OutingDecline.swift`
- `wander/OutingAttendanceService.swift`
- `wander/MapWithFogView.swift`
- `wander/ContentView.swift`
- `wander/OutingPlanDetailCardView.swift`
- `wander/FriendSyncService.swift`
- `wander/NotificationService.swift`
- `firestore.rules`
- `firebase-tests/tests/outing-event-attendances.rules.test.mjs`
- `functions/src/index.ts`
- `functions/src/notificationLogic.ts`
- `functions/src/notificationLogic.test.ts`
- `functions/src/friendshipCleanupLogic.ts`
- `functions/src/friendshipCleanupLogic.test.ts`
- `docs/notifications-apns-configuration.md`
- `Backlog features.md`, `Documentation UX.md` et
  `Documentation technique.md` dans le vault Obsidian Wander.

### Implementation checklist

- [x] Obtenir l’approbation explicite de la révision.
- [x] Ajouter et valider le contrat Firestore d’une réponse négative.
- [x] Garantir l’exclusivité oui/non dans une écriture atomique.
- [x] Observer les deux réponses personnelles sans faux état transitoire.
- [x] Afficher les deux groupes d’avatars aux lecteurs autorisés.
- [x] Ajouter le broadcast de refus et son identité idempotente.
- [x] Étendre les nettoyages d’événement, d’amitié et de compte.
- [x] Mettre à jour les documentations détaillées et Obsidian.
- [x] Simplifier, tester, compiler, valider et effectuer la revue finale.

### Risks

- Les deux listeners personnels doivent attendre leurs snapshots serveur avant
  de conclure à une absence de réponse.
- Les règles doivent interdire la coexistence d’un document positif et négatif
  tout en autorisant leur permutation dans un même batch.
- Le trigger négatif doit relire l’état courant afin de ne jamais notifier un
  refus déjà remplacé par une participation.
- Les listes doivent rester lisibles sous Dynamic Type sans confondre les
  personnes qui viennent avec celles qui ont décliné.

### Validation

- [x] Tests Firestore des créations, permutations, lectures et refus d’accès.
- [x] Tests Functions du ciblage, du contenu et de l’idempotence du refus.
- [x] Tests des nettoyages d’événement, d’amitié et de compte.
- [x] Build et analyse Debug pour iOS Simulator.
- [ ] Scénarios oui/non/non-répondu sur l’iPhone 17 Simulator.
- [ ] VoiceOver, Dynamic Type, clair/sombre et erreurs réseau.
- [x] `git diff --check` et revue finale sans finding P1 à P3.

### Résultats de validation — réponse négative explicite

- Les tests Firestore Emulator réussissent : 56 tests sur 56. Ils couvrent la
  création, la permutation atomique oui/non, l’exclusivité des deux documents,
  la visibilité du groupe et les refus d’accès.
- Les tests Functions réussissent : 47 tests actifs sur 47 ; un test
  d’intégration préexistant reste explicitement ignoré. Le ciblage, le contenu,
  l’identité idempotente et les nettoyages des réponses négatives sont couverts.
- Le build Debug et l’analyse statique Xcode réussissent. Le seul diagnostic
  reste l’avertissement `CFBundleVersion` préexistant : extension `15`,
  application `27`.
- `git diff --check` réussit et la revue finale ne relève aucun finding P1 à P3
  dans le périmètre de cette révision.
- Les trois notes Obsidian sont contrôlées dans Obsidian 1.13.7 en mode Aperçu :
  propriété `updated`, wikiliens et nouveaux passages sont rendus.
- Le simulateur autorisé reste sur l’écran de connexion Apple sans session ;
  les scénarios interactifs, VoiceOver, Dynamic Type, clair/sombre et erreurs
  réseau restent donc à valider. Aucun autre simulateur n’a été démarré.
- Aucun déploiement Firebase distant n’a été exécuté. Le plan conserve son
  statut global `in_progress` jusqu’aux validations interactives restantes.

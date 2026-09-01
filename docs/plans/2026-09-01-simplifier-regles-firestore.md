---
title: "Simplifier les règles Firestore sans ouvrir les données sociales"
status: completed
date: 2026-09-01
completed_at: 2026-09-01T13:39:22+09:00
owner: "Samuel"
related:
  - "../../todos/021-done-p2-simplify-firestore-rules.md"
  - "../../todos/022-ready-p2-refondre-modele-donnees-firestore.md"
  - "../../todos/012-ready-p2-nettoyer-participations-revoquees.md"
tags: [plan, firebase, firestore, security]
---

# Simplifier les règles Firestore sans ouvrir les données sociales

## Outcome

Réduire fortement la complexité des règles Firestore afin qu'une évolution de
schéma ou de payload ne bloque plus les parcours de l'application, notamment la
lecture et l'écriture des réponses à une sortie. Les frontières sociales
restent néanmoins explicites : un non-ami ne voit ni la carte ni les sorties
d'un compte, et seul un ami accepté de l'organisateur peut répondre à sa sortie.

## Context

- La fiche d'une sortie peut afficher le groupe tout en laissant la réponse dans
  l'état « Participation indisponible » lorsqu'un seul des listeners personnels
  `attendees` ou `declines` reçoit `permission-denied`.
- `firestore.rules` dépasse actuellement 1 000 lignes et combine autorisation,
  validation de schéma, format, timestamps, état de compte et cohérence entre
  documents.
- Firestore évalue les requêtes contre tous leurs résultats possibles : des
  conditions dépendant des champs des résultats rendent les listeners plus
  fragiles qu'une autorisation fondée sur le chemin et la relation sociale.
- Les modifications locales déjà présentes pour les refus de sortie et le
  nettoyage après révocation doivent être conservées, pas restaurées.

## Scope

- Included:
  - authentification Firebase obligatoire pour tout accès client ;
  - lecture des profils limitée au propriétaire et aux relations `pending` ou
    `accepted`, avec résolution ponctuelle des codes amis ;
  - lecture des positions, explorations, sorties et groupes limitée au
    propriétaire et à ses amis `accepted` ;
  - création d'une demande d'amitié en `pending`, acceptation uniquement par le
    destinataire et participants immuables ;
  - coupure immédiate des accès sociaux en `revoking` ;
  - écritures limitées au propriétaire du chemin ou à l'auteur de la réponse ;
  - tokens d'appareil privés et collections backend interdites aux clients ;
  - suppression des validations de forme et de schéma sans effet direct sur
    l'autorisation.
- Not included:
  - refonte du modèle de données suivie dans le todo 022 ;
  - modification fonctionnelle des services Swift ou des Cloud Functions ;
  - migration ou suppression de données distantes ;
  - déploiement des règles Firebase ;
  - ouverture publique ou accès social aux comptes non amis.

## Proposed approach

Conserver quelques prédicats orientés domaine : session authentifiée,
appartenance à une paire, amitié acceptée, destinataire d'une demande,
propriétaire d'un chemin et auteur d'une réponse. Supprimer les allowlists de
champs, regex, catalogues, limites de texte, comparaisons de timestamps, lecture
du profil pour valider un payload et contrainte de requête par `publicationId`.

Les règles de lecture d'un événement ou de son groupe dépendront uniquement de
`ownerId` capturé dans le chemin et d'une amitié `accepted`. Ainsi, la requête
de liste n'aura plus à prouver une condition sur chaque document retourné. Le
client continuera à filtrer la publication courante et à décoder les données
avant affichage.

## Affected files

- `docs/plans/2026-09-01-simplifier-regles-firestore.md` — source de vérité du
  travail et de sa validation.
- `firestore.rules` — nouvelle matrice d'autorisation simplifiée.
- `firebase-tests/tests/device-tokens.rules.test.mjs` — confidentialité des
  appareils sans validation de payload.
- `firebase-tests/tests/friendships.rules.test.mjs` — consentement et révocation.
- `firebase-tests/tests/location-push.rules.test.mjs` — appareils et dispatches.
- `firebase-tests/tests/outing-event-attendances.rules.test.mjs` — accès aux
  groupes et identité des réponses.
- `firebase-tests/tests/outing-events.rules.test.mjs` — lecture sociale et
  propriété des événements.
- `firebase-tests/tests/profile-avatar.rules.test.mjs` — profil propriétaire et
  lecture sociale sans catalogue imposé par les règles.
- `firebase-tests/tests/social-access.rules.test.mjs` — matrice transversale des
  profils, positions et explorations.
- `todos/021-done-p2-simplify-firestore-rules.md` — résolution du finding.
- `todos/022-ready-p2-refondre-modele-donnees-firestore.md` — retrait de la
  dépendance d'ordre devenue obsolète ; la refonte reste séparée.
- `todos/012-ready-p2-nettoyer-participations-revoquees.md` — alignement des
  garanties de révocation avec les règles simplifiées.
- `docs/solutions/2026-09-01-separer-autorisation-et-schema-firestore.md` — leçon
  réutilisable après validation.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md`
  — statut et nouvelle définition de l'assouplissement.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md`
  — matrice d'autorisation et rôle du client.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`
  — consentement social et états de participation.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/00 - Wander.md`
  — synthèse du statut du chantier Firebase.

Le vault Obsidian est présent mais non inscriptible depuis l'environnement
Codex courant. Si cette limite persiste, les quatre mises à jour ci-dessus
seront consignées comme validation restante sans créer de copie du vault.

## Implementation

- [x] Remplacer les validations imbriquées par la matrice d'autorisation cible.
- [x] Préserver le consentement lors de la création et de l'acceptation d'amitié.
- [x] Autoriser les listes sociales depuis le chemin sans contrainte fragile sur
      les champs retournés.
- [x] Protéger les écritures croisées, tokens et documents backend.
- [x] Adapter les tests de règles aux invariants de sécurité restants.
- [x] Mettre à jour les todos et la documentation technique disponible.
- [x] Effectuer la simplification, la validation et la revue finales.

## Edge cases and risks

- Un client peut écrire des champs additionnels ou des valeurs que sa version ne
  sait pas décoder — les décodeurs Swift doivent continuer à ignorer ou rejeter
  ces documents sans exposer de données étrangères.
- Une réponse peut viser une ancienne `publicationId` — le client filtre la
  publication courante ; l'auteur ne peut pas usurper un autre participant.
- Un demandeur pourrait tenter de s'accorder l'amitié — la transition
  `pending` vers `accepted` reste réservée au destinataire.
- Une révocation en cours ne doit pas prolonger l'accès — seules les relations
  `accepted` autorisent les lectures sociales et les réponses.
- Les règles locales ne corrigent pas l'appareil tant qu'elles ne sont pas
  déployées — le déploiement et la validation distante nécessitent une
  approbation séparée.

## Validation

- [x] `git diff --check` réussit.
- [x] La suite des règles réussit avec JDK 21.
- [x] Un compte déconnecté est refusé partout.
- [x] Un étranger et une relation `pending` ou `revoking` ne peuvent lire ni
      position, exploration, événement ou groupe, ni répondre à la sortie.
- [x] Un ami `accepted` peut lire les données sociales, écouter `attendees` et
      `declines`, puis répondre pour son propre UID avec un payload enrichi.
- [x] Aucun compte ne peut écrire le profil, la position, l'événement, le token
      ou la réponse d'un autre compte.
- [x] Le build Debug générique réussit sans nouveaux avertissements.
- [x] Le diff est revu contre ce plan et tout finding résiduel est classé.
- [x] Les limites Obsidian et de déploiement sont consignées exactement.

### Résultats

- `firestore.rules` passe de 1 048 à 282 lignes.
- La suite locale réussit avec 37/37 tests sur 7 suites, Firebase Emulator Suite
  et JDK 21.
- Le test supplémentaire de revue refuse les réponses sous un événement absent.
- Le build Debug générique iOS réussit avec `CODE_SIGNING_ALLOWED=NO`. Les seuls
  avertissements de version de bundle des extensions étaient déjà présents
  avant cet incrément ; aucun nouvel avertissement n'a été introduit.
- `git diff --check` réussit et le scan statique ne retrouve plus d'allowlist de
  champs, regex, catalogue d'avatars, comparaison de temps ou filtre de
  publication dans les règles.
- Aucun déploiement Firebase, aucune migration et aucune suppression de donnée
  distante n'ont été exécutés.

### Validation externe restante

Le vault Obsidian est lisible mais non inscriptible depuis cet environnement ;
sa validation en reading view n'a donc pas réussi et aucune copie de
substitution n'a été créée. Les mises à jour exactes restantes sont :

- `Backlog features.md` — passer « Simplifier et assouplir l’évolution des
  règles Firestore » en terminé, remplacer l'ancien ordre avec le todo 022 et
  pointer vers le plan et le todo 021 terminé ;
- `Documentation technique.md` — actualiser « Schéma Firestore principal »,
  « Événements et participations », « Validation et outils » (37/37 tests) et
  « Fichiers repères » avec la nouvelle séparation autorisation/schéma ;
- `Documentation UX.md` — préciser dans « Principes d’expérience », « Sorties
  prévues » et « Permissions et confidentialité » que carte, sorties, groupes
  et réponses sont réservés aux amis acceptés ;
- `00 - Wander.md` — actualiser `updated`, « État du projet » et le résumé de la
  validation Firebase.

La vérification sur deux comptes réels reste également à exécuter après un
déploiement explicitement approuvé.

## Acceptance criteria

- `firestore.rules` est ramené à une matrice courte et lisible sans validation
  exhaustive de schéma.
- Les deux listeners de réponse d'un ami accepté sont autorisés sans dépendre
  d'une clause `where` sur la publication.
- Les frontières sociales et de propriété décrites dans l'Outcome sont testées.
- Aucun changement distant, aucune donnée et aucun travail local existant ne
  sont supprimés.

## Review notes

- Hardest decision: distinguer les validations de sécurité minimales des
  validations de schéma qui bloquent l'évolution fonctionnelle.
- Rejected alternatives: règles publiques ; lecture sociale pour tout compte
  authentifié ; conservation des allowlists exactes de champs ; refonte du
  modèle Firestore dans le même incrément.
- Least certain: version exacte des règles actuellement déployées et confirmation
  du symptôme sur deux comptes après un futur déploiement approuvé.
- Residual finding: le todo bloqué `002` conserve une future étape de règles
  limitées à `apple.com`. La matrice approuvée exige désormais une session
  Firebase sans inspecter le provider ; cette formulation devra être conciliée
  lors de la reprise de ce finding Apple, avant tout déploiement d'authentification.
- Historical documentation: les anciens plans et solutions décrivent les
  validations strictes qui existaient lors de leur clôture. La solution de ce
  plan documente explicitement leur remplacement sans réécrire ces historiques.

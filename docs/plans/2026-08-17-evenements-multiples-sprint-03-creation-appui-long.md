---
title: "Événements multiples — Sprint 3 — Création par appui long"
status: in_progress
sprint: 3
date: 2026-08-17
approved_at: "2026-08-17T10:36:34+09:00"
started_at: "2026-08-17T10:37:00+09:00"
haptic_revision_approved_at: "2026-08-17T11:01:33+09:00"
location_footer_removal_approved_at: "2026-08-17T12:28:21+09:00"
category_revision_approved_at: "2026-08-17T12:38:25+09:00"
category_revision_started_at: "2026-08-17T12:38:25+09:00"
strict_category_revision_approved_at: "2026-08-17T12:48:25+09:00"
tags: [plan, sprint, ios, swiftui, mapkit, ux]
---

# Sprint 3 — Création d’événement par appui long

## Outcome

Permettre de créer un nouvel événement en maintenant un doigt sur un endroit
vide de la carte principale. Le point choisi ouvre directement un formulaire
simple, sans bouton d’ajout, recherche textuelle ni mini-carte. Chaque nouvel
appui long crée un événement indépendant.

## Scope

- Reconnaître un appui long à un doigt sur la carte principale.
- Convertir la position du geste en coordonnée et ouvrir le compositeur une
  seule fois au début du geste.
- Ignorer les appuis longs sur les annotations et les contrôles de la carte.
- Conserver les gestes MapKit usuels, notamment le déplacement et le zoom.
- Résoudre automatiquement le nom et l’adresse du point, avec un libellé et
  les coordonnées comme repli hors ligne.
- Afficher le lieu comme information fixe dans le compositeur.
- Supprimer le bouton d’ajout, la recherche textuelle et la mini-carte.
- Conserver l’édition de l’heure et l’annulation d’un événement existant ; son
  lieu reste fixe pendant l’édition.
- Employer « événement » dans les libellés concernés par ce parcours.
- Produire un unique retour haptique moyen quand l’appui long devient valide,
  juste avant l’ouverture du compositeur.
- Ne présenter aucun texte d’aide sous la section « Lieu », en création comme
  en modification.
- Exiger à la création une catégorie parmi Café, Repas, Verre, Balade,
  Culture, Sport et Autre, sans choix présélectionné.
- Afficher la catégorie dans la fiche de l’événement et la conserver en lecture
  seule lors d’une modification.
- Persister un identifiant de catégorie stable et obligatoire dans Firestore ;
  tout document sans catégorie ou avec une valeur inconnue est rejeté.

## Non-goals

- Aucun autre moyen de créer un événement en parallèle de l’appui long.
- Aucun ajustement du point dans le compositeur.
- Aucune recherche manuelle de lieu ou d’adresse.
- Aucune expiration, règle TTL ou migration de données.
- Aucune suppression distante par Codex ; le propriétaire supprimera lui-même
  les anciens événements en ligne avant d’utiliser le nouveau contrat strict.
- Aucun changement des identités, chemins, dates d’audit ou durées de vie du
  contrat Firestore livré aux Sprints 1 et 2.
- Aucun changement visuel des marqueurs de la carte selon la catégorie.
- Aucun changement du contenu des notifications selon la catégorie.
- Aucune modification de la catégorie après publication dans ce sprint.
- Aucun déploiement Firebase, commit ou nettoyage distant.

## Dependencies

- Sprint 1 terminé : backend `events` sans expiration.
- Sprint 2 terminé : application iOS indexée par `eventId`.

## Affected files

- `wander/MapWithFogView.swift`
- `wander/ContentView.swift`
- `wander/OutingPlanComposerView.swift`
- `wander/OutingPlan.swift`
- `wander/OutingPlanService.swift`
- `wander/OutingPlanDetailCardView.swift`
- `firestore.rules`
- `firebase-tests/tests/outing-events.rules.test.mjs`
- `docs/plans/2026-08-17-evenements-multiples-sprint-03-creation-appui-long.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/00 - Wander.md`

## Implementation checklist

- [x] Installer et retirer proprement le reconnaisseur d’appui long MapKit.
- [x] Transmettre exactement une coordonnée valide à `ContentView` par geste.
- [x] Ouvrir le compositeur de création avec cette coordonnée.
- [x] Supprimer le bouton d’ajout et son calcul de position par défaut.
- [x] Retirer la recherche, ses états et ses requêtes.
- [x] Retirer la mini-carte et rendre le lieu non modifiable dans le formulaire.
- [x] Conserver le géocodage inverse automatique et un repli publiable.
- [x] Conserver l’édition de l’heure et l’annulation d’un événement précis.
- [ ] Mettre à jour la documentation Obsidian concernée pour la révision
  des catégories.
- [x] Simplifier et revoir le diff.
- [x] Ajouter le retour haptique unique à la reconnaissance de l’appui long.
- [x] Supprimer complètement le pied de texte de la section « Lieu ».
- [x] Ajouter les catégories persistées et leur présentation native.
- [x] Exiger un choix explicite dans le compositeur de création.
- [x] Rejeter les événements sans catégorie, sans valeur de repli.
- [x] Afficher la catégorie dans la fiche et en lecture seule à l’édition.
- [x] Exiger le champ dans les règles Firestore.
- [x] Couvrir les catégories autorisées, absentes et invalides par les tests.

## Risks

- Un callback exécuté pour plusieurs états du geste ouvrirait plusieurs feuilles ;
  seul l’état `.began` doit créer une demande.
- Le retour haptique ne doit pas se répéter pendant le maintien du doigt ; il
  doit partager la même garde `.began` que l’ouverture du compositeur.
- Le reconnaisseur pourrait perturber le panoramique MapKit ; sa tolérance au
  mouvement et ses règles de reconnaissance doivent laisser les gestes natifs
  fonctionner.
- Un appui sur un marqueur pourrait créer un événement involontaire ; les vues
  d’annotation et contrôles doivent être exclus.
- Le géocodage inverse peut échouer ou être lent ; le point doit rester
  publiable avec « Lieu sélectionné » et ses coordonnées.
- Sans bouton alternatif, l’action est moins découvrable et moins accessible ;
  la carte recevra un libellé et une indication d’accessibilité, sans rétablir
  un autre parcours de création.
- Le contrat strict rend incompatibles les anciens documents et les anciennes
  versions de l’application qui n’écrivent pas `category` ; ce choix est accepté
  et les événements distants existants seront supprimés manuellement.

## Validation

- [x] Le projet compile sans nouvelle erreur ni nouvel avertissement Swift.
- [ ] Un appui long sur un endroit vide ouvre le compositeur au bon point.
- [ ] Un geste ne déclenche qu’une seule ouverture.
- [x] Un geste ne déclenche qu’un seul retour haptique.
- [ ] Déplacer ou zoomer la carte ne crée aucun événement.
- [ ] Un appui long sur un marqueur ou un contrôle ne crée aucun événement.
- [ ] Plusieurs appuis longs successifs peuvent publier plusieurs événements.
- [x] Le bouton d’ajout, la recherche textuelle et la mini-carte ont disparu.
- [x] L’édition conserve le lieu et permet encore de modifier l’heure ou
  d’annuler l’événement ciblé.
- [x] Le formulaire reste publiable si le géocodage inverse échoue.
- [x] Le build Debug réussit pour l’iPhone 17 configuré sans démarrer ni créer
  de simulateur supplémentaire.
- [x] Les quatre notes Wander sont vérifiées dans la vue de lecture d’Obsidian.
- [x] Aucun déploiement Firebase, commit ou nettoyage distant n’est exécuté.
- [x] La publication reste désactivée tant qu’aucune catégorie n’est choisie.
- [x] Les sept catégories sont publiables et exposées dans la fiche.
- [x] Un événement sans `category` est refusé sans valeur de repli.
- [x] Une catégorie inconnue ou d’un type invalide est refusée par les règles.
- [x] Les tests complets des règles Firestore réussissent.
- [ ] Dynamic Type, VoiceOver et les modes clair/sombre sont vérifiés pour le
  sélecteur et le libellé de catégorie.

### Résultats exacts au 17 août 2026

- `xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration
  Debug -destination 'platform=iOS Simulator,name=iPhone 17'
  CODE_SIGNING_ALLOWED=NO build` — succès, code de sortie `0` ; seul le message
  Xcode `[MT] IDERunDestination: Supported platforms... empty` a été émis, sans
  avertissement Swift.
- `git diff --check` — succès, aucune erreur d’espace ou de patch.
- Recherche ciblée — aucune `MKLocalSearch`, `MapReader`, `SpatialTapGesture`,
  recherche textuelle ni icône d’ajout ne subsiste dans le compositeur et le
  parcours d’entrée concernés.
- Revue structurelle — durée minimale de `0,5 s`, callback limité à `.began`,
  coordonnée validée, annotations et contrôles exclus, reconnaissance
  simultanée autorisée avec les gestes MapKit et création sans `eventId`
  existant.
- Obsidian — les quatre notes ont été ouvertes en mode Aperçu ; propriétés,
  wikilinks, tableau, callout et diagramme Mermaid sont rendus.
- `xcrun simctl list devices booted` — aucun simulateur démarré. Aucun appareil
  n’a été démarré ou créé ; les cinq validations gestuelles interactives
  ci-dessus restent donc à exécuter sur l’iPhone 17 déjà démarré lors d’une
  prochaine session.
- Revue de code — aucun finding nouveau ne justifie un fichier `todos/`.
- Révision haptique — `UIImpactFeedbackGenerator(style: .medium)` est préparé
  quand le toucher est accepté puis `impactOccurred()` est appelé une seule
  fois, sous la garde `.began` et après validation de la coordonnée. Le build
  Debug suivant la révision réussit avec le code de sortie `0` ; l’intensité
  tactile reste à confirmer sur un iPhone réel.
- Révision du formulaire — le pied de section « Lieu » a été supprimé en
  création et en modification. Les deux anciens textes sont absents du code,
  `git diff --check` réussit et le build Debug suivant la révision se termine
  avec le code de sortie `0`.
- Révision des catégories — le build Debug sur la destination iPhone 17
  réussit avec le code de sortie `0`, sans nouvelle erreur ni nouvel
  avertissement Swift ; seul le message Xcode existant sur les plateformes du
  scheme est émis.
- `npm --prefix firebase-tests run test:rules` avec OpenJDK 21 — 29 tests
  réussis, aucun échec ; les sept valeurs sont acceptées, tandis que l’absence,
  les valeurs inconnues et les types invalides sont refusés.
- `npm --prefix functions test` — compilation TypeScript réussie, 26 tests
  réussis, aucun échec et un test d’intégration émulateur ignoré comme prévu.
- Revue manuelle — les deux constructions de `OutingPlanDraft` propagent la
  catégorie, tout nouvel événement l’écrit, le décodeur exige le champ et aucun
  finding ne justifie un nouveau fichier `todos/`.
- Révision stricte — le build Debug réussit de nouveau avec le code de sortie
  `0` ; les 29 tests Firestore et les 26 tests Cloud Functions réussissent après
  suppression du fallback. Aucun événement distant n’a été supprimé ou modifié.
- Validation interactive non exécutée : `xcrun simctl list devices booted` ne
  retourne aucun appareil. Aucun Simulator n’a été démarré sans approbation.
- Documentation Obsidian non mise à jour : le vault externe n’est pas
  accessible en écriture dans cette session. Restent à modifier et valider en
  vue de lecture : `Backlog features.md` (« Permettre plusieurs événements
  persistants »), `Documentation technique.md` (« Schéma Firestore principal »
  et « Événements et participations »), `Documentation UX.md` (« Sorties
  prévues » et « États UX essentiels »), puis `00 - Wander.md` (« État du
  projet »), avec mise à jour du frontmatter `updated` pour chaque note.

## Acceptance criteria

- Le seul parcours de création visible est l’appui long sur la carte principale.
- Le point du geste devient le lieu fixe du nouvel événement.
- Le formulaire ne contient ni recherche textuelle ni carte.
- Un nouvel appui long crée un nouvel événement, sans remplacer les précédents.
- Une catégorie explicite est requise à la création et persiste avec
  l’événement.
- La fiche expose la catégorie sans modifier le langage visuel natif de l’app.
- Les interactions ordinaires et les marqueurs de la carte restent utilisables.

## Review notes

- Hardest decision: conserver l’édition existante sans réintroduire de moyen de
  déplacer le point ; l’édition garde donc le lieu et porte sur l’heure ou
  l’annulation.
- Rejected alternatives: conserver le bouton, une mini-carte, une recherche ou
  créer au centre de la carte ; ces solutions contredisent le parcours approuvé.
- Least certain: la validation gestuelle dépend de la disponibilité du seul
  simulateur iPhone 17 déjà démarré.
- Category revision: le choix reste volontairement non présélectionné en
  création et non modifiable ensuite ; les identifiants anglais persistés sont
  découplés des libellés français.
- Strict category revision: aucun fallback n’est conservé ; l’absence de
  `category` invalide le document et la suppression des anciens événements
  distants reste une action manuelle du propriétaire.

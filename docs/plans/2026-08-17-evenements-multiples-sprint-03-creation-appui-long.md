---
title: "Événements multiples — Sprint 3 — Création par appui long"
status: in_progress
sprint: 3
date: 2026-08-17
approved_at: "2026-08-17T10:36:34+09:00"
started_at: "2026-08-17T10:37:00+09:00"
haptic_revision_approved_at: "2026-08-17T11:01:33+09:00"
location_footer_removal_approved_at: "2026-08-17T12:28:21+09:00"
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

## Non-goals

- Aucun autre moyen de créer un événement en parallèle de l’appui long.
- Aucun ajustement du point dans le compositeur.
- Aucune recherche manuelle de lieu ou d’adresse.
- Aucune expiration, règle TTL ou migration de données.
- Aucun changement du contrat Firestore livré aux Sprints 1 et 2.
- Aucun déploiement Firebase, commit ou nettoyage distant.

## Dependencies

- Sprint 1 terminé : backend `events` sans expiration.
- Sprint 2 terminé : application iOS indexée par `eventId`.

## Affected files

- `wander/MapWithFogView.swift`
- `wander/ContentView.swift`
- `wander/OutingPlanComposerView.swift`
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
- [x] Mettre à jour la documentation Obsidian concernée.
- [x] Simplifier et revoir le diff.
- [x] Ajouter le retour haptique unique à la reconnaissance de l’appui long.
- [x] Supprimer complètement le pied de texte de la section « Lieu ».

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

## Acceptance criteria

- Le seul parcours de création visible est l’appui long sur la carte principale.
- Le point du geste devient le lieu fixe du nouvel événement.
- Le formulaire ne contient ni recherche textuelle ni carte.
- Un nouvel appui long crée un nouvel événement, sans remplacer les précédents.
- Les interactions ordinaires et les marqueurs de la carte restent utilisables.

## Review notes

- Hardest decision: conserver l’édition existante sans réintroduire de moyen de
  déplacer le point ; l’édition garde donc le lieu et porte sur l’heure ou
  l’annulation.
- Rejected alternatives: conserver le bouton, une mini-carte, une recherche ou
  créer au centre de la carte ; ces solutions contredisent le parcours approuvé.
- Least certain: la validation gestuelle dépend de la disponibilité du seul
  simulateur iPhone 17 déjà démarré.

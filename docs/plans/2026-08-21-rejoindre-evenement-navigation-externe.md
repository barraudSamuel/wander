---
title: "Rejoindre un événement avec une application de navigation"
status: in_progress
date: 2026-08-21
owner: "Codex"
approved_at: "2026-08-21T17:14:48+09:00"
in_progress_at: "2026-08-21T17:14:48+09:00"
last_reviewed_at: "2026-08-21T17:27:41+09:00"
related:
  - "2026-08-06-rejoindre-un-ami.md"
  - "../solutions/2026-08-06-navigation-externe-depuis-mapkit.md"
tags: [plan, map, events, navigation, accessibility]
---

# Rejoindre un événement avec une application de navigation

## Outcome

Depuis la fiche d'un événement, tout utilisateur peut toucher une action
secondaire « Itinéraire » puis ouvrir le lieu exact dans Google Maps ou, lorsque
disponible en Corée, dans Naver Map à pied. Cette action reste distincte de la
participation et de l'édition de l'événement.

Le parcours est réussi lorsqu'il réutilise la coordonnée valide de l'événement,
préserve le comportement existant pour rejoindre un ami, ne demande aucune clé
d'API et ferme proprement le choix si l'événement devient inaccessible.

## Context

- `wander/OutingPlanDetailCardView.swift` présente déjà le lieu, la date,
  l'adresse, l'organisateur, les participants et les actions métier.
- `wander/ContentView.swift` ouvre déjà Google Maps et Naver Map pour rejoindre
  un ami, avec URL structurée, repli web Google, contrôle d'installation Naver
  et bornes de couverture documentées.
- `wander/OutingPlan.swift` contient déjà le nom et la coordonnée validée du
  lieu ; aucun nouveau champ distant n'est requis.
- Le plan historique de la fiche événement excluait la navigation externe : ce
  changement reste donc un plan autonome.

## Scope

- Included:
  - bouton natif « Itinéraire » dans la fiche de chaque événement ;
  - choix Google Maps et Naver Map dans une alerte native ;
  - destination reconstruite depuis l'`eventID` encore disponible ;
  - mutualisation des constructeurs d'URL utilisés par les amis et événements ;
  - Google Maps universel avec repli navigateur ;
  - Naver Map à pied seulement si l'app est installée et le lieu en Corée ;
  - Dynamic Type, VoiceOver, mode sombre et réduction des animations.
- Not included:
  - moteur d'itinéraire intégré à Wander ;
  - Apple Plans ou autre application cartographique ;
  - SDK, clé payante ou schéma Google privé ;
  - modification du modèle, de Firebase, des règles ou de `Info.plist`.

## Proposed approach

La fiche expose une fermeture `onOpenDirections` et affiche « Itinéraire »
comme bouton secondaire, disponible aussi bien pour l'organisateur que pour un
ami. `ContentView` conserve uniquement l'identifiant de l'événement ciblé et
reconstruit le nom et la coordonnée depuis `mapOutingPlans` au moment de
l'ouverture.

Les helpers Google et Naver reçoivent une destination générique composée d'un
nom et d'une coordonnée. Le parcours ami continue de reconstruire sa donnée
vivante et la convertit vers ce même type. L'état événement est réconcilié
lorsqu'un événement disparaît afin qu'aucune destination obsolète ne soit
ouverte.

## Affected files

- `wander/OutingPlanDetailCardView.swift` — action secondaire accessible.
- `wander/ContentView.swift` — sélection, alerte et helpers externes partagés.
- `docs/plans/2026-08-21-rejoindre-evenement-navigation-externe.md` — suivi.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md` — état produit.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md` — parcours et validations UX.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md` — responsabilité de navigation externe.
- `todos/` — seulement si la revue découvre une anomalie non résolue.
- `docs/solutions/` — seulement si un apprentissage durable nouveau émerge.

## Implementation

- [x] Marquer le plan `in_progress` avant la première modification produit.
- [x] Ajouter l'action « Itinéraire » à la fiche événement.
- [x] Conserver et réconcilier l'identité de l'événement ciblé.
- [x] Généraliser la construction et l'ouverture des destinations externes.
- [x] Présenter Google Maps et Naver Map selon leur disponibilité.
- [x] Mettre à jour les trois notes Obsidian et leur propriété `updated`.
- [x] Simplifier et relire le changement.
- [x] Compiler le code touché et consigner les résultats.
- [ ] Achever les validations interactives sur le simulateur et l'appareil.

## Edge cases and risks

- Confusion entre participation et déplacement — utiliser le libellé distinct
  « Itinéraire » et un style secondaire.
- Événement annulé pendant l'alerte — résoudre par `eventID` et fermer l'état
  lorsque la collection ne contient plus l'événement.
- Régression du parcours ami — conserver sa validation de relation et de
  coordonnée avant conversion vers la destination générique.
- Naver absent ou hors couverture — masquer son action et conserver Google.
- Google Maps absent — utiliser l'URL HTTPS universelle et son repli web.
- Fiche plus haute — vérifier Dynamic Type et l'absence de recouvrement des
  commandes essentielles sur l'iPhone 17 Simulator déjà démarré.

## Validation

- [x] `xcodebuild` Debug générique pour simulateur réussit.
- [x] `git diff --check` réussit.
- [x] L'inspection statique confirme que chaque fiche, personnelle ou amie,
      propose « Itinéraire » sans condition de rôle.
- [x] L'inspection statique confirme que participation et édition conservent
      leurs actions et leur priorité visuelle.
- [x] L'inspection statique confirme que Google reçoit la coordonnée exacte et
      conserve son repli navigateur HTTPS.
- [x] L'inspection statique confirme que Naver est masqué sans installation ou
      hors Corée et construit `/route/walk` vers le lieu.
- [x] L'inspection statique confirme qu'une suppression d'événement ferme le
      choix devenu obsolète.
- [x] Le parcours « Rejoindre un ami » compile avec la destination mutualisée
      et conserve ses gardes de relation, coordonnée et fraîcheur.
- [ ] Vérifier l'ouverture réelle de Google Maps depuis un événement personnel
      et un événement d'ami.
- [ ] Vérifier sur un appareil équipé de Naver Map l'ouverture réelle du trajet
      à pied, et confirmer l'absence de l'action quand l'app n'est pas installée.
- [ ] Dynamic Type, VoiceOver, mode sombre et réduction des animations sont
      vérifiés sur l'iPhone 17 Simulator déjà démarré.
- [x] Les notes Obsidian conservent frontmatter, wikilinks, tableaux et rendu en
      Reading View.

### Résultats exacts

- Build : `xcodebuild -project wander.xcodeproj -scheme wander -configuration
  Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath
  /tmp/wander-event-navigation-derived-data CODE_SIGNING_ALLOWED=NO build` →
  `BUILD SUCCEEDED` le 21 août 2026.
- Avertissement existant hors périmètre : le `CFBundleVersion` de
  `WanderShareExtension` (`15`) ne correspond pas à celui de l'app (`24`).
- Diff : `git diff --check` → succès, sans sortie.
- Simulateur : `xcrun simctl list devices booted` n'a retourné aucun appareil
  démarré sous iOS 26.3. Conformément aux règles du dépôt, aucun simulateur n'a
  été démarré sans autorisation explicite ; les contrôles interactifs restent
  donc ouverts.
- Obsidian : `Backlog features.md`, `Documentation UX.md` et
  `Documentation technique.md` ont été ouverts en Reading View. Les propriétés
  `updated`, wikilinks, tableaux et nouveaux passages sont rendus correctement.

## Acceptance criteria

- L'action d'itinéraire est visible, native et distincte de la participation.
- La destination externe correspond toujours à la coordonnée actuelle de
  l'événement identifié par son `eventID`.
- Google et Naver suivent les mêmes règles que la navigation vers un ami.
- Aucun contrat de données, secret, log de position ou dépendance n'est ajouté.

## Review notes

- Hardest decision: séparer clairement « Itinéraire » de « Je participe » tout
  en ne conservant qu'un `eventID`, puis reconstruire la destination vivante au
  moment du choix pour éviter une coordonnée obsolète.
- Rejected alternatives: « Rejoindre » a été écarté car il se confond avec la
  participation ; Apple Plans, un moteur interne, un SDK et un schéma Google
  privé dépassent le périmètre et ajouteraient de la configuration inutile.
- Least certain: les ouvertures inter-app Google et Naver restent à observer en
  conditions réelles. Naver exige notamment un appareil avec Naver Map installé,
  et aucun iPhone 17 Simulator n'était démarré pendant cette session.

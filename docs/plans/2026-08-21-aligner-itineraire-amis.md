---
title: "Aligner l'action Itinéraire des amis"
status: in_progress
date: 2026-08-21
owner: "Codex"
approved_at: "2026-08-21T17:37:54+09:00"
in_progress_at: "2026-08-21T17:37:54+09:00"
last_reviewed_at: "2026-08-21T18:10:20+09:00"
revised_at: "2026-08-21T18:07:37+09:00"
revision_approved_at: "2026-08-21T18:07:37+09:00"
related:
  - "2026-08-06-rejoindre-un-ami.md"
  - "2026-08-21-rejoindre-evenement-navigation-externe.md"
tags: [plan, map, friends, navigation, accessibility]
---

# Aligner l'action Itinéraire des amis

## Outcome

La fiche Profil d'un ami affiche un vrai bouton pleine largeur identique à celui
d'un événement : « Itinéraire », SF Symbol `map`, style secondaire et grande
taille. La commande compacte reste aussi disponible dans la callout.

## Scope

- Included:
  - remplacer le symbole `figure.walk` par `map` dans la callout ami ;
  - annoncer « Itinéraire vers [ami] » avec VoiceOver ;
  - titrer l'alerte « Itinéraire vers [ami] » ;
  - aligner le texte explicatif de la fiche profil ;
  - ajouter dans la fiche Profil un bouton « Itinéraire » pleine largeur ;
  - désactiver ce bouton quand la position de l'ami est indisponible ;
  - fermer la fiche avant de présenter le choix Google Maps ou Naver Map ;
  - mettre à jour les aperçus produit Obsidian concernés.
- Not included:
  - modifier les URLs, les règles de disponibilité Google ou Naver ;
  - transformer la callout compacte en bouton pleine largeur ;
  - modifier Firebase, les modèles ou `Info.plist`.

## Affected files

- `wander/MapWithFogView.swift` — symbole et libellé accessible de la commande.
- `wander/ContentView.swift` — titre de l'alerte de choix.
- `wander/FriendProfileSheet.swift` — texte explicatif.
- `docs/plans/2026-08-21-aligner-itineraire-amis.md` — suivi du travail.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md` — état produit.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md` — vocabulaire du parcours ami.

## Implementation

- [x] Passer le plan à `in_progress` avant la première modification produit.
- [x] Aligner le symbole et le libellé accessible dans la callout ami.
- [x] Aligner le titre de l'alerte et le texte de la fiche profil.
- [x] Mettre à jour les deux notes Obsidian et leur propriété `updated`.
- [x] Simplifier et relire le changement.
- [x] Compiler et valider le diff.
- [x] Ajouter le bouton pleine largeur dans la fiche Profil.
- [x] Différer le choix d'application jusqu'à la fermeture de la fiche.
- [x] Revalider le build, le diff et la documentation après la révision.

## Risks

- Confondre l'action avec l'ouverture du profil — conserver deux commandes
  séparées, chacune avec sa cible tactile de 44 points.
- Modifier involontairement le trajet — ne toucher à aucun constructeur d'URL
  ni à aucune garde de coordonnée ou de relation.
- Incohérence documentaire — remplacer uniquement le vocabulaire associé à
  l'action actuelle et préserver l'historique des plans terminés.

## Validation

- [x] Le build Debug générique pour simulateur réussit.
- [x] `git diff --check` réussit.
- [x] L'inspection statique confirme que la callout ami utilise le SF Symbol
      `map`, conserve le bouton profil et ses deux cibles de 44 points.
- [x] Le libellé accessible est « Itinéraire vers [ami] » et l'aide explique le
      choix d'une application pour afficher l'itinéraire.
- [x] L'alerte propose encore Google Maps et Naver Map selon les mêmes règles.
- [x] La fiche profil parle de l'action « Itinéraire ».
- [x] L'inspection statique confirme que la fiche Profil affiche un bouton
      `Itinéraire` pleine largeur, secondaire, de grande taille et désactivé
      sans position.
- [x] La fermeture de la fiche précède d'un cycle d'acteur principal la
      revalidation de l'ami et la présentation du choix d'application.
- [x] Les notes Obsidian conservent leurs propriétés, wikilinks et leur rendu en
      Reading View.
- [ ] Observer la callout avec un ami sur l'iPhone 17 Simulator et vérifier
      visuellement ses deux commandes ainsi que l'annonce VoiceOver réelle.
- [ ] Observer le bouton pleine largeur, son état désactivé sans position et la
      transition fiche → choix d'application sur l'iPhone 17 Simulator.

### Résultats exacts

- Build : `xcodebuild -project wander.xcodeproj -scheme wander -configuration
  Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath
  /tmp/wander-event-navigation-derived-data CODE_SIGNING_ALLOWED=NO build` →
  `BUILD SUCCEEDED` le 21 août 2026.
- Le même build a de nouveau réussi après l'ajout du bouton pleine largeur et
  de la transition différée fiche → alerte.
- Avertissement existant hors périmètre : l'extraction App Intents est ignorée
  car le projet ne dépend pas d'`AppIntents.framework`.
- Diff : `git diff --check` → succès, sans sortie.
- Simulateur : `xcrun simctl list devices booted` n'a retourné aucun appareil
  démarré sous iOS 26.3. Aucun simulateur n'a été démarré sans l'autorisation
  explicite requise par le dépôt.
- Obsidian : `Backlog features.md` et `Documentation UX.md` ont été ouverts en
  Reading View ; leurs propriétés `updated`, wikilinks et nouveaux passages
  sont rendus correctement.

## Acceptance criteria

- Le vocabulaire et le symbole sont cohérents entre amis et événements.
- La fiche Profil propose le même bouton pleine largeur que les événements.
- La callout reste compacte, native et accessible.
- Aucun comportement de navigation, contrat de données ou secret ne change.

## Review notes

- Hardest decision: présenter l'alerte seulement après la disparition de la
  fiche Profil. Un drapeau local déclenche la fermeture, puis un cycle d'acteur
  principal laisse SwiftUI terminer la transition avant de revalider l'ami.
- Rejected alternatives: élargir la callout aurait réduit la place du bouton
  Profil ; présenter l'alerte racine pendant que la fiche est encore affichée
  aurait créé deux présentations concurrentes et une transition fragile.
- Least certain: le rendu final, l'état désactivé, la transition et l'annonce
  VoiceOver doivent encore être observés avec un ami visible ; aucun iPhone 17
  Simulator n'était démarré.

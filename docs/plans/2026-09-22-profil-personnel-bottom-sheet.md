---
title: "Profil personnel de la carte en bottom sheet"
status: completed
completed_at: 2026-09-22T13:04:17+09:00
date: 2026-09-22
owner: Samuel
tags: [plan, map, profile]
---

# Profil personnel de la carte en bottom sheet

## Outcome

Toucher son avatar sur la carte ouvre une feuille native comme les profils
d’amis. La bulle MapKit personnelle disparaît. La feuille propose une hauteur
compacte, un agrandissement et une fermeture par glissement. Le pin reste visible.

## Approval

Plan présenté dans la conversation puis explicitement approuvé par Samuel le
22 septembre 2026, après confirmation que le tooltip serait supprimé.

## Scope

- Profil personnel depuis la carte, ses informations et le cadrage associé.
- Réutilisation de la présentation des amis, sans modifier l’onglet Profil.
- Aucun changement Firebase, permissions ou persistance.

## Affected files

- `wander/ContentView.swift` : sélection et présentation du profil personnel.
- `wander/MapWithFogView.swift` : sélection du pin et suppression du callout.
- `wander/MapSocialProximityController.swift` : cadrage de la sélection personnelle.
- `wander/MapFriendCameraController.swift` : cible personnelle pour la caméra.
- `wander/FriendProfileSheet.swift` : composants communs de présentation.
- `wander/OwnProfileSheet.swift` : contenu personnel.
- `wander/DebugSocialMapScenario.swift` : parcours reproductible sans compte réel.
- `wanderUITests/MapSocialGestureUITests.swift` : régression du parcours personnel.
- `wanderTests/FriendProfilePresentationTests.swift` et tests caméra/proximité si nécessaires.
- Ce plan : suivi et preuves de validation.
- Obsidian `Documentation UX.md` : profil personnel sur la carte, propriété `updated`.
- Obsidian `Documentation technique.md` : sélection, feuille et cadrage, propriété `updated`.
  Racine : `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander`.

## Implementation

- [x] Relier le pin personnel à une sélection de profil unique.
- [x] Réutiliser la présentation native et afficher les informations personnelles.
- [x] Supprimer le tooltip personnel et adapter le cadrage ouverture/fermeture.
- [x] Ajouter les régressions des parcours personnels, groupes et amis ; compilation seulement.
- [x] Revoir le diff et mettre à jour les notes Obsidian.

## Risks

- Sélections successives ami/personnel : une seule feuille active, sans recentrage tardif.
- Cadrage : conserver zoom et orientation, ne pas relancer le suivi GPS.
- Données de position absentes : conserver une fiche utilisable sans cadrage invalide.
- La liste Événements doit conserver son état derrière la feuille.

## Validation and acceptance

Samuel a demandé explicitement une compilation uniquement, sans tests simulateur.
Le seul simulateur démarré est un iPhone 16e. Aucun appareil n’a été lancé, créé
ou téléchargé et aucun test n’a été exécuté.

- [x] App et cibles de tests compilées avec `build-for-testing`.
- [x] Aucun nouveau diagnostic Swift ; avertissements hérités AppIntents et
  versions des extensions 15/27 face à l’app 43. Les versions sont déjà suivies
  dans `todos/054-ready-p2-aligner-build-extensions.md`.
- [x] `git diff --check` passe.
- [x] Notes Obsidian UX et technique actualisées avec leur propriété `updated`.
- Non exécuté à la demande de Samuel : parcours visuels et gestuels, tests
  unitaires sur simulateur, captures. Cela limite la validation à la compilation
  et à la revue statique ; ce n’est pas une validation de comportement à l’écran.

Commande exécutée :

```sh
xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -disableAutomaticPackageResolution build-for-testing
```

Journaux : `/tmp/wander-own-profile-build.log` et
`/tmp/wander-own-profile-build-final.log`. Résultat : `TEST BUILD SUCCEEDED`.

## Implementation details

- `MapProfileSelection` identifie `.currentUser` et `.friend` ; une seule sheet
  dérive de `MapDetailSelection` et protège les sélections d’événements.
- Le pin personnel ne présente plus de callout MapKit. La sélection d’un pin
  ou d’un membre de groupe attend la mesure de la feuille pour le cadrage.
- `MapProfileNativeContent` partage la mesure préalable, le palier compact,
  le palier large et le défilement avec les profils d’amis.
- `OwnProfileSheet` conserve progression, position, présence et adresse copiable.
  `MapProfileAddress` partage le cache borné et le formatage existants ; les
  coordonnées sont regroupées par clé arrondie avant recherche d’adresse.
- Les tests caméra existants utilisent la cible typée ; un test de proximité
  couvre l’absence de centrage préalable du profil personnel depuis pin/groupe.
  Les tests UI couvrent la réouverture, les deux hauteurs et le passage aux amis.

## Review notes

- Diagnostic initial par lecture : `.currentUser` ne déclenche aucune présentation
  dans `activateSocialAnnotation`; le pin conserve `canShowCallout = true`.
- Reproduction et tests sur simulateur exclus ensuite par Samuel ; aucun résultat runtime revendiqué.
- Aucun changement Git autorisé. Arbre initial propre.

- Simplification : trois lectures indépendantes, réutilisation, qualité et
  efficacité. Cache/formatage d’adresse partagés, propriété de police morte
  supprimée, ancien initialiseur de caméra remplacé, sélection de profil unifiée.
- Proposition rejetée : supprimer `canShowCallout = false` sur le pin personnel.
  Le composant personnalisé initialise explicitement cette propriété à `true` ;
  la valeur par défaut MapKit ne s’applique donc pas.
- Pas de nouvelle solution autonome : réutilisation du mécanisme de feuille et
  de cadrage déjà documenté pour les amis, sans apprentissage inédit vérifié.

- Revue finale : les lectures de correction, transitions SwiftUI/MapKit,
  tests, standards et maintenabilité ne signalent aucun défaut confirmé.
  La durée de présence personnelle est effacée par `LocationTracker.stopTracking()` ;
  le contrôle de ce parcours n’a pas révélé de régression de présence périmée.
- Contrôle des notes Obsidian : frontmatter, référence au plan et délimiteurs
  des wikilinks vérifiés sans ouvrir l’application.

- Les solutions MapKit existantes ont été confrontées au diff : feuille hors du
  rendu de carte, cadrage unique, annulation par geste, sélection native de secours
  et conservation de la liste Événements. Aucun défaut supplémentaire identifié.

- Compte rendu `ce-code-review` terminé : sept lectures statiques, aucun constat
  actionnable. Reçu : `/tmp/compound-engineering-501/ce-code-review/20260922-own-profile-review/review.json`.
  Limites conservées : parcours UI non exécutés et absence de couverture
  déterministe des erreurs/annulations de géocodage ; aucun défaut établi.

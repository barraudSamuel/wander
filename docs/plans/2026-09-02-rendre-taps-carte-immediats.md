---
title: "Rendre les taps de la carte immédiats"
status: blocked
date: 2026-09-02
approved_at: 2026-09-02
reapproved_at: 2026-09-02
owner: Samuel Barraud
related:
  - 2026-09-01-regrouper-marqueurs-carte.md
  - 2026-09-02-animer-ouverture-cluster-vertical.md
tags: [plan, map, performance, ux]
---

# Rendre les taps de la carte immédiats

## Outcome

Déclencher l'ouverture d'un ami, d'un événement ou d'un groupe directement au
relâchement du doigt sur son annotation, sans attendre la sélection différée de
MapKit, puis rendre le contenu perceptible en moins de 100 ms tout en conservant
les gestes natifs de la carte.

## Scope

- Ajouter une reconnaissance applicative du tap limitée aux annotations
  sociales.
- Annuler l'activation lorsque le toucher devient un déplacement de carte.
- Conserver la sélection MapKit pour l'état, l'accessibilité et les sélections
  programmatiques.
- Dédupliquer l'activation immédiate et le callback `didSelect` ultérieur.
- Désélectionner immédiatement au relâchement sur une zone vide de la carte.
- Annuler cette fermeture lorsque le toucher devient un geste cartographique.
- Raccourcir l'ouverture d'un cluster et de la fiche événement.
- Afficher le contenu dès la première frame, puis terminer une animation courte.
- Conserver le chargement et le rafraîchissement des données en arrière-plan.

## Non-goals

- Remplacer MapKit ou son moteur de rendu.
- Modifier le modèle des amis, des événements ou des participations.
- Désactiver ou reconfigurer les reconnaisseurs internes privés de MapKit.
- Modifier la création d'événement autrement que pour prévenir une régression.

## Dependencies

- Les annotations et callbacks existants de `MapWithFogView`.
- Les données sociales déjà chargées dans `ContentView`.
- Le simulateur iPhone 17 déjà démarré pour la validation interactive.

## Affected files

- `wander/MapWithFogView.swift`
- `wander/MapSocialClusterAnnotationView.swift`
- `wander/ContentView.swift`
- `docs/plans/2026-09-02-rendre-taps-carte-immediats.md`
- `docs/solutions/2026-09-02-rendre-interactions-mapkit-immediates.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`

## Implementation checklist

- [x] Installer et retirer un reconnaisseur de pression immédiate sur la carte.
- [x] Limiter ce reconnaisseur aux annotations sociales compactes.
- [x] Activer l'annotation au relâchement sans attendre `didSelect`.
- [x] Dédupliquer les activations immédiates et MapKit.
- [x] Conserver les sélections programmatiques existantes.
- [x] Réduire l'animation d'ouverture du cluster.
- [x] Réduire l'animation d'ouverture de la fiche événement.
- [x] Fermer immédiatement sur un tap du fond de carte.
- [x] Exclure les contrôles, callouts et indicateurs de la fermeture immédiate.
- [ ] Mettre à jour les documentations technique et UX.
- [x] Compiler et contrôler le diff.
- [ ] Valider les interactions sur l'iPhone 17 Simulator.
- [x] Effectuer la revue finale et consigner les findings résiduels.

## Risks

- Le reconnaisseur immédiat peut concurrencer le panoramique — il reste limité
  aux annotations et autorise les gestes MapKit simultanés.
- MapKit peut ensuite émettre `didSelect` — l'activation commune doit être
  idempotente pour éviter deux ouvertures ou deux rafraîchissements.
- Une annotation peut être remplacée pendant le clustering — le traitement
  résout la vue et son annotation au moment du relâchement.
- Une animation trop courte peut sembler sèche — garder un mouvement système
  bref, sans opacité initiale nulle.

## Validation

- [x] `git diff --check` réussit.
- [x] Le build Debug réussit sans nouvel avertissement.
- [ ] Ami, événement et groupe réagissent dès le relâchement.
- [ ] La première réaction visuelle arrive en moins de 100 ms.
- [ ] Pan, pinch, double tap et appui long restent fonctionnels.
- [ ] Les taps répétés ne produisent pas de double activation.
- [ ] Un tap du fond ferme immédiatement sans fermer pendant un panoramique.
- [ ] VoiceOver et Réduire les animations restent cohérents.
- [ ] Les notes Obsidian sont vérifiées en reading view.

Validation exécutée le 2026-09-02 :

- `git diff --check` : réussi.
- Build Debug : réussi avec `xcodebuild -quiet -project wander.xcodeproj
  -scheme wander -configuration Debug -destination 'generic/platform=iOS
  Simulator' -derivedDataPath /tmp/wander-participant-badge-derived-data
  -disableAutomaticPackageResolution build`.
- Deux avertissements préexistants subsistent : les `CFBundleVersion` des deux
  extensions (`27` et `15`) diffèrent de celui de l'app (`31`).
- Build installé et lancé sur l'iPhone 17 Simulator déjà démarré.
- Rebuild incrémental après ajout de la fermeture immédiate : réussi sans
  sortie ni nouvel avertissement ; le binaire a été réinstallé et relancé sans
  crash sur le même simulateur.
- Rebuild après correction de l'ordre du hit-test accessible : réussi sans
  sortie ni nouvel avertissement ; le binaire a été réinstallé et relancé. Les
  `MKAnnotationView` sont désormais reconnues avant l'exclusion générique du
  trait `.button`, tandis que les `UIControl` enfants restent exclus.
- Rebuild après remplacement du reconnaisseur actif par un observateur passif :
  réussi avec seulement les deux avertissements `CFBundleVersion` préexistants ;
  le binaire a été réinstallé et relancé. L'observateur termine en `.failed` et
  ne peut ni prévenir ni être prévenu par un geste MapKit.
- Validation des annotations bloquée par l'écran de connexion Apple du
  simulateur, sans compte de test autorisé.
- Le vault Obsidian est lisible mais non modifiable depuis l'environnement.
  Restent à mettre à jour puis vérifier en reading view :
  - `Backlog features.md`, section `En cours`, avec le statut du correctif de
    réactivité cartographique ;
  - `Documentation technique.md`, section `Carte`, avec le reconnaisseur limité
    aux annotations, l'activation partagée et la déduplication de `didSelect` ;
  - `Documentation UX.md`, sections `Carte et progression`, `Amis sur la carte`,
    `Sorties prévues` et `Points UX encore à valider`, avec le retour immédiat,
    les animations de 180 ms et les scénarios gestuels à confirmer.

## Acceptance criteria

- Un tap direct sur une annotation sociale ne dépend plus du délai de sélection
  de MapKit pour afficher son contenu.
- Les gestes natifs de carte et l'appui long de création ne régressent pas.
- Les sélections venant du rail, de la recherche ou de l'état SwiftUI restent
  fonctionnelles.
- Les animations restent perceptibles mais ne retardent plus l'information.
- Un tap du fond déclenche la fermeture au relâchement, tandis qu'un déplacement
  de carte annule cette fermeture.

## Review notes

- Hardest decision: court-circuiter la latence de sélection sans modifier les
  reconnaisseurs privés de MapKit ni casser le fallback accessible.
- Rejected alternatives: désactiver le double tap ou reconfigurer les gestes
  internes de MapKit serait fragile ; réduire seulement les animations aurait
  laissé le temps mort avant `didSelect` ; une couche de pins entièrement
  séparée aurait dupliqué la projection et le clustering existants.
- Least certain: l'arbitrage réel entre ouverture ou fermeture immédiate, pan,
  pinch et double tap ne peut pas être observé tant que le simulateur reste non
  authentifié.
- Review findings: aucun finding fonctionnel ou de sécurité supplémentaire
  identifié dans le diff. La validation interactive et les notes Obsidian
  restent suivies ici ; aucun nouveau fichier `todos/` n'est nécessaire.

---
title: Cartes événements avec ouverture agrandie
status: completed
date: 2026-09-26
approved_at: 2026-09-26
started_at: 2026-09-26
completed_at: 2026-09-26
owner: Samuel
related:
  - 2026-09-26-detail-evenement-narratif.md
tags: [plan, events, ios, design]
---

> Approche remplacée le 26 septembre à la demande de Samuel par le
> [plan de cartes autonomes](2026-09-26-cartes-evenements-autonomes.md),
> approuvé séparément. Le détail, le zoom et les actions par balayage sont
> retirés. Les validations ci-dessous décrivent la version historique.


# Cartes événements avec ouverture agrandie

## Résultat et approbation

Présenter les événements sous forme de cartes lisibles, puis agrandir la carte
touchée vers sa fiche dans le panneau existant. Samuel a validé le plan complet
présenté dans la conversation avec « je vlaide ». Les références retenues sont
les images 6 et 8 pour la liste, 7 pour les états compact/développé et 1 pour les
avatars. Un seul incrément est autorisé.

## Périmètre

- Date et heure, activité et lieu, organisateur distinct, participants et
  distance fiable disponible dans la carte compacte. Toute la carte est touchable.
- Même en-tête dans le détail, puis participants complets, réponse et adresse.
  Tous les éléments défilent ; conserver le retour et les actions système.
- Zoom natif depuis une carte source visible ; transition native normale depuis
  la carte géographique si aucune source de liste n'est disponible.
- Panneau agrandi à 85 % de l'espace disponible ; conserver le redimensionnement
  manuel et une hauteur de liste indépendante, restaurée au retour.
- Conserver sélection, tri stable, scroll, observations des participants,
  réponses, menus et actions de gestion, états vide/chargement/erreur.
- Fonds, polices, couleurs et contrôles natifs iOS. Aucune couverture, nouvelle
  donnée, modification Firebase, dépendance ou modification de la carte MapKit.

## Approche technique et dépendances

Conserver la List et le NavigationStack de MapEventsPanelView. Le zoom SwiftUI
utilise une source identifiée par l'événement et une namespace partagée. Un
en-tête commun reste défini dans les fichiers de présentation concernés.
MapDetailSplitView conserve séparément les positions liste/détail et reçoit la
sélection effective depuis ContentView et le scénario local.
La hauteur réservée à la List racine reste celle de la liste mémorisée, même
quand le NavigationStack s'agrandit pour le détail. Cela évite de borner son
offset près des dernières cartes au changement de taille.

Flux : carte touchée → sélection effective → détail et hauteur agrandie ;
retour confirmé ou événement disparu → liste et hauteur conservée. Un
changement d'événement ne doit pas écraser la position de liste. Fermer le
panneau conserve la règle existante de remise à un tiers pour la liste et
prépare le détail à 85 % pour sa réouverture. Un passage temporaire par Amis
conserve au contraire la hauteur manuelle du détail.
Les modifications non commitées de la fiche narrative et des tests servent de
base et sont préservées. Travail dans le checkout courant, sans commande Git
mutante, commit, PR ou publication. Les règles du dépôt prévalent sur les
automatismes de branche, de livraison et de suivi des skills.

## Fichiers concernés

- wander/MapEventsPanelView.swift
- wander/MapEventDetailView.swift
- wander/MapDetailSplitView.swift
- wander/ContentView.swift
- wander/DebugSocialMapScenario.swift
- wanderUITests/MapSocialGestureUITests.swift
- Ce plan et todos/ uniquement pour les constats retenus par la revue.
- Coffre Obsidian existant :
  /Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander
  - Backlog features.md : entrée détail/liste des événements.
  - Documentation UX.md : architecture de navigation, fiches et carte partagée,
    sorties prévues.
  - Documentation technique.md : carte/panneaux et événements/participations.
  - 00 - Wander.md : état du projet.
  - Actualiser updated et préserver les wikilinks ; ne pas ouvrir Obsidian.
    Utiliser l'accès technique autorisé au coffre hors des racines d'écriture,
    sinon consigner précisément les notes/sections non actualisées.

## Checklist

- [x] Enregistrer l'approbation avant l'implémentation.
- [x] Composer les cartes et l'en-tête commun, intégrer le zoom natif.
- [x] Séparer les hauteurs liste/détail et raccorder les deux appels du split.
- [x] Adapter les scénarios fonctionnels existants.
- [x] Simplifier, compiler l'app et les cibles de tests, puis revoir le diff.
- [x] Actualiser les quatre notes Obsidian et consigner la validation exacte.

## Risques et validation

Risques : décalage du scroll près du bas de liste lors du redimensionnement,
retour interactif annulé, disparition de l'événement ouvert, source de zoom
absente, changements d'onglet ou profil masquant le panneau. Garder les
observations limitées aux cartes visibles, suspendues pendant le détail.
Conserver la géométrie native de MapKit et ses règles de recentrage.

Scénarios : liste → détail agrandi → retour à même hauteur et position ; entrée
depuis un groupe de repères → retour liste ; ouverture/fermeture et changement
Amis/Événements ; redimensionnement manuel du détail indépendant de la liste ;
contenus longs et états des réponses/participants ; source indisponible ou
événement disparu. Aucun test dédié d'accessibilité.

La suspension des exécutions simulateur consignée dans le plan précédent reste
en vigueur. Aucun test lancé, aucune installation, capture ou ouverture de
simulateur. Les tests seront adaptés et compilés, pas exécutés. La fluidité et
le rendu resteront explicitement non vérifiés.

Commande de validation autorisée :
`xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build-for-testing`

Compléter par simplification, revue indépendante, contrôle des espaces et des
changements. Consigner les diagnostics préexistants séparément des nouveaux.

## Critères d'acceptation

- [x] Cartes compactes et détail conservent la même hiérarchie d'informations.
- [x] Zoom depuis une source visible, chemin normal sinon, retours natifs.
- [x] Hauteurs liste/détail indépendantes et restauration définie au retour.
- [x] États/actions/observations et modifications préexistantes préservés.
- [x] App et tests compilés sans nouveau diagnostic Swift ; revue achevée.
- [x] Documentation actualisée ou limitation exacte enregistrée.

Les critères de comportement ci-dessus sont implémentés et relus dans le code.
Leur vérification en exécution reste exclue du périmètre approuvé.

## Revue et résultats

- `ce-work` exécuté dans le checkout courant, sans commande Git mutante.
- `ce-simplify-code` : trois revues indépendantes réutilisation, qualité et
  efficacité. Aperçu des participants construit une fois par carte et réutilisé
  dans les deux dispositions ; commentaire lié à l'ancienne UI supprimé.
- Les tests UI existants sont adaptés à la carte 18, dernière de la liste,
  et aux géométries agrandie/restaurée. Un scénario couvre hauteur manuelle,
  retour partiellement glissé, onglets et réouverture. Aucun test exécuté.
- Les quatre notes Obsidian sont finalisées (`updated` :
  `2026-09-26T14:44:20+09:00`) : implémentation réalisée, compilation validée,
  limites de validation explicites. Leurs 41 occurrences de wikilinks sont
  identiques avant/après et leurs cibles existent. Aucun affichage Obsidian.
- Compilation approuvée réussie le 26 septembre : `TEST BUILD SUCCEEDED`,
  code de sortie 0. Journal `/tmp/wander-event-cards-build.log`. Aucun diagnostic
  Swift ; trois avertissements préexistants d'extraction AppIntents sans
  dépendance AppIntents.framework. Aucun test lancé ni simulateur utilisé.
- `ce-test-xcode` consulté : surfaces UI `SKIP`, bilan d'exécution `PARTIAL`
  conformément au périmètre approuvé. Aucun résultat visuel revendiqué.
- Correctif de revue : réinitialiser `eventDetailPosition` à `.expanded` lors
  de la fermeture du panneau événements ; préserver sa hauteur au passage par
  Amis. Le scénario existant couvre maintenant fermeture par bouton et par
  glissement, puis réouverture du même événement. Constat P2 et résolution :
  [064](../../todos/064-done-p2-restaurer-hauteur-detail-evenement.md).
- Nouvelle compilation après ce correctif avec la commande autorisée ci-dessus :
  `TEST BUILD SUCCEEDED`, code 0, journal
  `/tmp/wander-event-cards-final-build.log`. Aucun diagnostic Swift ; mêmes
  trois avertissements AppIntents préexistants. Aucun test exécuté.
- `git diff --check` passe après les modifications du code et des tests.
- Revue `ce-code-review mode:agent base:HEAD` achevée (`status: complete`),
  huit lectures spécialisées, fusion et validation indépendante. Run
  `20260926-143314-1c3439c4`, artefacts dans
  `/tmp/compound-engineering-501/ce-code-review/20260926-143314-1c3439c4`.
  Le reçu `review.json` porte sur le diff avant correction et conclut
  « Ready with fixes ». La relecture ciblée du correctif, consignée dans
  `follow-up-resolution.json`, confirme la résolution du seul constat
  actionnable P2, sans nouveau défaut retenu. L'export vers le
  reviewer externe a été refusé par le contrôle automatique, faute d'accord
  spécifique pour cet export ; aucun job externe démarré ni code transmis.
  La revue adversariale a été réalisée localement.
- Une réserve de synchronisation des mesures XCTest reste seulement dans le
  rapport : aucun échantillonnage de géométrie intermédiaire ni échec n'a été
  observé. Le validateur n'a pas confirmé cette hypothèse. Aucun correctif
  spéculatif ni exécution supplémentaire n'est requis pour cet incrément.
- Aucune validation en exécution ne sera déduite de la compilation ou de la
  lecture du code. L'implémentation et la validation autorisée sont terminées.

## Décisions et limites

- Décision principale : conserver une hauteur stable pour la List racine
  pendant l'agrandissement du NavigationStack, afin de ne pas contraindre son
  défilement près de la dernière carte.
- Alternatives écartées : une liste personnalisée ou une présentation de détail
  superposée auraient remplacé les contrôles natifs et multiplié les états de
  navigation. Les cartes restent des sections de List et le retour est natif.
- Point le moins certain : rendu et fluidité de la transition, retour interactif
  annulé et conservation effective du scroll. Les scénarios sont compilés,
  leur exécution est suspendue conformément à l'approbation.
- Pas de nouvelle fiche `docs/solutions/` : aucun enseignement nouveau validé
  en exécution ne justifie une note durable pour cet incrément. Les références
  existantes sur la conservation de la liste restent applicables.

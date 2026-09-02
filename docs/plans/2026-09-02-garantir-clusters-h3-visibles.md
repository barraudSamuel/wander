---
status: completed
approved_at: 2026-09-02
revised_at: 2026-09-02
completed_at: 2026-09-02T12:32:47+09:00
---

# Regrouper les marqueurs sociaux par proximité géographique

## Outcome

Regrouper le compte courant, les amis et les événements qui représentent le
même lieu réel, indépendamment du zoom de la carte. Un élément entre dans un
groupe à 20 mètres et un groupe existant reste stable jusqu'à 25 mètres afin
d'absorber les petites oscillations GPS.

## Diagnostic

- Le clustering natif MapKit dépend de la collision visuelle et change donc
  avec le zoom, ce qui ne représente pas la notion de « même café ».
- Une cellule H3 de résolution 10 couvre une zone trop large pour identifier un
  même établissement.
- La tentative locale de construire directement des `MKClusterAnnotation`
  repose sur un type que MapKit crée et gère lui-même ; elle doit être retirée.
- La synchronisation H3 expérimentale parcourt et trie toutes les annotations à
  chaque mise à jour SwiftUI et replie des groupes sans rapport avec le membre
  déplacé.

## Scope

- Calculer les groupes à partir de distances géographiques en mètres, jamais à
  partir de la distance projetée à l'écran.
- Utiliser 20 mètres pour créer ou rejoindre un groupe.
- Conserver les membres d'un groupe existant tant que sa distance paire à paire
  maximale ne dépasse pas 25 mètres.
- Empêcher les regroupements en chaîne : tous les membres d'un groupe doivent
  respecter la distance maximale entre eux.
- Afficher l'annotation source pour un membre isolé et une annotation
  applicative stable pour un groupe d'au moins deux membres.
- Recalculer uniquement lorsque la composition ou les coordonnées sociales
  changent ; un zoom ou un déplacement de caméra ne modifie pas les groupes.
- Conserver la pile compacte, la liste verticale, son animation, les callouts,
  la sélection d'un membre et l'accessibilité.
- Lorsqu'un membre est sélectionné dans un groupe, l'afficher temporairement
  séparément et conserver un représentant pour les autres membres ; restaurer
  le groupe complet à la fermeture.
- Désactiver le clustering natif MapKit pour tous les représentants sociaux.

## Non-goals

- Regrouper des marqueurs parce que leurs vues se chevauchent à un fort dézoom.
- Déduire un établissement ou une adresse depuis les coordonnées.
- Modifier H3, Firebase, le modèle persistant ou la fréquence de localisation.
- Modifier le design des marqueurs ou de la liste verticale.

## Affected files

- `wander/MapWithFogView.swift`
- `wander/MapSocialClusterAnnotationView.swift`
- `wander/MapSocialProximityGroupAnnotation.swift`
- `wander/wanderApp.swift`
- `docs/plans/2026-09-02-garantir-clusters-h3-visibles.md`
- `docs/solutions/2026-09-02-regrouper-marqueurs-par-proximite.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md`

## Implementation checklist

- [x] Introduire une annotation applicative de groupe, indépendante de
  `MKClusterAnnotation`.
- [x] Produire des groupes déterministes dont chaque paire respecte le seuil.
- [x] Appliquer l'hystérésis 20 m / 25 m aux groupes existants.
- [x] Réutiliser les annotations de groupe inchangées pour préserver l'état
  ouvert et éviter les clignotements.
- [x] Synchroniser les représentants seulement après une modification des
  sources sociales.
- [x] Désactiver le clustering natif et rendre chaque représentant visible.
- [x] Adapter l'ouverture, la fermeture et la sélection à l'annotation
  applicative.
- [x] Retirer le registre H3, les `MKClusterAnnotation` manuelles et leurs
  mécanismes de restauration.
- [x] Adapter la fixture Debug aux distances 5 m, 19 m, 21 m et 26 m, au cas de
  chaîne et à l'indépendance vis-à-vis du zoom.
- [x] Retirer la fixture et son argument de lancement avant la build finale.
- [x] Mettre à jour les notes Obsidian ou consigner précisément le blocage.
- [x] Simplifier, compiler, valider et effectuer la revue finale.

## Risks

- Sans hystérésis, l'imprécision GPS ferait entrer et sortir un membre autour du
  seuil ; les limites distinctes de 20 m et 25 m doivent préserver l'identité
  du groupe.
- Un algorithme par connexité pourrait relier plusieurs lieux par une chaîne de
  membres proches ; la contrainte paire à paire doit l'empêcher.
- Plusieurs groupes géographiques peuvent se chevaucher visuellement à fort
  dézoom ; ils doivent rester distincts conformément au besoin produit.
- La sélection temporaire d'un membre ne doit pas faire disparaître les autres
  membres de son groupe.

## Validation

- Vérifier deux membres distants de 5 m et 19 m : un groupe stable.
- Vérifier deux membres initialement distants de 21 m : deux marqueurs.
- Éloigner un groupe existant à 24 m puis 26 m : conservation puis séparation.
- Vérifier trois membres à 0 m, 15 m et 30 m : aucun groupe unique par effet de
  chaîne.
- Vérifier que la composition est identique aux zooms monde, ville et rue.
- Vérifier un groupe mixte compte courant, ami et événement.
- Sélectionner un membre : callout correct, autres membres représentés, groupe
  complet restauré à la fermeture.
- Build Debug sur l'iPhone 17 Simulator déjà actif.
- `git diff --check`, retrait de la fixture et revue manuelle du diff.

### Résultats

- Groupe mixte compte courant, ami et événement validé à 5 m et 19 m.
- Paire initiale à 21 m laissée séparée.
- Groupe existant conservé à 24 m puis séparé à 26 m.
- Cas 0 m / 15 m / 30 m validé sans groupe unique par effet de chaîne.
- Composition identique aux zooms rue, ville et monde.
- Tous les représentants visibles avec `displayPriority = .required`.
- Fixture et argument Debug retirés avant le build final.
- Build Debug final réussi pour le simulateur iOS, application réinstallée et
  lancée normalement sur l'iPhone 17 Simulator déjà actif.
- `git diff --check` réussi ; revue finale sans constat restant, donc aucun
  fichier `todos/` ajouté.

### Mises à jour Obsidian restantes

Les notes existent mais ne sont pas inscriptibles depuis cet environnement.
Aucun vault de substitution n'a été créé. Les mises à jour suivantes restent à
appliquer et à vérifier en mode lecture Obsidian :

- `Documentation UX.md` : actualiser la propriété `updated`, puis compléter
  `### Amis sur la carte` avec le regroupement compte/amis/événements à 20 m,
  sa conservation jusqu'à 25 m, son indépendance au zoom, la liste verticale
  et l'extraction temporaire du membre sélectionné.
- `Documentation technique.md` : actualiser la propriété `updated`, puis
  compléter `## Carte` avec `MapSocialProximityGroupAnnotation`, le calcul des
  distances une fois par changement de source, la fusion déterministe
  paire-à-paire, l'hystérésis 20 m / 25 m, la priorité aux groupes existants et
  la désactivation du clustering natif.
- Vérifier ensuite les propriétés, wikilinks, tableaux, callouts, blocs de code
  et diagrammes Mermaid affectés dans la vue de lecture.

## Acceptance criteria

- Les marqueurs d'un même lieu réel sont regroupés selon les seuils 20 m / 25 m
  et non selon le zoom ou leur chevauchement visuel.
- Aucun groupe ne dépasse 25 m entre deux de ses membres.
- Un zoom ou un déplacement de caméra ne modifie jamais la composition.
- Les groupes restent stables face aux petites oscillations GPS.
- La liste verticale, la sélection, les callouts et l'accessibilité restent
  fonctionnels.

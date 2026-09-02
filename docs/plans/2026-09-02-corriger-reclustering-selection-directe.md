---
status: completed
approved_at: 2026-09-02
completed_at: 2026-09-02T10:01:41+09:00
---

# Corriger le reclustering d'une sélection directe

## Outcome

Empêcher un ami, le compte courant ou un événement sélectionné directement sur la carte d'être fusionné dans un cluster voisin pendant l'ouverture de sa fiche ou le recentrage MapKit.

## Scope

- Rendre immédiatement non-clusterisable toute annotation sociale sélectionnée directement.
- Conserver cette isolation pendant toute la sélection.
- Protéger le recentrage programmatique contre le repli automatique lié aux changements de région.
- Restaurer le clustering normal lors de la désélection.
- Préserver la sélection depuis la liste verticale d'un cluster.

## Non-goals

- Modifier le seuil spatial ou l'apparence des clusters.
- Désactiver le clustering des autres marqueurs.
- Modifier le contenu des fiches ami ou événement.

## Dependencies

- Le mécanisme existant de focus temporaire et de restauration des annotations sociales.

## Affected files

- `wander/MapWithFogView.swift`
- `docs/plans/2026-09-02-corriger-reclustering-selection-directe.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md`

## Implementation checklist

- [x] Isoler synchroniquement la vue sélectionnée sans la retirer de MapKit.
- [x] Appliquer ce focus aux sélections directes compte, ami et événement.
- [x] Encadrer le recentrage par le garde-fou de changement de région.
- [x] Restaurer le clustering à la désélection sans boucle de callbacks.
- [ ] Mettre à jour les deux notes Obsidian — bloqué : vault présent mais non inscriptible depuis cette session ; mises à jour exactes consignées ci-dessous.
- [x] Reproduire la régression de la vidéo et valider les parcours voisins.

## Risks

- Retirer/réinsérer une annotation déjà sélectionnée fermerait sa callout ; la sélection directe doit donc modifier la vue en place.
- Une restauration déclenchée pendant un callback `didDeselect` peut provoquer une boucle si le garde existant n'est pas respecté.
- Le recentrage programmatique peut être pris pour un geste utilisateur et annuler le focus s'il n'est pas explicitement encadré.

## Validation

- Vidéo utilisateur inspectée image par image : la callout de Sam s'ouvrait, puis son annotation encore clusterisable était absorbée par l'événement rouge voisin pendant le recentrage.
- `git diff --check` : réussi.
- Build Debug final pour le simulateur iOS : réussi après retrait complet du scénario DEBUG local.
- Régression reproduite sur l'iPhone 17 Simulator avec Aya et un événement placés juste au-dessus du seuil de regroupement.
- Sélection directe d'Aya : après 1,2 seconde et la fin du recentrage, callout toujours ouverte, actions présentes et événement voisin toujours distinct.
- Sélection directe de l'événement : callback exécuté, état sélectionné conservé et Aya toujours distincte après le recentrage.
- Fermeture des deux sélections : callout/état événement retiré et clustering réactivé sur le marqueur concerné.
- Compte courant : utilise la même vue `UserLocationAnnotationView` et le même chemin d'isolation validé pour Aya ; branche de délégation compilée et symétrique.
- Sélection depuis la liste verticale : le focus préexistant est détecté et le nouveau chemin ne retire ni ne reconfigure l'annotation une seconde fois.
- Réduire les animations : recentrage direct désormais conditionné par `UIAccessibility.isReduceMotionEnabled` ; isolation et restauration restent immédiates.
- Scénario et argument DEBUG retirés ; absence confirmée par `rg` ; build final propre réinstallé sur le Simulator actif.
- Revue manuelle : aucun finding P1, P2 ou P3 ; aucun fichier `todos/` ajouté.

### Mises à jour Obsidian restantes

Les deux fichiers existent, mais `test -w` échoue. Ne pas créer de vault de remplacement.

#### `Documentation UX.md`

1. remplacer le frontmatter `updated` par `2026-09-02T10:01:00+09:00` ;
2. dans `Onglet Explorer > Amis sur la carte`, préciser qu'une personne ou une sortie sélectionnée directement reste visuellement et fonctionnellement indépendante des points voisins pendant son recentrage et l'affichage de sa fiche ;
3. préciser que la fermeture rend ce marqueur de nouveau éligible au regroupement normal ;
4. vérifier le frontmatter, les wikilinks et le paragraphe ajouté dans Obsidian reading view.

#### `Documentation technique.md`

1. remplacer le frontmatter `updated` par `2026-09-02T10:01:00+09:00` ;
2. dans `Carte`, documenter que le coordinateur place une annotation sociale sélectionnée directement en focus sans retrait/réinsertion : `clusteringIdentifier = nil` et `displayPriority = .required` sont appliqués à la vue en place avant le recentrage ;
3. documenter que `beginSocialRegionChange()` protège ce recentrage programmatique et que la désélection retire/réinsère ensuite l'annotation pour restaurer son clustering ;
4. vérifier le frontmatter, les wikilinks, le paragraphe et le diagramme Mermaid existant dans Obsidian reading view.

## Acceptance criteria

- Aucun marqueur sélectionné ne fusionne avec un voisin pendant sa fiche.
- La sélection et ses actions restent fonctionnelles après le recentrage.
- La désélection réactive le clustering de ce seul marqueur.
- Les clusters non sélectionnés continuent de fonctionner normalement.

---
title: "Alléger le brouillard sans altérer les cellules révélées"
status: in_progress
date: 2026-08-18
owner: "Samuel Barraud"
related: []
tags: [plan, map, fog-of-war, ux]
---

# Alléger le brouillard sans altérer les cellules révélées

## Outcome

La carte reste clairement lisible sous le brouillard de guerre et chaque zone
révélée conserve exactement sa géométrie H3 à tous les niveaux de zoom. Aucun
lissage, élargissement, halo, ombre, flou ou effet liquide n'est appliqué.

## Context

Avant ce travail, `MapWithFogView` appliquait un voile noir à 45 %. Les essais
successifs d'arrondi, puis de morphologie, ont altéré la géométrie affichée ;
l'ouverture morphologique de 16 pixels pouvait notamment supprimer des zones
devenues petites à l'écran pendant le dézoom.

## Scope

- Inclus : opacité du brouillard, découpe exacte des cellules révélées et
  documentation associée.
- Exclus : résolution H3, acquisition de position, persistance, synchronisation
  Firebase, heat map, exploration des amis, annotations et contrôles de carte.

## Proposed approach

Conserver l'overlay mondial existant et le brouillard noir à 22 %, puis percer
directement dans le contexte Core Graphics le chemin exact de chaque cellule
H3 visible. Aucun bitmap hors écran, filtre Core Image, trait de contour ou
rayon dépendant de l'écran n'intervient dans le rendu.

## Affected files

- `wander/MapWithFogView.swift` — couleur et dessin du brouillard.
- `docs/plans/2026-08-18-fog-of-war-plus-clair-contours-lisses.md` — suivi du travail.
- `docs/solutions/2026-08-18-lisser-contours-fog-mapkit.md` — apprentissage réutilisable après validation.
- `Backlog features.md` dans le vault Obsidian Wander — suivi du changement.
- `Documentation UX.md` dans le vault Obsidian Wander — comportement visuel.
- `Documentation technique.md` dans le vault Obsidian Wander — stratégie de rendu.
- `todos/` — uniquement si la revue révèle un problème restant.

## Implementation

- [x] Réduire l'opacité du brouillard tout en préservant les détails Apple Maps.
- [x] Conserver la découpe polygonale H3 exacte sans traitement du contour.
- [x] Supprimer tous les essais d'arrondi et de masque morphologique.
- [x] Préserver l'ordre fog, heat map et explorations d'amis.
- [x] Mettre à jour la documentation technique, UX et le backlog.
- [x] Compiler l'application pour un Simulator iOS générique.
- [ ] Valider le rendu sur l'iPhone 17 Simulator.
- [x] Simplifier et revoir le changement ; consigner tout finding restant.

### Révision « liquid » approuvée puis annulée

- [x] Remplacer le petit adoucissement par un rayon opaque généreux et arrondi.
- [x] Vérifier dans le renderer que les cellules voisines se fondent sans frontière interne.
- [x] Mettre à jour la documentation et la revue selon le rendu final.
- [x] Recompiler l'application.
- [x] Annuler cette piste avant validation interactive.

### Révision « sans halo » approuvée puis annulée

- [x] Supprimer toutes les passes semi-transparentes du contour.
- [x] Conserver une seule découpe opaque, large, avec extrémités et jointures rondes.
- [x] Vérifier qu'aucun flou, glow, ombre ou dégradé n'est appliqué.
- [x] Mettre à jour la documentation pour décrire cette limite nette.
- [x] Recompiler et revoir l'application.
- [x] Annuler cette piste avant validation interactive.

### Révision « masque morphologique net » approuvée puis annulée

- [x] Remplacer le trait Core Graphics qui conserve la silhouette H3.
- [x] Construire un masque binaire local avec une marge anti-couture.
- [x] Appliquer fermeture, ouverture et seuil alpha dur sans halo.
- [x] Réutiliser un `CIContext` et borner la taille des buffers par tuile.
- [x] Mettre à jour la documentation dépôt et Obsidian.
- [x] Compiler, simplifier et revoir le changement.
- [x] Annuler cette piste après constat de disparition des zones au dézoom.

### Annulation de l'arrondi approuvée le 20 août 2026

- [x] Supprimer entièrement le masque morphologique et ses imports Core Image.
- [x] Revenir à la découpe exacte des polygones H3 sans traitement du contour.
- [x] Conserver uniquement le brouillard allégé à 22 %.
- [x] Mettre à jour la documentation dépôt et Obsidian.
- [x] Compiler, simplifier et revoir le changement.
- [ ] Vérifier au dézoom que les zones révélées ne disparaissent plus.

## Edge cases and risks

- Cellules proches du bord d'une tuile MapKit — ne sélectionner que celles dont
  le rectangle géospatial intersecte la tuile courante.
- Variation avec le zoom — conserver la géométrie H3 et laisser MapKit appliquer
  uniquement sa transformation cartographique normale.
- Cellules adjacentes — remplir tous les sous-chemins dans une seule opération
  `.clear` afin de ne pas ajouter de frontière artificielle.

## Validation

- [x] Le build Debug réussit sans nouvel avertissement.
- [ ] Les rues et libellés restent lisibles sous le brouillard en mode clair et sombre.
- [ ] Les cellules adjacentes restent entièrement révélées sans séparation interne.
- [ ] Les zones ne disparaissent plus pendant le dézoom.
- [ ] Panoramique, zoom et rotation ne produisent ni couture ni scintillement.
- [ ] Heat map, explorations d'amis, annotations et appui long ne régressent pas.
- [x] Les notes Obsidian sont vérifiées en mode lecture.

## Acceptance criteria

- Le brouillard est visiblement moins sombre que l'opacité noire initiale de 45 %.
- Le tracé conserve volontairement les limites H3 sans lissage artificiel.
- Le coût de rendu reste fluide pendant les gestes ordinaires de MapKit.
- Aucun comportement ou stockage d'exploration n'est modifié.

## Review notes

- Hardest decision: abandonner tout effet d'arrondi après avoir constaté qu'un
  traitement en pixels ne respecte pas la permanence des données géospatiales.
- Rejected alternatives: trait Core Graphics épais, masque morphologique, flou
  gaussien et modification de la résolution H3.
- Least certain: comportement visuel exact aux zooms extrêmes, à confirmer sur
  le Simulator demandé.
- Simulator: au moment de la validation, seul l'iPhone 16e est démarré ; les
  iPhone 17 sont arrêtés et n'ont pas été démarrés sans approbation du propriétaire.
- Annulation de l'arrondi: l'ouverture morphologique supprimait les composantes
  dont la taille écran devenait inférieure au rayon de 16 pixels pendant le
  dézoom. Le pipeline Core Image a donc été retiré intégralement au profit de
  la découpe polygonale H3 directe.
- Build après annulation: `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' build` réussi le 20 août 2026. Aucun nouvel avertissement lié au renderer.
- Revue après annulation: aucun import Core Image, filtre, bitmap hors écran,
  trait élargi ou composition `destinationOut` ne subsiste dans
  `FogOfWarOverlayRenderer`; seul le `setLineWidth` de la heat map reste ailleurs.
- Obsidian après annulation: `Backlog features`, `Documentation technique` et
  `Documentation UX` ont été relus en mode Aperçu avec les propriétés mises à
  jour et le comportement sans arrondi correctement rendu.

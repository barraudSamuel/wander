---
title: "Affiner les fiches carte"
status: completed
date: 2026-09-08
approved_at: 2026-09-08
completed_at: 2026-09-08T18:24:00+09:00
owner: Samuel
---

# Affiner les fiches carte

Samuel approuve les ajustements et demande explicitement de ne pas lancer de
tests. Cette instruction remplace la validation sur simulateur proposée.

## Périmètre

- Retirer l'année des dates du résumé événement et joueur.
- Afficher uniquement les icônes dans les actions des panneaux Explorer,
  avec les noms accessibles et les cibles tactiles conservés.
- Employer des emojis pour l'activité et les repères du résumé.
- Réduire la police de 17–26 à 16–21 points et resserrer les espacements.
  Garder Dynamic Type et le défilement pour les contenus longs ou agrandis.
- Simplifier les variantes de boutons devenues inutiles.

## Fichiers concernés

- `wander/OutingPlanDetailCardView.swift`
- `wander/FriendProfileSheet.swift`, panneau Explorer uniquement
- `wander/MapDetailSplitView.swift`
- `wanderUITests/MapSocialGestureUITests.swift` si une attente doit être adaptée
- Ce plan
- Coffre Obsidian `sam/wander` : `Documentation UX.md` et
  `Documentation technique.md`, avec propriété `updated` et wikilinks valides

## Mise en œuvre et validation

- [x] Appliquer les modifications de présentation.
- [x] Relire le diff et vérifier les références et libellés accessibles.
- [x] Mettre à jour les deux notes, sans ouvrir Obsidian.

Aucun test ni lancement du simulateur. Pas de compilation demandée pour ce
petit ajustement. La vérification se limite à la relecture et à la cohérence du
diff ; le rendu n'est pas revendiqué comme testé. Les 60 contrôles de la version
précédente ne constituent pas une validation de ces ajustements.

## Résultat

Les dates emploient jour, mois, heure et minute. Les actions utilisent le style
natif `iconOnly` ; les variantes de largeur et le style de label personnalisé
ont été supprimés. Les libellés, états sélectionnés et gardes des callbacks
restent en place. Les attentes des tests UI reposent sur ces noms accessibles
et ne nécessitent pas de modification.

Les emojis remplacent les symboles d'activité et de calendrier du résumé ;
le panneau joueur ajoute les repères de lieu et de mode fantôme. L'onglet Amis
conserve son formulaire natif.

La typographie passe à 16–21 points. Interligne, espacement entre paragraphes
et marges verticales sont réduits. Le minimum du panneau compact passe de
140 points mis à l'échelle +40 à +80 points, dans les limites de la fenêtre ;
le seuil de croissance typographique passe à 220 points mis à l'échelle.
Cela laisse davantage de hauteur au résumé courant sans réduire les actions.

Relecture manuelle : aucune référence restante aux variantes retirées,
libellés accessibles conservés et `git diff --check` valide. Aucun test,
compilation, lancement du simulateur ou nouvelle capture. Les notes UX et
technique ont été mises à jour à 18:23:56, avec frontmatter et liens valides.
Aucun constat restant ni apprentissage durable supplémentaire à documenter.

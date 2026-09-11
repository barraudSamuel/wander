---
title: Surlignages arrondis incluant les emojis
status: completed
date: 2026-09-10
approved_at: 2026-09-10
completed_at: 2026-09-10
owner: Samuel
---

# Surlignages arrondis incluant les emojis

Plan présenté puis explicitement validé par Samuel dans la conversation.

## Résultat et périmètre

Surligner l’emoji d’activité, la date et le groupe « 📍 nom du lieu ». Fond bleu
système léger, marge discrète et coins continus légèrement arrondis, façon squircle.
Lorsqu’un groupe passe sur plusieurs lignes, chaque portion reçoit son fond aligné
sur les caractères. Les avatars et les mots de liaison gardent leur présentation.
L’arrondi demandé autorise ce dessin local autour du texte dans l’interface native.

## Fichiers concernés

- `wander/MapEventsPanelView.swift` : regroupement des fragments avec emojis.
- `wander/MapDetailFittingText.swift` : mesure et rendu des fonds arrondis.
- `wanderTests/MapEventListPresentationTests.swift`,
  `wanderUITests/MapSocialGestureUITests.swift` : vérifications ciblées.
- Le présent plan ; constat dans `todos/` ou solution dans `docs/solutions/`
  seulement si une limite ou un apprentissage réutilisable apparaît.
- Vault `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Backlog features.md`, `Documentation UX.md`, `Documentation technique.md`,
  `00 - Wander.md`, avec propriété `updated` et wikilinks conservés.

## Mise en œuvre et critères d’acceptation

- [x] Enregistrer l’approbation.
- [x] Inclure les emojis dans les fragments surlignés.
- [x] Dessiner des fonds continus arrondis par portion de ligne avec la même
  disposition de texte que celle utilisée pour mesurer et afficher ces lignes.
- [x] Vérifier l’alignement, les lieux longs, les changements de largeur et le
  redimensionnement sur l’iPhone 17 existant, en taille standard.
- [x] Relire, consigner les résultats et mettre à jour les quatre notes Obsidian.

## Risques, limites et validation

Éviter les divergences entre géométrie du fond, glyphes et pièces jointes d’avatars,
les marges coupées et les fonds obsolètes après une réutilisation de ligne. Les
fiches sans surlignage gardent leur chemin de rendu existant. Tests unitaires du
texte et géométrie si nécessaire, parcours UI ciblés et captures après stabilisation.
Build Debug, `git diff --check`. Aucun test dédié d’accessibilité. Les skills
Compound Engineering ne sont pas disponibles ; workflow équivalent manuel.

Aucun changement Firebase, de navigation ou de données. Le défaut connu de police
emoji du simulateur reste dans le constat 048, sans modification du runtime.

## Résultats et revue

Le fond rectangulaire de l’attribut natif est remplacé par des chemins
`RoundedRectangle(style: .continuous)`. Un même `NSLayoutManager` mesure les
fragments, calcule leurs rectangles par ligne et dessine les glyphes, pièces jointes
d’avatars comprises. Les groupes « 📍 lieu » et emoji d’activité sont surlignés.
Les mesures sont invalidées au changement de largeur, contenu, police ou apparence.
Les fiches sans fragments surlignés restent sur UILabel.

La première compilation a signalé trois captures implicites de propriétés dans un
callback ; corrigées. L’API de construction des traits dépréciée est aussi remplacée
dans le fichier concerné. `/tmp/wander-rounded-highlights-validation.xcresult`
passe : huit tests unitaires et quatre parcours UI. Captures examinées dans
`/tmp/wander-rounded-highlights-screens/`, notamment le lieu long sur plusieurs
lignes et les participants après retour.

Le parcours paysage passe dans `/tmp/wander-rounded-highlights-width.xcresult`,
capture examinée dans `/tmp/wander-rounded-highlights-width-screens/`.
Le nouveau test de recalcul, en revanche, a révélé un crash reproductible à la
destruction d’une ancienne mise en page. Les diagnostics ciblés puis la pile
`/tmp/wander-rounded-highlights-stack.log` montrent `MapDetailHighlightedLayout`
→ `swift_task_deinitOnExecutorImpl` → `TaskLocal::StopLookupScope` → malloc.
Il correspond au défaut déjà documenté dans
`../solutions/2026-09-02-regrouper-marqueurs-par-proximite.md` et
[swiftlang/swift#88036](https://github.com/swiftlang/swift/issues/88036).
Le correctif réutilise un `nonisolated deinit` vide explicite ; l’objet reste détenu
uniquement par le label sur l’acteur principal. Les traces et le gestionnaire de
signal temporaires ont été retirés des tests. La reprise finale
`/tmp/wander-rounded-highlights-final.xcresult` passe : neuf tests unitaires,
y compris le recalcul et l’invalidation, ainsi que le retour après défilement.
Constat corrigé : `../../todos/049-done-p2-destruction-mise-en-page-surlignee.md`.

Revue : choix d’une même disposition TextKit pour éviter un fond calculé autrement
que les lignes affichées. Un fond unique autour du bloc ne suivrait pas ses retours
à la ligne ; superposer une seconde mesure au UILabel risquerait de les décaler.
Les caches restent bornés à 64 mesures ; chaque largeur invalide ses géométries.
Les quatre notes Obsidian prévues ont été actualisées avec leur propriété `updated`.
Aucune nouvelle solution générale : le problème Swift et son correctif étaient déjà
documentés. La limite restante est le rendu emoji du runtime, constat 048.

Bilan : build Debug, neuf tests unitaires et cinq parcours UI distincts réussis.
Captures des lieux longs, groupes, défilement, fiches et paysage examinées ; les
surlignages ont leurs coins continus et suivent les retours à la ligne. Le problème
de police emoji empêche toujours de confirmer les pictogrammes colorés eux-mêmes.
`git diff --check` passe. Aucun diagnostic Swift restant dans le fichier modifié ;
les avertissements AppIntents et de versions d’extensions restent préexistants.
Les modifications de version du projet effectuées hors de cette tâche sont conservées.
L’application normale est relancée sur le même simulateur après les tests.

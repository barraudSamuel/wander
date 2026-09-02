---
status: completed
approved_at: 2026-09-02
completed_at: 2026-09-02T09:39:03+09:00
---

# Animer l'ouverture du cluster vertical

## Outcome

Rendre visible et continue la transition entre la pile sociale compacte et sa liste verticale dépliée, ainsi que la transition inverse.

## Scope

- Corriger l'ordre de configuration qui ouvre actuellement le cluster sans animation avant l'appel animé.
- Animer la géométrie de la capsule, le fondu de la pile compacte et l'apparition verticale des lignes.
- Conserver une transition immédiate lorsque Réduire les animations est activé.
- Protéger les états finaux lors d'interactions répétées ou d'une animation interrompue.

## Non-goals

- Modifier le regroupement MapKit, le contenu des lignes ou le zoom sur un membre.
- Changer les dimensions compactes ou dépliées.

## Dependencies

- Le cluster vertical existant et son animation UIKit.

## Affected files

- `wander/MapWithFogView.swift`
- `wander/MapSocialClusterAnnotationView.swift`
- `docs/plans/2026-09-02-animer-ouverture-cluster-vertical.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`

## Implementation checklist

- [x] Déclencher l'état déplié seulement au moment de l'appel animé.
- [x] Initialiser et animer les états visuels compact et déplié.
- [x] Sécuriser la fin des animations interrompues.
- [ ] Mettre à jour la documentation UX Obsidian — bloqué : vault présent mais non inscriptible depuis cette session ; mise à jour exacte consignée ci-dessous.
- [x] Vérifier le diff, compiler et contrôler le flux sur le Simulator actif.

## Risks

- Une reconfiguration MapKit pendant la transition peut remplacer la vue du cluster.
- Des taps rapides peuvent interrompre une animation et laisser un conteneur masqué à tort.
- Les changements de taille doivent rester ancrés sur la coordonnée de la carte.

## Validation

- `git diff --check` : réussi.
- Build Debug final pour le simulateur iOS : réussi après retrait complet du scénario DEBUG local.
- iPhone 17 Simulator actif : ouverture capturée à 10 images/s ; la pile compacte s'atténue et se réduit, la capsule s'étend depuis son ancrage, puis les lignes montent de 6 pt en apparaissant. Le repli joue la transition inverse.
- Sélection d'un membre après la transition : réussie ; le marqueur réel est recentré et sélectionné.
- Interruption : la completion vérifie l'état courant avant de masquer un conteneur ; les animations utilisent `beginFromCurrentState`.
- Réduire les animations : chemin immédiat conservé et mouvement de carte désactivé via `UIAccessibility.isReduceMotionEnabled`.
- Scénario DEBUG et argument de lancement retirés ; le build final propre a été réinstallé sur le Simulator actif.
- Revue manuelle : aucun finding P1, P2 ou P3 ; aucun fichier `todos/` ajouté.

### Mise à jour Obsidian restante

Le fichier `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md` existe mais `test -w` échoue. Ne pas créer de vault de remplacement. À la prochaine session writable :

1. remplacer le frontmatter `updated` par `2026-09-02T09:39:00+09:00` ;
2. dans `Onglet Explorer > Amis sur la carte`, documenter que les marqueurs sociaux coïncidents sont présentés en pile verticale compacte, qu'un toucher transforme cette pile en liste verticale par une animation en ressort de 0,36 s, que les avatars compacts s'atténuent pendant que les lignes montent légèrement, et que le repli joue l'inverse ;
3. préciser que Réduire les animations rend la transition immédiate ;
4. vérifier le frontmatter, les wikilinks et le paragraphe ajouté dans Obsidian reading view.

## Acceptance criteria

- La pile compacte se transforme visiblement en liste verticale lors du tap.
- Le repli joue la transition inverse sans saut d'état.
- Un membre reste sélectionnable après l'animation.
- Réduire les animations supprime le mouvement.

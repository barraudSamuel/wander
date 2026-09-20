---
title: Réduire la largeur de la barre de navigation
status: in_progress
date: 2026-09-20
approved_at: 2026-09-20
---

## Résultat et périmètre

Plan présenté dans la conversation, approuvé par Samuel avec « j'approuve ».
Rapprocher les trois icônes dans une barre native centrée. Après le conteneur
réduit à 75 %, Samuel approuve avec « je valide » une réduction uniforme
supplémentaire de 10 % en largeur et en hauteur, icônes comprises. Aucun
changement de contenu, de données ou de navigation.

## Fichiers concernés

- `wander/NativeMapTabView.swift` : positionnement et espacement natifs.
- Ce plan et un constat de validation dans `todos/` si nécessaire.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md` : architecture de navigation et propriété `updated`.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md` : séparation des conteneurs carte et navigation, propriété `updated`.

## Étapes

- [x] Enregistrer l’approbation.
- [x] Configurer le groupe centré : boutons de 64 points, espacement de 8 points.
- [x] Compiler la configuration Debug pour iOS Simulator.
- [x] Consigner la vérification visuelle non exécutée suivant la demande de Samuel
  « Non, compiler seulement », dans `todos/057-ready-p2-valider-barre-compacte.md`.
- [x] Relire le changement et mettre à jour la documentation UX.

## Correctif après retour sur appareil

La seconde capture utilisateur montre que les réglages d’espacement n’ont pas
réduit la barre. L’approche révisée a été présentée dans la conversation :
conteneur de navigation centré plus étroit, carte pleine largeur, barre et
interactions natives conservées, compilation seule. Samuel demande ensuite
« check la doc et fait moi une navigation plus compact » : reprise de cette
approche et vérification de la documentation Apple avant implémentation.

- [x] Retirer les réglages d’espacement sans effet sur la capture.
- [x] Séparer le hosting plein écran du contrôleur d’onglets enfant ; borner la
  largeur de ce dernier à 75 % de la zone sûre, au plus 320 points.
- [x] Transmettre les touchers hors barre à la carte et aux panneaux.
- [x] Garder les réserves verticales système et clavier, sans réduire la zone
  horizontale de la carte ou des panneaux.
- [x] Compiler, simplifier et relire le correctif ; actualiser les deux notes
  Obsidian et le constat 057 avec les limites de validation.
- [ ] Confirmer sur appareil le résultat visuel et les interactions du correctif.

Le conteneur UIKit et le hit-testing changent ; vérifier ensuite sur appareil
la largeur, les trois onglets, le clavier, le glissement natif et les gestes
carte à gauche, au centre et à droite. Les tests existants de MotionDock
vérifient ces parcours mais pas la largeur cible. Aucun test UI n’est exécuté,
conformément à la demande de compilation seule.

Références Apple consultées le 20 septembre :

- [itemSpacing](https://developer.apple.com/documentation/uikit/uitabbar/itemspacing) : règle l’espace entre les items, pas la largeur du contrôleur.
- [Container view controller](https://developer.apple.com/library/archive/featuredarticles/ViewControllerPGforiPhoneOS/ImplementingaContainerViewController.html) : relation parent/enfant et placement de la vue racine de l’enfant.
- [Tab Bar Controllers](https://developer.apple.com/library/archive/documentation/WindowsViews/Conceptual/ViewControllerCatalog/Chapters/TabBarControllers.html) : laisser la hiérarchie de barre gérée par UIKit.

Ces documents décrivent le mécanisme utilisé, sans garantir une largeur visuelle
Liquid Glass précise. L’hypothèse que le contrôleur adapte la barre à son espace
disponible reste à vérifier sur appareil. La capture constitue l’observation
du défaut ; aucune reproduction locale n’est revendiquée.

Pré-correctif : HEAD `37507f64952245a5de86b3d6b3768011f45481f5`, modifications
de cette tâche dans NativeMapTabView, ce plan et 057. Les changements du plan
recentrage, du constat 056 et de sa solution restent hors périmètre.
Les skills CE ont finalement été retrouvés dans le cache du plugin 3.27.0.
Les consignes locales interdisent les commandes Git mutantes ; aucun stash,
commit ou changement de branche n’est exécuté.

## Risques et validation

### Réduction uniforme supplémentaire, approuvée

Le plan de réduction uniforme de 10 % a été présenté dans la conversation,
puis approuvé explicitement par Samuel avec « je valide ». Même périmètre de
fichiers : NativeMapTabView, ce plan, le constat 057 et les notes UX/technique.

- [x] Enregistrer l’approbation avant modification du code.
- [x] Appliquer un facteur 0,9 au conteneur de navigation seulement, avec
  translation calculée à partir de `bounds` pour garder le bas ancré.
- [x] Convertir les réserves verticales après transformation ; conserver la
  conversion des touchers UIKit entre les repères.
- [x] Compiler sans simulateur, relire et actualiser les deux notes Obsidian.
- [ ] Confirmer ensuite sur appareil le rendu, les touchers et le clavier.

La carte et les panneaux ne sont pas mis à l’échelle. La largeur apparente du
conteneur vaut 67,5 % de la zone sûre au maximum 288 points. Les trois images
et la hauteur de barre diminuent dans les mêmes proportions. Vérifier sur
appareil le Liquid Glass et le confort des cibles tactiles réduites.
La documentation [UIView.transform](https://developer.apple.com/documentation/uikit/uiview/transform)
précise que la transformation n’affecte pas Auto Layout et qu’il faut éviter
de lire `frame` sur la vue transformée : calcul fondé sur `bounds` et `convert`.

### Contraintes générales

Le rendu Liquid Glass peut ne pas appliquer les propriétés de largeur de la
même façon que les anciennes barres. La compilation ne prouve pas le
resserrement du contour : la comparaison visuelle est un critère d’acceptation.
Préserver les zones tactiles natives, le centrage, les panneaux et les gestes
d’appui maintenu/glissement. Aucun changement des vues internes privées.

Les skills Compound Engineering sont indisponibles : workflow suivi manuellement.
Le 20 septembre, `xcrun simctl list devices booted` exécuté avec accès au service
ne retourne aucun appareil démarré. Samuel demande ensuite « Non, compiler seulement ».
La validation visuelle et les interactions ne seront donc pas exécutées pendant ce travail.

## Résultats

### Premier essai, remplacé après la capture utilisateur

- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug
  -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution build` :
  **BUILD SUCCEEDED**, code de sortie 0. Journal `/tmp/wander-compact-tab-build.log`.
- `git diff --check` : réussi.
- Aucun avertissement de compilation Swift sur le changement. Le build signale
  les versions des extensions 15 et 27 contre 42 pour l’app, déjà suivies dans
  `todos/054-ready-p2-aligner-build-extensions.md`, ainsi que l’extraction des
  métadonnées App Intents ignorée faute de dépendance.
- Relecture : uniquement trois propriétés UIKit publiques ; assets, hauteur,
  sélection, guides de disposition et panneaux inchangés. Aucun ajustement
  supplémentaire requis après simplification manuelle.
- Note Obsidian UX mise à jour avec les valeurs et la limite de validation,
  propriété `updated` actualisée ; aucun rendu Obsidian ouvert.
- Le périmètre révisé à la demande de Samuel, réglage et compilation, est terminé.
  La réduction effective du contour d’environ 25 % n’est pas démontrée.
  Aucun enseignement de rendu n’est enregistré comme vérifié dans `docs/solutions/`.

### Correctif par conteneur réduit

- Même commande `xcodebuild` que ci-dessus, journal
  `/tmp/wander-compact-tab-container-build.log` : **BUILD SUCCEEDED**, code 0.
- Aucun avertissement Swift ; avertissement d’extraction des métadonnées
  App Intents ignorée faute de dépendance. Aucun simulateur démarré.
- `git diff --check` réussi. Relecture ciblée de `NativeMapTabView.swift` :
  relation parent/enfant UIKit, conversion du guide, largeur pleine carte,
  sélection/refus du binding, callbacks faibles et filtre de touchers contrôlés.
- `ce-simplify-code` : trois revues locales terminées. Qualité : aucun constat.
  Réutilisation : recherche d’index et filtrage tactile conservés, pour éviter
  de changer le comportement lors de cette réorganisation. Efficacité : trois
  vues vides chargées explicitement pour assurer leur fond transparent ; coût
  borné. Deux sources de layout conservées pour les changements de parent et
  d’enfant, avec garde d’égalité des insets. Aucune simplification supplémentaire.
- `Code review: targeted manual due to unrelated branch work`, conformément
  au workflow de fin de `ce-debug`. Aucun défaut bloquant retenu ; risque de
  rendu et d’interactions sans exécution consigné dans le constat 057.
- Deux notes Obsidian mises à jour et `updated` actualisé. Pas de rendu Obsidian.
- Confiance : compilation vérifiée ; comportement visuel non vérifié. Le plan
  reste `in_progress` tant que le résultat sur appareil n’est pas confirmé.
  Pas de nouvel enseignement prétendument vérifié dans `docs/solutions/`.

### Réduction uniforme de 10 %

- `UIView.transform` appliquée au conteneur uniquement, facteur 0,9 sur les
  deux axes. Translation verticale calculée avec `bounds` pour conserver le
  milieu du bord inférieur, recalculée lors du layout parent ou enfant.
- `reportContentInsets` s’exécute après la transformation ; les conversions
  UIKit des guides et des touchers intègrent l’échelle. Aucun changement des
  assets, de la carte ou des contenus Amis/Profil.
- Même commande de build Debug pour iOS Simulator générique : **BUILD SUCCEEDED**,
  code 0, journal `/tmp/wander-compact-tab-scale-build.log`. Aucun simulateur
  démarré. Uniquement le warning App Intents de métadonnées non extraites.
- `ce-simplify-code` : trois revues ciblées de `updateNavigationLayout` et de
  ses deux appels, terminées sans constat. `ce-code-review` : revue lite du
  code terminée sans défaut retenu ; reçu
  `/tmp/compound-engineering-501/ce-code-review/wander-navigation-scale-5mjvogv_/report.md`.
- Pas de nouveaux tests ni de parcours UI : réglage visuel réversible et
  validation limitée à la compilation à la demande de Samuel. Les tests
  MotionDock existants restent inchangés. Aucune preuve visuelle revendiquée.
- Notes UX et technique actualisées, avec `updated` modifié. Le plan reste
  `in_progress` uniquement pour la confirmation sur appareil suivie dans 057.

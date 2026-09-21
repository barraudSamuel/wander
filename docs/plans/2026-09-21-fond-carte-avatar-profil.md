---
title: "Fond illustré de la carte avatar du profil utilisateur"
status: completed
date: 2026-09-21
approved_at: 2026-09-21
completed_at: 2026-09-21
approval: "je valide le plan : suppression de la croix et des callbacks associés, fermeture native par glissement"
owner: Samuel
tags: [plan, ios, friends, profile]
---

# Fond de carte avatar

## Suppression approuvée de la croix de fermeture

Samuel approuve la suppression de la croix. La fiche conserve la poignée
native et se ferme par glissement vers le bas. Le recentrage reste déclenché
par `onDismiss` après la disparition de la feuille ; le bouton Itinéraire
conserve sa fermeture avant le choix d’application.

Fichiers concernés :
- `wander/FriendProfileSheet.swift`
- `wander/ContentView.swift`
- `wander/DebugSocialMapScenario.swift`
- `wanderTests/FriendProfilePresentationTests.swift`
- `wanderUITests/MapSocialGestureUITests.swift`
- `wanderUITests/MotionDockUITests.swift`
- Ce plan et `todos/060-ready-p2-valider-profils-bottom-sheet.md`
- Notes Obsidian `Documentation UX.md`, `Documentation technique.md` et
  `Backlog features.md`

- [x] Plan proposé puis explicitement approuvé avant modification.
- [x] Supprimer la croix, ses paramètres et les fonctions appelées uniquement par elle.
- [x] Adapter les tests à la fermeture native par glissement, depuis les deux hauteurs.
- [x] Compiler, vérifier fermeture/recentrage et capturer le profil sans croix.
- [x] Simplifier, relire et actualiser les notes ainsi que le suivi.

Le risque porte sur la fermeture d’une fiche agrandie et sur le recentrage après
disparition. Les tests UI existants seront adaptés pour vérifier ces parcours
sur l’iPhone 17 autorisé, à taille de texte standard. Aucun autre comportement
de caméra ni test d’accessibilité dédié ne fait partie de cet ajustement.

### Implémentation et contrôles de fermeture

- Suppression de l’overlay contenant `Button(role: .close)`, des paramètres
  `onClose` et des deux fonctions `closeFriendProfile` appelées uniquement par
  ce bouton. `onDismiss`, Itinéraire et la révocation d’amitié restent en place.
- Les tests passent par un glissement du haut du contenu jusqu’au bas de la
  fenêtre. Le test de clics sur la croix devient un contrôle de son absence
  suivi d’une fermeture depuis chaque hauteur, avec un scénario neuf par cas.
- Les trois passes de simplification ont terminé. Aucun constat de réutilisation
  ou de qualité. La proposition d’éviter le second lancement de test est écartée :
  un scénario neuf isole chaque hauteur et évite de dépendre de la réouverture
  d’un groupe après un recentrage. Aucun changement de production supplémentaire.
- Première exécution de quatre tests UI dans
  `/tmp/wander-profile-no-close-ui-tests.log` : le contrôle d’absence de croix
  et de fermeture aux deux hauteurs passe. Trois tests échouent avant leur
  fermeture, sur des attentes de poignées ou de panneaux. Deux de ces parcours
  annexes restent suivis dans `todos/060-ready-p2-valider-profils-bottom-sheet.md`.
- Le test de recentrage démarre ensuite directement avec la fiche ouverte,
  pour éviter les attentes sans rapport avec son assertion. Il atteint alors
  le contrôle de position mais compare à tort le centre visuel du groupe à sa
  coordonnée géographique. La pièce de diagnostic donne un cadre y=289, h=102
  et une cible y=399,65 ; `MapSocialClusterAnnotationView` ancre le groupe
  huit points sous son bord inférieur. Le test utilise désormais `maxY + 8`,
  avec la même tolérance de 40 points. Aucun calcul de caméra n’a été changé.
  Diagnostic conservé dans `/tmp/wander-profile-no-close-recenter-test.log`
  et `/tmp/wander-profile-no-close-test-attachments/`.

### Validation finale sans croix

- Compilation finale `build-for-testing` réussie avec les options de compilation
  consignées plus bas. Journal `/tmp/wander-profile-no-close-final-build.log`.
  Sortie 0, aucun avertissement Swift ; un avis AppIntents préexistant.
- Test `wanderUITests/MapSocialGestureUITests/testFriendSheetHasNoCloseButtonAndDismissesFromBothHeights`
  réussi sur l’iPhone 17, avec fermeture réelle depuis les deux hauteurs.
- Test `wanderUITests/MapSocialGestureUITests/testFriendDismissalRecentersAfterSheetResize`
  réussi après correction du point de mesure. Journal final
  `/tmp/wander-profile-no-close-recenter-final-test.log` : un test, zéro échec,
  `TEST EXECUTE SUCCEEDED`, sortie 0. Exécution avec `test-without-building`,
  schéma wander, Debug, destination
  `platform=iOS Simulator,id=6F13855D-10B8-45AF-9205-17C8393379E3`,
  `-disableAutomaticPackageResolution -skipPackageUpdates
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO` et filtre `-only-testing`
  du test ci-dessus. Aucun autre appareil ni test d’accessibilité dédié utilisé.
- Capture finale inspectée :
  `/Users/samuelbarraud/.codex/visualizations/2026/09/21/01a0c25f-4950-79e1-ac0a-8eaf56422643/wander-profile-no-close.png`.
  Croix absente, poignée native visible, carte et nom de 17 points conservés.
- Notes Obsidian UX, technique et backlog mises à jour ; propriété `updated`
  et wikilinks vérifiés. Revue terminée dans
  `/tmp/compound-engineering-501/ce-code-review/profile-no-close-20260921/review.json`.
  Aucun défaut introduit retenu ; les deux échecs annexes sont conservés dans
  le suivi 060. La suite complète n’est pas déclarée verte.
- `git diff --check` réussi. Aucun commit ni autre commande Git modificatrice.
  Pas de note `ce-compound` supplémentaire : le code, le commentaire du test
  et ce plan expliquent le changement et la mesure correcte de l’ancrage.

Les sections suivantes décrivent les versions antérieures.

## Correction approuvée du raccord et nom à 17 points

Samuel signale une fine ligne colorée sous le nom, puis demande de corriger
le raccord et de diminuer encore légèrement la police. La taille retenue est
17 points gras, avec la même adaptation iOS.

L’hypothèse à vérifier est le bord inférieur commun aux deux sous-chemins du
masque pair/impair. La correction prévue remplace ces contours par un seul
contour continu qui suit les courbes de l’encart, sans segment sous le nom.
Le découpage arrondi extérieur reste distinct pour borner les noms larges.

Fichiers : `wander/FriendProfileSheet.swift`, ce plan,
`todos/060-ready-p2-valider-profils-bottom-sheet.md`, les notes Obsidian
`Documentation UX.md` et `Backlog features.md`.

- [x] Correction proposée puis explicitement demandée par Samuel avant modification.
- [x] Examiner la capture fournie et comparer les masques avec un décalage sous-pixel.
- [x] Corriger le contour, puis réduire le nom à 17 points.
- [x] Compiler et inspecter les raccords en modes clair et sombre à taille standard.
- [x] Terminer la revue, le suivi et les notes Obsidian.

Risque : altérer les raccords concaves ou le recadrage. La comparaison des
captures vérifiera ces bords, le fond natif et la lisibilité du nom. Les tests
de mesure existants ne détectent pas les défauts de pixels ; la reproduction
visuelle sert de contrôle principal. Aucun test d’accessibilité dédié prévu.

La capture fournie contient une ligne colorée à y=133, encadrée par le même
fond natif à y=132 et y=134. La capture locale Amina en mode clair ne reproduit
pas cette ligne au centre. Un contrôle de rastérisation des deux formes, extraites
du code avant/après, reproduit le problème avec des écarts de 0,05, 0,1 et
0,25 point entre le bas de l’ancre et celui du fond : couverture de 38, 76 et
128 sur 255 avec l’ancien masque, contre zéro avec le nouveau. À écart nul,
les deux valent zéro. Cela confirme le mécanisme possible ; les coordonnées
exactes du profil Explorer fourni n’ont pas été instrumentées.

Le nouveau contour utilise le bas du fond comme référence unique et contourne
l’encart sans fermer de segment sous le nom. Les épaules concaves, le sommet
arrondi et le clip extérieur sont conservés. Le contrôle temporaire est dans
`/tmp/wander-profile-seam-probe.swift`, son résultat dans
`/tmp/wander-profile-seam-probe.log`. La première lecture du bitmap regardait
les lignes du haut ; le repère des lignes a été corrigé avant la comparaison.

### Validation du raccord corrigé

- `build-for-testing` réussi avec le schéma wander en Debug et les paquets
  déjà résolus. Journal `/tmp/wander-profile-seam-build.log`, sortie 0,
  `TEST BUILD SUCCEEDED`. Aucun avertissement Swift ; deux avis AppIntents existants.
- Test existant `FriendProfilePresentationTests/testSharedBodyMeasurementUsesActualWidth`
  réussi via `test-without-building` sur l’iPhone 17 autorisé, sans parallélisme.
  Un test, zéro échec, sortie 0 ; journal
  `/tmp/wander-profile-seam-measurement-test.log`. Les commandes complètes sont
  les mêmes que celles consignées plus bas pour les ajustements précédents.
- Captures réelles à la taille standard inspectées dans
  `/Users/samuelbarraud/.codex/visualizations/2026/09/21/01a0c25f-4950-79e1-ac0a-8eaf56422643/` :
  `wander-profile-seam-fixed-light.png` et `wander-profile-seam-fixed-dark.png`.
  Raccord net, nom plus petit, avatar, statut et bouton visibles. Les pixels
  centraux autour du bord inférieur suivent le fond de la feuille sans rangée
  bleue ou verte. Le simulateur retrouve son mode sombre initial.
- Trois relectures `ce-simplify-code` du delta terminées sans constat.
  Revue `ce-code-review` lite terminée, aucune correction supplémentaire :
  `/tmp/compound-engineering-501/ce-code-review/profile-seam-20260921/review.json`.
- Notes UX et backlog actualisées, timestamps et wikilinks vérifiés ; suivi
  mis à jour. `git diff --check` réussi, aucune commande Git modificatrice.
- Pas de nouveau test permanent pour cet ajustement graphique. Le contrôle
  de rastérisation vérifie le défaut précis, le test existant vérifie la mesure.
  `ce-compound` n’ajoute pas de solution : le commentaire et cette section
  conservent déjà la raison du contour continu et les limites des observations.

Les sections suivantes sont l’historique des versions précédentes.

## Réduction approuvée du nom à 18 points

Samuel approuve le passage de 20 à 18 points. La police système reste grasse
et suit la taille de texte iOS avec `@ScaledMetric(relativeTo: .title3)`.
L’ancrage, la découpe et le fond natif restent identiques ; leurs dimensions
suivent automatiquement celles du texte.

Fichiers : `wander/FriendProfileSheet.swift`, ce plan,
`todos/060-ready-p2-valider-profils-bottom-sheet.md`, les notes Obsidian
`Documentation UX.md` et `Backlog features.md`.

- [x] Plan proposé puis explicitement approuvé avant modification.
- [x] Réduire le nom à 18 points et conserver son adaptation native.
- [x] Relire le changement, compiler et capturer le rendu sur l’iPhone 17 autorisé.
- [x] Actualiser le suivi et les notes Obsidian, puis terminer la revue.

Le risque se limite au changement de dimensions du texte et de la découpe.
La compilation et une capture réelle à la taille standard valideront le rendu.
Aucun nouveau test de style ni test d’accessibilité dédié n’est nécessaire.
Les sections suivantes conservent l’historique des ajustements précédents.

### Validation du nom à 18 points

- Deux lignes de code modifiées : métrique privée de 18 points relative à
  `.title3`, puis police système grasse utilisant cette métrique. L’ancre,
  le masque, les marges et la mesure de la feuille restent inchangés.
- Trois passes `ce-simplify-code` terminées sur le delta contre
  `/tmp/wander-profile-font18-before/FriendProfileSheet.swift` : aucun constat
  de réutilisation, qualité ou efficacité ; aucune correction supplémentaire.
- Compilation app et tests réussie avec la commande `build-for-testing`
  consignée plus bas. Journal `/tmp/wander-profile-font18-build.log`, sortie 0,
  `TEST BUILD SUCCEEDED`. Aucun avertissement Swift ; un avis AppIntents existant.
- Test `FriendProfilePresentationTests/testSharedBodyMeasurementUsesActualWidth`
  réussi avec la commande ciblée `test-without-building` consignée plus bas.
  Un test, zéro échec, sortie 0. Journal
  `/tmp/wander-profile-font18-measurement-test.log`.
- Capture réelle inspectée sur l’iPhone 17 déjà démarré, mode sombre et taille
  standard `large`, avec le scénario fictif Amina sans connexion Apple :
  `/Users/samuelbarraud/.codex/visualizations/2026/09/21/01a0c25f-4950-79e1-ac0a-8eaf56422643/wander-profile-font18.png`.
  Le nom est réduit ; l’encart expose toujours le fond natif de la feuille.
  Avatar, statut, informations de position et bouton Itinéraire restent visibles.
- Notes Obsidian UX et backlog actualisées, `updated` et wikilinks vérifiés.
  Revue `ce-code-review` lite sans défaut actionnable, reçu dans
  `/tmp/compound-engineering-501/ce-code-review/profile-font18-20260921/review.json`.
- Aucun test ajouté pour cet ajustement de style. Le test existant de mesure et
  la capture vérifient la disposition. Aucun test d’accessibilité dédié exécuté.
  `ce-compound` ne produit pas de solution : ajustement courant expliqué par le code.

## Ajustement approuvé du fond de l’encart

Samuel valide la suppression de la bande noire de 12 points et le remplacement
du fond noir de l’encart par une découpe transparente de l’image. La découpe
reprend le sommet arrondi et les raccords concaves existants. Elle laisse voir
le véritable fond natif de la bottom sheet, y compris sa transparence.

Le nom garde `.title3.bold()`, soit 20 points à la taille standard. Sa couleur
devient sémantique `.primary` pour rester lisible en mode clair et sombre.
La découpe ne concerne que l’image ; le texte et l’avatar restent visibles.
Les dimensions réelles de l’encart pilotent la découpe, y compris pour un nom long.

Fichiers : `wander/FriendProfileSheet.swift`, ce plan,
`todos/060-ready-p2-valider-profils-bottom-sheet.md`, les notes Obsidian
`Documentation UX.md` et `Backlog features.md` déjà listées plus bas.

- [x] Plan révisé explicitement approuvé avant modification.
- [x] Retirer la bande et découper l’image à l’emplacement réel de l’encart.
- [x] Passer le texte en couleur sémantique et conserver la police de 20 points.
- [x] Simplifier, compiler, vérifier la mesure existante des noms longs.
- [x] Inspecter les captures réelles en modes clair et sombre sur l’iPhone 17 autorisé.
- [x] Actualiser les notes, le suivi et les preuves de validation ; terminer la revue.

Risques : découpe décalée, nom effacé avec le fond, joint visible ou texte peu
lisible. Le masque s’applique uniquement au fond, à partir des bornes de la vue
du nom. Le contenu garde sa mesure et la feuille garde son matériau natif.

Les sections suivantes retracent les versions précédentes ; ce dernier
ajustement remplace la bande et le remplissage noirs qu’elles décrivent.

### Validation du fond natif

- Une préférence d’ancre transmet les bornes de la vue du nom après ses marges
  internes. Le fond résout cette ancre dans son propre repère ; le masque pair/impair
  soustrait `ProfileNameTabShape` de l’image seule. Aucune copie du matériau de la
  feuille, couleur échantillonnée, duplication du texte ou état de mesure ajouté.
- Le cadre explicite de l’image donne au masque les dimensions de la carte malgré
  le remplissage `scaledToFill`. Le masque arrondi extérieur borne l’ensemble.
  La bande de 12 points et le remplissage noir de l’encart ont été supprimés.
- Trois passes indépendantes `ce-simplify-code` terminées sur le delta contre
  `/tmp/wander-profile-sheet-background-before/FriendProfileSheet.swift`.
  Aucun changement de réutilisation ou de qualité proposé. La fusion du contour
  arrondi avec le masque pair/impair, proposée en efficacité, est écartée : la
  découpe d’un nom large peut traverser le coin arrondi inférieur. Le remplissage
  pair/impair seul ferait alors réapparaître une zone extérieure ; le découpage
  final protège ce bord. Aucun gain de performance n’a été mesuré.
- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug
  -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution
  -skipPackageUpdates CODE_SIGNING_ALLOWED=NO build-for-testing` :
  `TEST BUILD SUCCEEDED`, sortie 0. Journal `/tmp/wander-profile-cutout-build.log`.
  Aucun avertissement Swift ; deux avis AppIntents préexistants.
- Test existant `FriendProfilePresentationTests/testSharedBodyMeasurementUsesActualWidth`
  exécuté avec `test-without-building`, destination iPhone 17
  `6F13855D-10B8-45AF-9205-17C8393379E3`, `-parallel-testing-enabled NO`, mêmes
  options de schéma/configuration et paquets que ci-dessus, filtré par
  `-only-testing:wanderTests/FriendProfilePresentationTests/testSharedBodyMeasurementUsesActualWidth`.
  Un test réussi, zéro échec, sortie 0. Journal :
  `/tmp/wander-profile-cutout-measurement-test.log`.
- Captures réelles Amina inspectées, à la taille standard iOS `large`, dans
  `/Users/samuelbarraud/.codex/visualizations/2026/09/21/01a0c25f-4950-79e1-ac0a-8eaf56422643/` :
  `wander-profile-cutout-dark.png` et `wander-profile-cutout-light.png`.
  La bande est absente, le fond natif se poursuit dans l’encart, le nom passe du
  blanc au noir selon le thème. Avatar, statut et bouton Itinéraire restent visibles.
  Le simulateur a retrouvé son mode sombre initial après capture.
- Notes Obsidian UX et backlog actualisées, propriété `updated` et wikilinks
  préservés. Le rendu des noms longs n’est pas capturé ; leur mesure est testée.
- `ce-code-review` terminé, parcours lite : aucun défaut actionnable. Reçu complet :
  `/tmp/compound-engineering-501/ce-code-review/profile-native-cutout-20260921/review.json`.
  `git diff --check` réussi. Aucune commande Git modificatrice exécutée.
- `ce-compound` : pas de nouvelle solution, la raison du masque et ses limites
  sont présentes ici et dans le code.

## Ajustement approuvé du nom

Samuel valide le 21 septembre l’encart ancré comme la nouvelle référence : sommet
arrondi, raccords concaves à gauche et à droite, base noire continue sur le bord
inférieur de la carte. Le nom passe de `.title2.bold()` à `.title3.bold()`, soit
22 à 20 points à la taille de texte standard. Le nom reste multiligne et sa hauteur
participe à la mesure ; l’avatar conserve son espace au-dessus.

Fichiers de cet ajustement : `wander/FriendProfileSheet.swift`, ce plan,
`todos/060-ready-p2-valider-profils-bottom-sheet.md`, et les deux notes Obsidian
`Documentation UX.md` et `Backlog features.md` listées plus bas. L’image reste identique.

- [x] Ajustement explicitement approuvé avant modification.
- [x] Intégrer l’encart à la base de la carte avec les raccords de la référence.
- [x] Réduire le nom à 20 points et préserver la place des noms longs.
- [x] Simplifier, compiler et vérifier le layout avec les tests existants pertinents.
- [x] Capturer le rendu réel sur l’iPhone 17 déjà autorisé par Samuel.
- [x] Mettre à jour les notes et la validation, puis relire le diff.

Risques : raccords noirs discontinus, texte long rogné ou avatar recouvert. Le nom
reste dans la pile de disposition ; seule sa forme de fond est personnalisée.
Validation prévue : compilation, mesure à deux largeurs via le test existant,
capture de la vraie fiche de démonstration à la taille de texte standard.

La première version ci-dessous a été compilée à 14:20 puis capturée à 14:29 sur
l’iPhone 17 après autorisation explicite de son démarrage. Sa validation initiale
est conservée comme historique, cet ajustement la complète.

### Validation de l’ajustement

- `ProfileNameTabShape` relie le sommet arrondi aux épaules concaves avec quatre
  courbes quadratiques. Le rayon est borné par les dimensions disponibles.
  L’encart et la base noire de 12 points sont contigus dans une pile sans
  espacement. Le fond illustré et le masque arrondi portent sur la carte entière.
- La zone de l’avatar mesure 176 points et contient l’avatar de 128 points avec
  24 points libres en haut et en bas. La hauteur du nom est ensuite libre ; il
  n’est pas superposé à l’avatar. La carte s’allonge si le nom prend davantage
  de place.
- Trois passes indépendantes `ce-simplify-code` terminées sur le delta contre
  `/tmp/wander-profile-name-before/FriendProfileSheet.swift`. Aucun constat de
  réutilisation, qualité ou efficacité. La forme personnalisée est nécessaire
  aux raccords demandés ; les formes arrondies standard ne les reproduisent pas.
- Compilation app et cibles de tests réussie : `xcodebuild -project
  wander.xcodeproj -scheme wander -configuration Debug -destination
  'generic/platform=iOS Simulator' -disableAutomaticPackageResolution
  -skipPackageUpdates CODE_SIGNING_ALLOWED=NO build-for-testing`.
  Journal : `/tmp/wander-profile-name-build.log`. `TEST BUILD SUCCEEDED`, sortie 0.
  Aucun avertissement Swift ; seuls les avis AppIntents déjà présents subsistent.
- Test existant exécuté sur l’iPhone 17 `6F13855D-10B8-45AF-9205-17C8393379E3` :
  `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug
  -destination 'platform=iOS Simulator,id=6F13855D-10B8-45AF-9205-17C8393379E3'
  -disableAutomaticPackageResolution -skipPackageUpdates -parallel-testing-enabled NO
  -only-testing:wanderTests/FriendProfilePresentationTests/testSharedBodyMeasurementUsesActualWidth
  CODE_SIGNING_ALLOWED=NO test-without-building`.
  Résultat : un test réussi, zéro échec, sortie 0. Le nom long est mesuré à 240
  et 420 points de largeur. Journal : `/tmp/wander-profile-name-measurement-test.log`.
- Capture réelle inspectée sur le simulateur autorisé, avec le scénario Amina
  et la vraie `FriendProfileContentView`, sans connexion Apple :
  `/Users/samuelbarraud/.codex/visualizations/2026/09/21/01a0c25f-4950-79e1-ac0a-8eaf56422643/wander-profile-name-anchored.png`.
  Le fond remplit la carte ; raccords, base continue, espacement de l’avatar,
  nom réduit, statut et bouton Itinéraire sont visibles. Les gestes et autres
  états de localisation ne sont pas validés par cette capture.
- `ce-code-review` terminé, portée locale et parcours lite : aucun défaut
  actionnable. Reçu complet dans
  `/tmp/compound-engineering-501/ce-code-review/profile-name-anchored-20260921/review.json`.
  `git diff --check` réussi. Aucun changement Git de l’index ou de l’historique.
- Les deux notes Obsidian prévues sont actualisées à 14:50:13 KST, avec les
  propriétés `updated` et tous les wikilinks préservés. Le suivi 060 distingue
  la capture Amina vérifiée de la mesure des noms longs et des gestes restants.
- La catégorie de texte du simulateur est `large`, taille standard iOS.
  Aucun test d’accessibilité dédié, ni création ou démarrage d’autre simulateur.
- `ce-compound` : pas de nouvelle solution. La forme et les contraintes de
  disposition sont directement lisibles dans le code et le présent plan.

## Résultat et périmètre approuvés

Dans la fiche utilisateur ouverte depuis la carte, afficher l’image fournie par
Samuel derrière l’avatar centré. Le fond remplit la carte avec un recadrage centré,
équivalent à `object-fit: cover`. Le nom apparaît en blanc dans un petit encart
noir arrondi, à cheval sur le bord inférieur, inspiré du badge de la référence.
Le statut et les informations de localisation restent sous la carte.

Cette personnalisation visuelle précise est demandée et approuvée par Samuel.
Les contrôles et la présentation de la feuille restent natifs. L’onglet Profil,
les pins, la synchronisation et le modèle de données ne changent pas.

## Fichiers concernés

- `wander/FriendProfileSheet.swift` : composition de l’identité dans le contenu partagé.
- `wander/Assets.xcassets/ProfileCardBackground.imageset/Contents.json` et
  `ProfileCardBackground.png` : image fournie, embarquée dans l’application.
- `docs/plans/2026-09-21-fond-carte-avatar-profil.md` : suivi et validation.
- `todos/060-ready-p2-valider-profils-bottom-sheet.md` : validation visuelle différée.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md` : suivi de la carte avatar.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md` : composition des fiches utilisateur et propriété `updated`.

## Mise en œuvre

- [x] Plan approuvé explicitement avant les changements.
- [x] Embarquer l’image originale dans un asset nommé.
- [x] Composer le fond recadré, l’avatar et l’encart du nom.
- [x] Simplifier et relire le diff.
- [x] Compiler et contrôler les fichiers modifiés.
- [x] Actualiser les deux notes Obsidian et consigner la validation.

## Choix d’implémentation et risques

- Exécution native inline, une seule modification de vue et un asset associé.
- Arbre de travail propre au démarrage, branche `main`. Les instructions de Samuel
  interdisent toute commande Git modificatrice : travail dans le checkout courant,
  sans création de branche, indexation, commit ou publication.
- Fond dans une zone de hauteur fixe et largeur proposée par la feuille. SwiftUI
  propose les dimensions de cette zone à son fond ; le masque arrondi borne l’image.
- Nom multiligne dans le flux de disposition, avec chevauchement vertical limité.
  Sa hauteur participe à la mesure commune et ne doit pas recouvrir le statut.
- Conserver les états fantôme, position ancienne et indisponible, le bouton
  Itinéraire et le bouton de fermeture.
- Ne pas ajouter de test reproduisant les constantes de style. Les tests existants
  `FriendProfilePresentationTests` couvrent déjà mesure selon la largeur et préparation
  unique. Leur contrat reste pertinent ; validation par compilation et revue du layout.

## Validation et critères d’acceptation

- [x] Build iOS Simulator réussi, sans nouvel avertissement lié à ce changement.
- [x] Image source copiée à l’identique, asset valide, diff sans erreurs d’espacement.
- [x] Revue du recadrage, du nom multiligne et de la mesure partagée.
- [x] Condition de validation visuelle vérifiée : aucun iPhone 17 démarré, contrôle non exécuté.

Le 21 septembre, `xcrun simctl list devices booted` ne retourne aucun appareil
démarré. Conformément au plan approuvé, aucun simulateur ne sera lancé. Le rendu,
les noms longs et la hauteur réelle de la fiche resteront à confirmer sur appareil.
Aucun test d’accessibilité dédié n’est prévu.

## Revue et documentation

- `ce-simplify-code` : trois revues indépendantes terminées, réutilisation,
  qualité et efficacité. Une simplification réunit les deux observations retenues :
  suppression du `GeometryReader` inutile et du second découpage rectangulaire.
  Le fond reçoit la taille de la vue principale et le masque arrondi découpe
  l’ensemble. Aucun autre changement de qualité demandé ; aucun constat écarté.
- `ce-code-review`, portée locale contre `HEAD`, parcours lite : aucun défaut
  actionnable. Vérification de la composition, du nom multiligne dans le flux,
  des critères du dépôt et du plan approuvé. Reçu complet :
  `/tmp/compound-engineering-501/ce-code-review/profile-card-20260921/review.json`.
  Les assets non suivis sont vérifiés séparément par hash, manifeste et compilation.
- Choix principal : le chevauchement utilise l’espacement de la pile, pas un
  décalage visuel qui oublierait la hauteur du nom lors de la mesure. Le bandeau
  garde une hauteur de 200 points et l’avatar sa taille de 128 points.
- `ce-test-xcode` : connecteur XcodeBuildMCP absent de la session. Validation
  équivalente par Xcode CLI, conforme au périmètre conditionnel approuvé :
  `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug
  -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution
  -skipPackageUpdates CODE_SIGNING_ALLOWED=NO build-for-testing`.
  Résultat `TEST BUILD SUCCEEDED`, code de sortie 0. Journal :
  `/tmp/wander-profile-card-build.log`.
- L’application, `wanderTests` et `wanderUITests` compilent ; aucun test exécuté.
  Aucun avertissement Swift. Avis AppIntents sans framework et versions préexistantes
  des extensions 15/27 contre 42, déjà suivies dans le constat 054.
- `git diff --check` réussi. Manifeste JSON valide ; SHA-256 du PNG identique à
  l’image fournie, 2 372 509 octets. Aucune commande Git modificatrice.
- Les deux notes Obsidian prévues ont été actualisées à 14:18:59 KST, avec leur
  propriété `updated` et conservation de tous les wikilinks. Obsidian n’a pas été ouvert.
- Limite : aucun rendu ni geste observé en exécution. Le suivi 060 contient les
  vérifications du fond, des noms longs, de la séparation du statut et de la hauteur.
- `ce-compound` : aucune nouvelle solution. La composition et ses contraintes se
  lisent directement dans le code et cette documentation ; aucun apprentissage
  non évident vérifié ne justifie une note supplémentaire.

---
title: "Rendre les interactions MapKit immédiates"
date: 2026-09-02
last_updated: 2026-10-09
module: "Carte sociale"
problem_type: ui_bug
component: frontend
severity: medium
symptoms:
  - "Un toucher peut sélectionner deux amis dont les avatars sont proches"
root_cause: async_timing
resolution_type: code_fix
tags: [solution, mapkit, gestures, performance, ux]
related:
  - ../plans/2026-09-02-rendre-taps-carte-immediats.md
  - ../plans/2026-10-09-selection-unique-amis-proches.md
---

# Rendre les interactions MapKit immédiates

## Problème

L'ouverture d'un ami, d'un événement ou d'un groupe reposait uniquement sur
`MKMapViewDelegate.mapView(_:didSelect:)`. MapKit arbitre cette sélection avec
ses gestes de panoramique et de zoom, ce qui introduit un temps mort perceptible
avant que l'application reçoive le callback. Les animations de 360 ms pour un
groupe et de 420 ms pour une fiche événement amplifiaient ensuite cette lenteur.

## Résolution

`MapWithFogView.Coordinator` installe un sous-type passif de
`UIGestureRecognizer`, limité par son delegate aux vues d'annotations sociales
compactes et au fond de carte. Il fournit un retour d'opacité dès le début du
toucher, s'annule lorsque le doigt dépasse la tolérance de mouvement, puis
active l'annotation au relâchement avant de demander sa sélection à MapKit.
L'observateur rapporte le toucher sans reconnaître de geste UIKit ; ses
méthodes `canPrevent` et `canBePrevented` renvoient `false`. Il ne peut donc pas
voler le premier tap au reconnaisseur double tap de MapKit.

Le même chemin d'activation reste appelé par `didSelect` pour les sélections
natives et programmatiques. VoiceOver et Switch Control conservent ce chemin
natif, sans activation par l'observateur passif.

La première correction absorbait un callback natif portant le même identifiant
d'annotation. La vidéo et les tests du 9 octobre montrent sa limite : MapKit
peut sélectionner un voisin B après que l'observateur a activé A. Les deux
identifiants diffèrent, donc deux profils et deux demandes de position partent.
Une déduplication par ami dans le service ne corrigerait pas cette séquence.

Le Coordinator mémorise désormais la cible au début du toucher et n'active
celle-ci qu'au relâchement valide. Les callbacks natifs de ce toucher ne
délivrent aucune autre action. Si MapKit sélectionne un voisin, le Coordinator
rétablit la bonne sélection native avant que sa désélection différée efface le
focus. La protection reste présente après le premier callback, pendant une
seconde au maximum. Une nouvelle interaction ou une sélection explicite d'une
autre cible la libère immédiatement ; l'écho SwiftUI du profil déjà ouvert ne
la libère pas. Annulation, démontage et gestes de carte la libèrent aussi.

Le reconnaisseur accepte également un toucher commencé sur le fond de carte.
S'il se termine sans dépasser la tolérance de mouvement, les annotations
sociales sélectionnées sont désélectionnées sans animation MapKit : la
fermeture ne dépend donc plus de `didDeselect` produit par le tap interne de la
carte. Un panoramique annule cette fermeture, et les contrôles ou éléments dont
le trait accessible est un bouton restent exclus.

L'ordre du hit-test est important : un `UIControl` enfant est exclu en premier,
mais une `MKAnnotationView` doit être reconnue avant d'examiner son trait
accessible `.button`. Sinon les pins accessibles sont eux-mêmes exclus et
l'ouverture retombe silencieusement sur la sélection différée de MapKit.

Les gestes MapKit restent simultanés. Les rangées interactives d'un groupe
ouvert sont exclues parce qu'elles sont des `UIControl`, tout comme les
accessoires de callout. Aucun reconnaisseur interne de MapKit n'est désactivé ou
reconfiguré.

L'ouverture d'un groupe et la transition de la fiche durent désormais 180 ms.
Le groupe rend ses rangées opaques dès la première frame et la fiche utilise une
transition d'échelle sans fondu initial.

## Preuves

### Correction des amis proches du 9 octobre

- Avant correction, le vrai Coordinator produisait `[first, second]` ou
  `[second, first]` pour un seul toucher, selon l'ordre imposé des callbacks.
- Les huit régressions du Coordinator vérifient les deux ordres, les nouveaux
  touchers, l'annulation, l'écho SwiftUI, une autre demande de profil, un toucher
  répété et l'expiration de la protection. Ces tests utilisent le delegate de
  production, pas une copie de sa logique.
- Le scénario UI utilise deux amis géographiquement distincts dont les cibles
  tactiles se chevauchent. Il compte les callbacks réellement sortants et
  vérifie A puis B et l'absence d'une seconde activation tardive pendant la présentation.
- Les résultats exacts, les limites de l'environnement et la comparaison avec
  la version d'origine sont consignés dans le plan du 9 octobre lié ci-dessus.

### Validation historique du 2 septembre

- `git diff --check` réussit.
- Le build Debug pour iOS Simulator réussit.
- Les seuls avertissements sont les deux différences de `CFBundleVersion`
  préexistantes entre l'app et ses extensions.
- Le build est installé et lancé sur l'iPhone 17 Simulator existant.
- La validation de taps réels reste bloquée par l'écran de connexion Apple du
  simulateur et ne doit pas être considérée comme acquise.

## Prévention

- Une interaction applicative prioritaire ne doit pas dépendre exclusivement
  de la reconnaissance de sélection interne d'un composant cartographique.
- Conserver le callback natif comme fallback accessible et programmatique.
- Arbitrer l'interaction avant ses effets : deux annotations différentes
  peuvent appartenir au même toucher. Ne pas libérer la protection au premier
  callback, et vérifier les callbacks sortants plutôt que seulement la dernière
  fiche visible. Un second vrai toucher reste une nouvelle interaction.
- Limiter tout reconnaisseur supplémentaire aux cibles nécessaires et annuler
  rapidement dès qu'un déplacement commence.
- Mesurer séparément le temps avant callback et la durée de l'animation ; une
  animation de plusieurs centaines de millisecondes peut être perçue comme de
  la latence même si l'état change immédiatement.

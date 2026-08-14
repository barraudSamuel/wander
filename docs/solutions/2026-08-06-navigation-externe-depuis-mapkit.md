---
title: "Piloter une callout MapKit et une fiche SwiftUI avec l’état vivant"
date: 2026-08-06
last_updated: 2026-08-14
category: architecture-patterns
module: friend-presence-map
problem_type: architecture_pattern
component: frontend_stimulus
severity: high
applies_when:
  - "Une interaction MapKit présente une modale SwiftUI alimentée par des données observables"
  - "Une position partagée peut vieillir ou devenir inaccessible pendant la présentation"
  - "Un chargement doit rester distinct d’une valeur valide à zéro"
  - "Une action externe dépend d’une autorisation ou d’une donnée à durée de vie courte"
tags:
  - mapkit
  - swiftui
  - friend-presence
  - presentation-state
  - location-freshness
  - run-loop
  - privacy
  - exploration-progress
related_plan: "../plans/2026-08-06-rejoindre-un-ami.md"
---

# Piloter une callout MapKit et une fiche SwiftUI avec l’état vivant

## Context

Une callout `MKAnnotationView` doit rester compacte et native tout en
déclenchant des présentations qui appartiennent à SwiftUI. Dans Wander, la
callout d’un ami contient deux boutons système de 44 points, affichés côte à
côte avec leurs SF Symbols, ainsi qu’un libellé compact sur l’âge de la
position. Les libellés **Rejoindre** et **Voir le profil** restent exposés à
l’accessibilité. Les détails vivent dans une `Form` SwiftUI séparée.

Le point délicat n’est pas seulement le pont UIKit vers SwiftUI. Une position
précise peut vieillir, disparaître ou devenir interdite après la révocation de
l’amitié pendant que le dialogue ou la fiche reste ouvert. Un instantané
complet de la coordonnée pris au toucher devient alors obsolète sans que la
présentation le sache.

Des essais historiques d’automatisation du parcours MapKit ont échoué avec
`AXError.cannotComplete` (session history). Un build réussi ne remplace donc
pas la validation du focus VoiceOver, du Dynamic Type et des transitions de
présentation dans un vrai simulateur ou sur appareil.

## Guidance

### Faire remonter une identité, pas un instantané sensible

Le pont MapKit expose des callbacks `(String) -> Void`. Le coordinateur capture
l’identifiant porté par `FriendLocationAnnotation`, puis `updateUIView`
rafraîchit les callbacks vers SwiftUI (`wander/MapWithFogView.swift:1254`,
`wander/MapWithFogView.swift:1285`, `wander/MapWithFogView.swift:1955`).

SwiftUI conserve seulement cet identifiant dans un petit état de sélection :

```swift
private struct FriendSelection: Identifiable, Equatable {
    let userID: String
    var id: String { userID }
}
```

Cette identité exprime une intention de présentation. Elle ne constitue pas
une autorisation durable d’utiliser les données qui existaient au moment du
toucher.

### Laisser chaque couche présenter ce qu’elle maîtrise

UIKit construit la callout avec `UIButton.Configuration`, `UILabel` et
`UIStackView`. SwiftUI possède l’alerte de navigation et la `.sheet(item:)`.

La fiche utilise les composants natifs `NavigationStack`, `Form`, `Section`,
`LabeledContent` et `ProgressView`. La callout locale reste informationnelle et
conserve sa résolution et sa copie d’adresse ; les actions d’ami utilisent un
mode de contenu distinct.

### Résoudre les données vivantes depuis l’identité

`FriendProfileSheet` reçoit un `userID` et observe directement
`FriendSyncService` et `CityBoundary`. Son nom, sa couleur, son exploration et
sa position sont des propriétés calculées à partir des collections publiées
(`wander/FriendProfileSheet.swift:40`, `wander/FriendProfileSheet.swift:203`).

Une mise à jour Firestore apparaît ainsi dans la fiche déjà ouverte. Si
l’amitié est révoquée, la fiche appelle `dismiss()` et l’état de sélection est
également réconcilié par le parent (`wander/FriendProfileSheet.swift:195`,
`wander/ContentView.swift:513`).

### Séparer les états asynchrones des valeurs métier

Une exploration chargée contenant zéro cellule est une valeur valide. Elle ne
doit pas être confondue avec le premier snapshot encore en attente. Le service
garde donc un ensemble distinct des identifiants dont le snapshot a été reçu,
y compris lorsqu’il est vide (`wander/FriendSyncService.swift:128`).

La fiche représente séparément :

- le chargement de l’exploration ;
- la préparation ou l’indisponibilité des frontières de ville ;
- l’absence de position partagée ;
- une position hors des villes prises en charge ;
- une progression disponible.

Le total n’est affiché comme un nombre qu’après le chargement. Cela préserve la
différence entre « pas encore chargé » et « chargé avec zéro zone »
(`wander/FriendProfileSheet.swift:48`, `wander/FriendProfileSheet.swift:93`,
`wander/FriendProfileSheet.swift:242`).

### Séparer disponibilité et fraîcheur

`FriendLocation.maximumAge` définit une fenêtre de cinq minutes et `isFresh`
tolère seulement un faible décalage futur. Cette règle ne décide plus si la
position existe : elle décide uniquement si l’interface peut la présenter
comme récente.

1. À la réception Firestore, une coordonnée valide et un horodatage qui n’est
   pas excessivement futur sont conservés, même lorsque l’échantillon est
   ancien.
2. Un ensemble publié contient séparément les amis dont la position est encore
   récente.
3. À l’échéance, une minuterie retire seulement l’identifiant de cet ensemble ;
   elle ne supprime pas la dernière coordonnée connue.
4. La navigation reconstruit toujours sa destination depuis le service vivant,
   vérifie l’amitié et la coordonnée, puis annonce l’horodatage avant de lancer
   l’application externe.

La minuterie de fraîcheur est ajoutée à `RunLoop.main` en mode `.common` : elle
continue ainsi à avancer pendant les gestes MapKit. La transition conserve la
taille du pin mais abaisse son opacité à 50 %, puis remplace « Au même endroit
depuis… » par « Dernière position reçue… » dans le callout et le profil. Une
nouvelle position restaure automatiquement l’opacité complète.

### Garder la géométrie du pin indépendante de l’état

Un statut métier ne doit pas modifier la surface apparente d’une annotation.
Le marqueur de Wander utilise donc toujours un conteneur rond de 44 × 44
points, un cercle coloré de 36 points et l’initiale du pseudo. Une ombre noire
courte assure seulement la lisibilité sur la carte. Aucun halo coloré, avatar
ou pointe n’est appliqué, et la taille du cœur ne varie jamais. Pour une
position récente qualifiée, un texte circulaire statique affiche la durée de
présence autour du rond. Il n’ajoute ni rotation ni glow et disparaît lorsque
la position devient ancienne. L’opacité du cœur passe alors à 50 %.

`centerOffset` et `calloutOffset` restent à zéro : le centre du rond coïncide
avec la coordonnée MapKit. Ce réglage est identique pour l’utilisateur courant,
les amis et les positions anciennes. La zone transparente de l’annotation est
plus large pour accueillir le texte (88 × 88), mais le cœur visible reste à
44 × 44 et demeure exactement concentrique.

### Réconcilier les présentations avec les droits courants

Les changements des amis acceptés ou des positions appellent
`reconcileFriendPresentations`. Le dialogue **Rejoindre** disparaît si l’amitié
ou la position valide disparaît ; la fiche disparaît si l’amitié est révoquée
(`wander/ContentView.swift:208`, `wander/ContentView.swift:513`).

La destination de navigation est reconstruite à partir de l’état courant et
doit satisfaire les gardes suivantes :

```swift
guard acceptedFriendUserIDs.contains(userID),
      let location = friendSyncService.friendLocations[userID],
      location.userID == userID,
      CLLocationCoordinate2DIsValid(location.coordinate),
      location.coordinate.latitude.isFinite,
      location.coordinate.longitude.isFinite else {
    return nil
}
```

### Construire les liens externes avec des APIs structurées

Google utilise une URL universelle créée avec `URLComponents`, ce qui conserve
un repli web. Naver utilise son schéma, vérifie sa couverture et
`UIApplication.canOpenURL` (`wander/ContentView.swift:383`,
`wander/ContentView.swift:404`, `wander/ContentView.swift:425`). Le schéma
`nmap` est déclaré dans `LSApplicationQueriesSchemes`
(`wander/Info.plist:7`).

Les callbacks et la fiche de profil ne transportent ni n’affichent la
coordonnée. L’action externe reconstruit sa destination depuis
`FriendSyncService` au dernier moment.

## Why This Matters

Ce patron ferme quatre régressions fréquentes dans un pont UIKit/SwiftUI :

- une fermeture de coordinateur devenue obsolète ;
- une fiche figée pendant une écoute temps réel ;
- la confusion entre « zéro » et « pas encore chargé » ;
- l’ouverture d’une position révoquée ou présentée sans son horodatage.

Il maintient aussi une frontière de confidentialité claire. L’annotation et la
couleur identifient visuellement un ami, mais ne prouvent pas que la relation ou
la position est encore autorisée au moment de l’action.

## When to Apply

Appliquer ce patron lorsqu’une vue UIKit embarquée dans SwiftUI déclenche une
modale, lorsque la présentation dépend de listeners temps réel, ou lorsqu’une
action utilise une donnée révocable ou à durée de vie courte. Il convient
notamment aux annotations réutilisables, profils collaboratifs, invitations et
actions de navigation externe.

Pour une donnée locale et réellement immuable, une valeur complète dans
`.sheet(item:)` peut rester plus simple. Pour une donnée sensible ou
temporelle, conserver l’identité et revalider la valeur auprès de la source
observable au moment exact de l’action.

## Examples

Une fiche pilotée par identité reste branchée sur le service vivant :

```swift
.sheet(item: $selectedFriendProfile) { selection in
    FriendProfileSheet(
        userID: selection.userID,
        service: friendSyncService,
        cityBoundary: cityBoundary,
        cityBoundaryResolutionState: $cityBoundaryResolutionState
    )
}
```

La sémantique de chargement reste indépendante de la valeur :

```swift
let isLoaded = service.loadedFriendExplorationUserIDs.contains(userID)
let exploredCount = service.friendExplorations[userID]?.cellIDs.count ?? 0
```

Ici, `isLoaded == true && exploredCount == 0` signifie « exploration chargée
et vide », pas « chargement en cours ».

## Validation

- `plutil -lint wander/Info.plist` réussit.
- Le build Debug pour la destination générique iOS Simulator réussit avec
  `xcodebuild`.
- `git diff --check` ne signale aucune erreur d’espace.
- Une revue indépendante a confirmé les chemins de révocation, de chargement
  et de fraîcheur avant leur correction.
- Le comportement exact de Google Maps et Naver Map, l’ordre de focus
  VoiceOver et les plus grandes tailles Dynamic Type restent à valider sur un
  simulateur démarré ou un appareil.

## Related

- Plan d’origine : [Rejoindre un ami](../plans/2026-08-06-rejoindre-un-ami.md)

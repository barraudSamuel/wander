---
title: "Transmettre les zones sûres sous une barre native avec une carte persistante"
module: "Navigation et carte Explorer"
date: "2026-09-10"
problem_type: ui_bug
component: frontend
severity: medium
symptoms:
  - "Le panneau Profil recouvre la barre native"
  - "La fermeture d’une fiche carte passe sous la barre d’état"
root_cause: wrong_api
resolution_type: code_fix
framework_version: "iOS 26.3 Simulator, SDK iOS 26.2"
tags: [swiftui, uikit, safe-area, tab-bar, mapkit]
---

# Zones sûres et carte persistante sous les onglets

## Problème observé

Le remplacement d’une barre personnalisée par un `UITabBarController` a rétabli
les icônes et gestes natifs, mais le contenu du hosting controller persistant
ignorait les zones sûres. Les tests de présence des onglets et d’appui-glissement
passaient alors que le panneau couvrait la barre et que les fiches carte perdaient
leur marge sous l’encoche. Le correctif reste local, non commité.

## Mesure discriminante

Sur la fenêtre portrait de 402 × 874 points, le contrôleur UIKit indiquait 62 points
en haut et 34 en bas. Son guide de contenu était `(0, 62, 402, 729)`, arrêté au
sommet de la barre à y=791. Le hosting controller conservé hors des trois
contrôleurs d’onglet sélectionnables indiquait pourtant des insets nuls ; SwiftUI
mesurait toute la fenêtre, avec des insets nuls également.

Ajouter 49 points à `additionalSafeAreaInsets.bottom` n’a pas modifié cette
mesure. Un `GeometryReader` extérieur n’a pas suffi non plus. Le panneau terminait
à y=862 au lieu de s’arrêter avant la barre. Ce diagnostic concerne ce montage
de contrôleurs ; il ne signifie pas que les insets automatiques échouent pour
les hosting controllers utilisés normalement comme contenu d’un onglet.

## Correction

`wander/NativeMapTabView.swift` conserve un seul hosting controller et calcule
les marges depuis les guides publics `contentLayoutGuide` et `keyboardLayoutGuide`.
Il les transmet par quatre `safeAreaInset` SwiftUI. Ses régions automatiques sont
désactivées pour éviter un double calcul. Les valeurs changées sont transmises
au tour suivant de la boucle principale, car UIKit peut effectuer son layout
pendant une mise à jour du representable.

```swift
let contentFrame = contentLayoutGuide.layoutFrame
let bottom = min(contentFrame.maxY, view.keyboardLayoutGuide.layoutFrame.minY)
```

La carte peut prolonger son rendu derrière les zones sûres ; les panneaux et
les contrôles lisent la zone réservée. L’animation appartient au panneau seul.
La barre iOS 26 étant imbriquée dans un conteneur, placer le hosting sous son
ancêtre directement attaché à la vue racine. Passer `tabBar` à `insertSubview`
alors qu’elle appartient à un autre parent avait placé le hosting devant elle.
La remontée des `superview` utilise uniquement les API publiques.

## Prévention et validation

Une barre trouvée dans l’arbre accessible ne prouve ni sa visibilité ni le bon
placement de son voisinage. Vérifier le bord inférieur du panneau contre le bord
supérieur de la barre, les positions des icônes et une fiche carte touchable sous
l’encoche. Relire aussi des images pendant la transition, pas seulement à l’arrêt.

Les sept tests de géométrie, carte, clavier, défilement, rotation et gestes passent
sur l’iPhone 17 existant. Le test natif renforcé passe aussi après deux appuis
rapprochés, puis un appui maintenu et un glissement. Les parcours VoiceOver vocaux
et ceux du compte réel restent hors de cette validation locale.

Voir [le plan et les résultats exacts](../plans/2026-09-10-retablir-barre-native.md)
et la [documentation Apple des régions sûres du hosting controller](https://developer.apple.com/documentation/swiftui/uihostingcontroller/safearearegions).

---
title: "Faire remplir une feuille SwiftUI par un UIViewControllerRepresentable"
date: 2026-09-27
category: ios-ui
tags: [solution, swiftui, safe-area, sheet]
related_plan: "../plans/2026-09-27-supprimer-bande-blanche-profil.md"
---

# Faire remplir une feuille SwiftUI par un UIViewControllerRepresentable

## Problem

La fiche de profil est une feuille SwiftUI dont le contenu visible est un
`UIViewControllerRepresentable`. Son `Form` s'arrêtait au-dessus du bord
inférieur de la feuille : une bande blanche fixe recouvrait le bas, quelle que
soit la position de défilement. La feuille d'avatar, purement SwiftUI, n'avait
pas ce défaut.

## Root cause

La reproduction sur l'iPhone 17 simulé a montré que le contenu défilant ne
remplissait pas la zone inférieure attribuée à la présentation. Étendre le
`Form`, puis la racine hébergée dans `UIHostingController`, ne changeait pas
le rendu. Le réglage `safeAreaRegions` du contrôleur visible ne suffisait pas
non plus tant que le representable lui-même n'ignorait pas la safe area basse
de la feuille. Cette succession d'essais situe la limite effective à la
frontière SwiftUI/UIKit de la présentation.

## Solution

Appliquer `.ignoresSafeArea(.container, edges: .bottom)` au
`MapProfileNativeContent` placé dans chaque feuille, puis ne garder que la
région `.keyboard` sur son `UIHostingController` visible. Le `Form` personnel
et le `ScrollView` ami conservent une marge basse dans leur contenu défilant.
La mesure du palier compact utilise un contrôleur distinct et reste inchangée.

## What did not work

- Colorer le fond du contrôleur d'hébergement : la bande était masquée sans
  donner plus de place au contenu.
- Ignorer la safe area sur le `Form` ou sur sa racine hébergée : le
  representable restait limité par la présentation extérieure.
- Désactiver uniquement la région de conteneur dans le contrôleur visible :
  le `Form` s'arrêtait encore avant le bord inférieur.

## Validation

- `xcodebuild ... build-for-testing` a réussi sans nouveau diagnostic Swift.
- Sur l'iPhone 17 simulé, en modes clair et sombre, le formulaire personnel
  s'étend jusqu'au bord arrondi ; le dernier bloc reste entièrement visible
  après défilement. Le palier compact et la feuille d'avatar ont été revus.
  Avec le clavier logiciel ouvert, le champ « Code ami » reste visible au-dessus.
- Deux tests UI ciblés ont réussi : sélection d'avatar et parcours du profil
  personnel vers la fiche ami.

## Reusable lesson and prevention

Quand une feuille SwiftUI héberge un `UIViewControllerRepresentable`, vérifier
la safe area à la fois au niveau du representable et du contrôleur hébergé.
Comparer une capture avant/après avec un défilement réel jusqu'au dernier
élément : une compilation ou une couleur de fond identique ne prouve pas que
la zone défilante atteint le bord.

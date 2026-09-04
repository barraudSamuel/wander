---
title: "Parser un payload Naver compact sans confondre son préfixe et son nom"
date: 2026-09-04
category: ios
tags: [solution, share-extension, naver, parsing]
related_plan: "../plans/2026-09-04-corriger-titre-partage-naver.md"
---

# Parser un payload Naver compact sans confondre son préfixe et son nom

## Problem

Un partage Naver comme
`[NAVER Maps] 녹녹 서울 마포구 연남동 249-11 https://naver.me/xB7Oc7MR`
préremplissait `[NAVER Maps]` comme nom de l’événement au lieu de `녹녹`. Le
payload réel peut être transmis sur une seule ligne, alors que le parseur
historique attendait surtout une ligne pour le nom et une autre pour l’adresse.

## Root cause

`SharedPlaceResolver` filtrait seulement le titre générique singulier
`NAVER MAP`. La variante plurielle `NAVER Maps` restait donc une ligne utile.
De plus, `placeDetails` choisissait le texte partagé avant le paramètre `title`
de la redirection, même quand cette redirection fournissait déjà un nom et des
coordonnées explicites.

## Solution

La résolution conserve l’interception existante de la première redirection
Naver, puis lit son paramètre `title` uniquement pour un hôte Naver reconnu.
Ce titre devient le nom canonique du lieu quand la redirection contient les
coordonnées.

Le texte partagé est ensuite normalisé en trois étapes :

1. retirer les URLs Web détectées par `NSDataDetector` ;
2. retirer les préfixes Naver génériques singuliers, pluriels, entre crochets
   occidentaux ou coréens ;
3. utiliser le nom canonique comme frontière au début du texte restant pour
   extraire l’adresse sans découper arbitrairement les noms composés.

Le chemin générique par lignes, métadonnées URL et recherche MapKit reste
inchangé lorsque l’URL n’appartient pas à Naver.

## What did not work

- Ajouter seulement `naver maps` à la liste des titres génériques corrige le
  payload multiligne, mais pas la forme mono-ligne où le préfixe, le nom et
  l’adresse partagent la même chaîne.
- Découper au premier espace aurait cassé les nombreux noms de lieux composés.
- Dépendre d’une recherche Apple Maps aurait ignoré les coordonnées et le titre
  déjà présents dans la redirection Naver.

## Validation

- La redirection réelle `https://naver.me/xB7Oc7MR` répond avec
  `title=녹녹`, `lat=37.5637823` et `lng=126.9220025`.
- Le build Debug complet du scheme `wander` pour simulateur iOS réussit le
  4 septembre 2026, y compris la compilation et l’intégration de
  `WanderShareExtension`.
- La revue statique confirme que le payload mono-ligne devient le nom `녹녹`
  suivi de l’adresse `서울 마포구 연남동 249-11`, et que la variante multiligne
  suit le même chemin.
- Le build a été installé sur l’iPhone 17 Pro Simulator déjà démarré. Naver Map
  n’y étant pas disponible, le parcours inter-app réel reste à confirmer sur
  l’iPhone équipé de Naver.
- Deux avertissements de build préexistants restent hors périmètre : les
  `CFBundleVersion` des deux extensions diffèrent de celui de l’app conteneur.

## Reusable lesson and prevention

Quand un fournisseur partage à la fois du texte humain et une URL structurée,
ne pas choisir aveuglément la première ligne comme titre. Utiliser d’abord les
champs structurés limités au domaine de confiance concerné, puis s’en servir
comme ancre pour découper le texte. Conserver les replis génériques séparés afin
qu’un changement propre à un fournisseur ne modifie pas les autres imports.

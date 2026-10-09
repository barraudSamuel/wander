---
title: "Fusionner H3 avant de calculer le masque Mapbox"
date: 2026-10-09
category: performance
module: "Carte et brouillard"
problem_type: performance_issue
component: frontend
symptoms:
  - "Un calcul synthétique de brouillard reste actif plus de deux minutes dans CoreGraphics."
root_cause: wrong_api
resolution_type: code_fix
severity: high
tags: [mapbox, h3, fog, coregraphics, performance]
related_plan: "../plans/2026-10-09-remplacer-mapkit-par-mapbox.md"
---

# Fusionner H3 avant de calculer le masque Mapbox

## Problème

Pendant la migration Mapbox non encore livrée, les tests portant sur quelques
cellules passaient, mais une sonde de charge de 1 027, 10 267 puis 50 311 cellules
contiguës restait active après plus de deux minutes. Un échantillonnage du processus
la situait dans la soustraction de chemins CoreGraphics. La sortie tamponnée de
cette première sonde ne permet pas d’attribuer ce délai à un des trois volumes.

## Cause et approche écartée

Le premier masque donnait à CoreGraphics toutes les arêtes de chaque hexagone,
y compris les arêtes partagées. Déplacer ce travail hors du thread principal ne
réduit pas son coût. Annuler une tâche Swift n’interrompt pas une opération C
native déjà commencée.

Le masque représente le monde moins les zones explorées. Des trous GeoJSON
indépendants pour chaque cellule ne conviennent pas non plus lorsque leurs
frontières se touchent ou se chevauchent.

## Correction

Dans `wander/MapboxFogGeometry.swift`, fusionner d’abord les cellules avec
`cellsToLinkedMultiPolygon`, fourni par le module C de H3 déjà présent.
Grouper par résolution et dédupliquer les valeurs numériques avant cet appel,
car H3 n’accepte ni résolutions mélangées ni doublons dans un même ensemble.
Conserver les contours intérieurs afin qu’une île inexplorée reste masquée.

Projeter ensuite ces contours en Mercator, dupliquer ceux qui traversent
l’antiméridien, puis soustraire le tout au rectangle mondial avec CoreGraphics.
Le rendu Mapbox reçoit un nombre de sommets proportionnel aux contours restants.

La libération C doit suivre le succès de l’appel. Dans la version locale de H3,
`Vendor/H3Swift/Sources/Ch3/algos.c` libère déjà la structure quand la normalisation
échoue. Un `defer` installé avant le contrôle du code de retour pourrait alors
la libérer une seconde fois.

```swift
var polygon = LinkedGeoPolygon()
guard cellsToLinkedMultiPolygon(rawCells, Int32(rawCells.count), &polygon) == 0 else {
    // Traiter l’échec sans détruire une seconde fois la sortie.
    return fallbackRings
}
defer { destroyLinkedMultiPolygon(&polygon) }
```

Le renderer sérialise les calculs et vérifie l’annulation avant de commencer les
opérations natives. Il rejette les résultats devenus obsolètes.

## Preuves et limites

Une sonde Swift Debug sur ce Mac, compilant le fichier réel de géométrie, mesure
après fusion H3 environ 0,005 seconde pour 1 027 cellules, 0,040 seconde pour
10 267 cellules et 0,197 seconde pour 50 311 cellules. Le dernier résultat contient
1 560 points. Ces mesures portent sur des ensembles contigus synthétiques, sans
rendu GPU ; elles ne prédisent pas les performances d’un iPhone ni d’un ensemble
très dispersé.

Les dix tests de `wanderTests/MapboxFogGeometryTests.swift` passent avec le même
fichier de production dans un package temporaire macOS. Ils couvrent notamment
les cellules adjacentes, l’île inexplorée, le remplacement d’exploration,
les cellules H3 à l’antiméridien et une zone contiguë de 1 027 cellules.
Le build iOS réussit et le masque a été inspecté sur les vraies tuiles du
simulateur. La validation finale compte 113 tests natifs réussis et 26 scénarios
UI distincts réussis au fil des passes ciblées. Le plan de migration donne
les résultats exacts et les limites.

## Mise à jour du renderer pendant le traitement natif

Les tests iOS ont révélé un second piège dans l’envoi du masque. Mapbox peut
exposer `isStyleLoaded == false` pendant qu’il traite les données d’une source
GeoJSON déjà créée. Un guard portant seulement sur ce booléen peut abandonner
le dernier snapshot sans nouvel événement de chargement du style. Le masque
mondial initial reste alors visible sur des cellules explorées.

`MapboxFogRenderer.install()` autorise désormais la mise à jour lorsque la
source existe déjà, même pendant ce traitement. La création initiale attend
toujours que le style soit chargé :

```swift
let sourceExists = map.sourceExists(withId: Self.sourceID)
guard sourceExists || map.isStyleLoaded else { return }
```

Deux cas échouent sur vingt exécutions dans
`/tmp/wander-mapbox-fog-race.log`. Après correction, vingt tests passent en
4,25 secondes dans `/tmp/wander-mapbox-fog-fixed.log`. Ils interrogent la
couche rendue avec `queryRenderedFeatures`. Lire `GeoJSONSource.data` ne
restitue pas le snapshot envoyé par la mise à jour native.

## Prévention

Vérifier le volume et la topologie avant de déplacer un calcul de géométrie en
arrière-plan. Garder un cas contigu de plus de mille cellules et un cas avec trou
dans les tests. Lors d’un changement de H3, relire le contrat de libération en cas
d’erreur avant de généraliser un `defer` autour de son API C.

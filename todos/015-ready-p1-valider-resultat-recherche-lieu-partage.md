---
id: "015"
title: "Refuser les résultats de lieu partagé non fiables"
status: ready
priority: P1
source: review
created: 2026-08-18
tags: [todo, share-extension, mapkit, events, correctness]
---

# Refuser les résultats de lieu partagé non fiables

## Finding

Quand aucune coordonnée n’est fournie par le partage ou ses redirections, le
résolveur accepte actuellement le premier résultat global de `MKLocalSearch`
sans région, score de correspondance ni validation contre le nom et l’adresse
partagés. Comme l’extension accepte aussi tout texte brut, une entrée ambiguë
peut donc produire un événement à un homonyme ou à un établissement arbitraire.

Cela contredit le contrat du sprint qui exige de refuser une coordonnée non
fiable plutôt que d’inventer un point.

## Evidence

- `WanderShareExtension/Info.plist` active l’extension pour tout texte partagé.
- `wander/SharedPlaceImport.swift:159-170` lance une recherche sans région et
  accepte inconditionnellement `response.mapItems.first`.
- Aucun test automatisé ne couvre les noms homonymes, les textes génériques ou
  les résultats éloignés.

## Acceptance criteria

- [ ] Un partage avec coordonnées explicites continue d’utiliser ces
      coordonnées sans recherche MapKit.
- [ ] Un fallback MapKit n’est accepté qu’avec des critères documentés de
      correspondance du nom, de l’adresse et de la région.
- [ ] Une entrée ambiguë comme un nom générique échoue explicitement et ne peut
      pas être publiée.
- [ ] Des tests couvrent un résultat exact, un homonyme et une absence de
      résultat fiable.

## Resolution notes

À corriger avant de considérer la résolution multi-source fiable en production.

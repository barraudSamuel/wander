---
title: "Rendre les erreurs de recherche MapKit compréhensibles"
status: completed
date: 2026-08-11
completed_at: 2026-08-11T16:21:53+09:00
tags: [plan, mapkit, error-handling]
---

# Rendre les erreurs de recherche MapKit compréhensibles

## Outcome

La recherche de lieu ne montre plus de code technique `MKErrorDomain`. Elle
explique clairement une absence de résultat, une limitation temporaire, une
indisponibilité du service ou une perte de réseau.

## Scope

- Mapper `MKError.Code.placemarkNotFound` vers un état sans résultat utile.
- Fournir des messages français pour les erreurs MapKit et réseau courantes.
- Conserver la recherche strictement limitée à la région visible.

## Affected files

- `wander/OutingPlanComposerView.swift`.

## Checklist

- [x] Ajouter le mapping des erreurs de recherche.
- [x] Préserver l'annulation et l'identification des requêtes.
- [x] Vérifier le build Debug sans nouvel avertissement.
- [x] Relire le diff et consigner la validation.

## Risks

- Une absence de résultat ne doit pas être présentée comme une panne.
- Les erreurs inconnues doivent rester utiles sans exposer de code technique.

## Validation

- `xcodebuild -quiet -project wander.xcodeproj -scheme wander -configuration Debug -destination 'generic/platform=iOS Simulator' build` : réussi.
- `git diff --check -- wander/OutingPlanComposerView.swift docs/plans/2026-08-11-erreurs-recherche-mapkit.md` : réussi.
- Review ciblée du chemin `MKLocalSearch` : aucune anomalie relevée ; l'annulation, l'identifiant de requête et la région obligatoire restent inchangés.

## Acceptance criteria

- [x] `MKError.Code.placemarkNotFound` n'affiche plus de code technique.
- [x] Les erreurs de limitation, de service et de réseau ont un message français utile.
- [x] Les recherches restent limitées à la région visible.

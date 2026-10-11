---
id: "077"
title: "Clarifier la source du favori Naver"
status: done
priority: P2
source: review
created: 2026-10-10
tags: [todo, naver]
---

# Clarifier la source du favori Naver

## Finding

Le dédoublonnage par lieu remplace le nom de la liste source lors d'un import
depuis une autre liste. Le libellé « Liste » pouvait laisser penser que Wander
conservait toutes les appartenances aux listes Naver.

## Resolution notes

Le périmètre approuvé importe des adresses et met les lieux existants à jour.
Le champ décrit la dernière source d'import ; il ne modélise pas une collection
de listes. La fiche affiche maintenant « Dernière liste importée ». Aucun
changement de modèle ni gestion supplémentaire de collections n'a été ajouté.

## Acceptance criteria

- [x] Libellé explicite dans `wander/SavedPlaceDetailView.swift`.
- [x] `SavedPlaceTests.testReimportUpdatesWithoutDuplicatesAndSeparatesAccounts`
  vérifie deux noms de liste pour la même source, un seul lieu par compte et
  conservation du dernier nom. Test réussi lors de la seconde passe.
- [x] Comportement décrit dans la documentation technique et UX Obsidian.

Plan : `docs/plans/2026-10-10-import-favoris-naver.md`.

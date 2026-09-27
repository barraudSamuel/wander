---
status: done
priority: p3
date: 2026-09-26
---

# Accorder le compteur accessible au singulier

La revue de qualité du pied de carte compact a repéré la formulation « 1 participants » dans `MapEventsPanelView.swift`.

Correction : conserver « 1 participant » pour une personne et le pluriel pour plusieurs, suivi des noms. La compilation app et tests réussit avec `build-for-testing` ; aucun test d'accessibilité exécuté.

Plan : [Actions compactes des événements](../docs/plans/2026-09-26-actions-compactes-evenements.md).

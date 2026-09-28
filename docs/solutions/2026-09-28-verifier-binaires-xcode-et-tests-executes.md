---
title: "Vérifier les binaires Xcode et les tests réellement exécutés"
date: 2026-09-28
category: ios-testing
module: "Validation iOS de Wander"
problem_type: workflow_issue
component: development_workflow
severity: medium
applies_when:
  - "Une compilation incrémentale réussit mais le simulateur montre encore une ancienne interface"
  - "Des méthodes de test sont renommées et sélectionnées avec -only-testing"
tags: [solution, xcode, xctest, build-cache, validation]
related_plan: "../plans/2026-09-28-supprimer-navigation-centrer-evenements.md"
---

# Vérifier les binaires Xcode et les tests réellement exécutés

## Context

Pendant le retrait de la barre Explorer, `build-for-testing` réussissait mais
conservait le binaire UI de 08:58. Onze méthodes étaient demandées ; seules cinq
anciennes méthodes existantes s'exécutaient. Une sélection contenant seulement
une nouvelle méthode se terminait avec `TEST SUCCEEDED` et zéro test exécuté.

Les objets Swift de l'app avaient été recompilés à 10:00, mais ses exécutables
restaient eux aussi datés de 08:58. Après reconstruction des tests, les nouvelles
assertions trouvaient donc encore Explorer dans l'ancienne app.
L'origine interne de cette incohérence du cache Xcode n'a pas été déterminée.

## Guidance

Vérifier le nombre et les noms des tests exécutés, pas seulement le code de
sortie ou la bannière de succès. En cas d'interface ancienne, vérifier aussi les
étapes `SwiftCompile` et `Ld`, puis les dates des produits effectivement installés.

Ici, actualiser les dates des sources n'a pas suffi. Déplacer uniquement les
objets générés de la cible UI vers une sauvegarde temporaire, puis reconstruire,
a produit les nouvelles méthodes. Les deux exécutables générés de l'app ont
ensuite été mis de côté pour forcer leur liaison. La nouvelle app installée a
affiché le calendrier centré sans barre Explorer.

Ces manipulations concernent les produits de compilation, jamais les sources,
les dépendances téléchargées ni les données du simulateur. Utiliser les chemins
réels de la compilation courante et conserver les sauvegardes tant que la
reconstruction n'est pas confirmée. Ne pas appliquer ce nettoyage à chaque build.

## Why This Matters

Un filtre de test absent de l'ancien binaire peut donner une exécution verte
sans exercer le changement. Recompiler des fichiers Swift ne prouve pas non
plus que l'exécutable final a été relié et installé.

## When to Apply

Appliquer ce diagnostic lorsque les noms exécutés ou l'interface observée ne
correspondent pas aux sources, particulièrement après un renommage de tests.

## Examples

Les journaux de cette session séparent les étapes observées :

- `/tmp/wander-centered-events-current-test.log` : sélection d'une nouvelle
  méthode, zéro test exécuté malgré le succès.
- `/tmp/wander-centered-events-rebuilt-tests.log` : compilation effective des
  deux fichiers de tests UI, nouveau binaire à 10:08.
- `/tmp/wander-centered-events-linked-build.log` : liaison effective de l'app,
  nouveaux exécutables à 10:12.
- `/tmp/wander-centered-events-current.png` : capture inspectée après installation,
  montrant l'absence de barre et le calendrier centré.

## Related

- [Plan et résultats de validation](../plans/2026-09-28-supprimer-navigation-centrer-evenements.md).

---
title: Compiler H3Swift sans unsafe build flags dans Xcode
date: 2026-10-07
category: ios-build
module: Dépendances iOS de Wander
problem_type: build_error
component: development_workflow
severity: high
symptoms:
  - "Xcode refuse H3-product avant la compilation de Wander"
root_cause: config_error
resolution_type: config_change
framework_version: Xcode 27.0 et H3Swift 1.0.1
tags: [solution, xcode, swiftpm, h3, build]
related_plan: ../plans/2026-10-07-corriger-dependance-h3.md
---

# Compiler H3Swift sans unsafe build flags dans Xcode

## Problème

Le projet ne pouvait plus compiler, ce qui empêchait aussi de valider la
correction des permissions de localisation dans l'application complète.
La correction décrite ici est validée localement, non commitée à cette date.

## Symptômes

Xcode échouait avec le message suivant :

```text
The package product 'H3-product' cannot be used as a dependency of this target because it uses unsafe build flags.
```

## Approches écartées

Les deux versions publiées vérifiées, 1.0.0 et 1.0.1, contiennent le même
réglage. Changer seulement la version ne le retire pas. L'exception de SwiftPM
pour certaines dépendances par révision ne prouve pas qu'une cible Xcode
acceptera ce réglage ; cet épinglage n'a pas été testé comme correctif.
Modifier seulement le checkout de DerivedData laisserait les autres machines
avec le défaut et serait perdu lors d'une nouvelle résolution.

## Solution

Le projet référence `Vendor/H3Swift` comme `XCLocalSwiftPackageReference`.
Les 46 fichiers de `Vendor/H3Swift/Sources/` sont identiques à ceux du commit upstream
[H3Swift 1.0.1](https://github.com/libardoram/H3Swift/tree/f7c2e092dfd8b070458ffc05f599836fc6b09d18).
Le paquet conserve le produit `H3`, les cibles `H3` et `Ch3`, leurs chemins
d'en-têtes et les licences MIT et Apache 2.0 ainsi que la notice Uber.

Le manifeste local retire `.unsafeFlags(["-w"])`. Le retrait révèle un conflit
de macros entre les fallbacks H3 et le module Darwin. Deux réglages standard
dans `Vendor/H3Swift/Package.swift` résolvent ce conflit :

```swift
.define("M_PI", to: "3.14159265358979323846264338327950288"),
.define("M_PI_2", to: "1.57079632679489661923132169163975144"),
```

Les valeurs binary64 sont identiques aux littéraux H3 :
`0x1.921fb54442d18p+1` et `0x1.921fb54442d18p+0`. Les sources et les valeurs
utilisées par le moteur ne changent pas. Aucun avertissement n'est masqué.

## Pourquoi cela fonctionne

La cible C `Ch3` déclarait une option arbitraire pour masquer les avertissements.
Le produit `H3` dépend de cette cible, ce qui suffisait à déclencher le refus
de Xcode. Le paquet local supprime ce réglage à sa source.

H3 définit ses constantes seulement lorsqu'elles n'existent pas encore.
Les définitions du manifeste précèdent ces gardes et utilisent les mêmes
littéraux que le SDK Darwin, évitant les deux définitions concurrentes.

La compilation initiale échoue avec le message H3, puis la compilation Debug
réussit. Après correction des constantes, les huit tests ciblés sont exécutés
et réussis, dont sept tests de localisation dans le projet complet et un test
UI de carte. Les captures montrent la carte et la liste d'événements ouvertes.
La compilation Release pour appareil réussit également sans signature.
Les commandes et journaux sont conservés dans le plan lié.

## Prévention

Lors d'une mise à jour H3, vérifier la provenance, les licences, les sources
copiées et le manifeste avant de compiler les cibles simulateur et appareil.
Un `swift build` isolé ne remplace pas la compilation de la cible Xcode qui
consomme le produit. Les tests de permissions restent nécessaires, mais leurs
succès ne valident pas les dialogues de localisation sur un téléphone réel.

## Références

- [Plan H3 et preuves](../plans/2026-10-07-corriger-dependance-h3.md).
- [Validation des binaires et du nombre de tests](2026-09-28-verifier-binaires-xcode-et-tests-executes.md).
- [Validation restante des permissions](../../todos/071-ready-p2-valider-autorisation-arriere-plan.md).

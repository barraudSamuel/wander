---
title: "Accepter les alias IANA sans masquer le fuseau réel dans les tests"
module: "Événements"
date: "2026-10-24"
problem_type: logic_error
component: data_model
severity: medium
symptoms:
  - "La publication échoue avec Le fuseau horaire est invalide pour Asia/Kolkata"
  - "Les tests UI réussissent lorsque leur processus force Asia/Seoul"
root_cause: wrong_api
resolution_type: code_fix
framework_version: "Foundation, iOS 27.0, iPhone 18 Pro Simulator"
tags: [events, timezone, foundation, iana, testing]
related_plan: "../plans/2026-10-24-corriger-alias-fuseaux-horaires.md"
---

# Accepter les alias IANA sans masquer le fuseau réel dans les tests

## Problème

Le fuseau fourni par le système pouvait être refusé par la validation métier
avant toute écriture Firebase. Le défaut concernait aussi les événements relus,
car les deux chemins appellent le même helper dans `wander/OutingPlan.swift`.

## Symptômes

Sur le simulateur de reproduction, Foundation retourne `Asia/Kolkata` comme
fuseau courant et sait l'interpréter, mais sa liste `knownTimeZoneIdentifiers`
contient `Asia/Calcutta`. L'app affichait « Le fuseau horaire est invalide. ».

## Contournement insuffisant

Les tests Naver forçaient auparavant `TZ=Asia/Seoul`. Cela permettait de tester
les pins tout en masquant la publication défaillante avec le fuseau système.
Ce contournement a été retiré de `wanderUITests/NaverImportUITests.swift`.

## Solution

Le helper conserve les identifiants déjà acceptés et ajoute les alias avec `/`
reconnus par `TimeZone(identifier:)`, plus l'alias standard `UTC`. L'identifiant
et la date du brouillon restent inchangés. Les nouveaux formats de décalage
fixe comme `GMT+0530` restent exclus : Foundation et Intl n'acceptent pas tous
les mêmes formats. Aucun changement de règles Firestore ni migration.

## Pourquoi cela fonctionne

Une liste énumérée de noms n'est pas la liste exhaustive des alias reconnus.
Le test doit porter sur l'interprétation du nom, tout en conservant les limites
de format nécessaires aux autres consommateurs. Les notifications utilisent
`Intl.DateTimeFormat` et acceptent déjà les deux alias indiens.

## Prévention et preuves

Tester les alias explicitement au niveau métier, et conserver un parcours UI
avec le fuseau réel du système. Une substitution de fuseau destinée à isoler
un autre test ne prouve pas que le parcours fonctionne dans cet environnement.

Le journal rouge `/private/tmp/wander-timezone-red.log` montre le rejet de
Kolkata avant correction. Le bundle vert
`/private/tmp/wander-timezone-green.xcresult` contient 4 tests Swift et 2 parcours
UI réussis, avec `current=Asia/Kolkata` et `TZ=unset` sur le simulateur.
Les tests serveur vérifient 15:30 pour les deux alias à partir de 10:00 UTC.
Ils ne prouvent ni la livraison réelle des notifications ni la concordance
exhaustive des bases de fuseaux de toutes les versions iOS et Node.

Le correctif est local et non committé à la date de cette note.

## Références

- [Plan et validation détaillée](../plans/2026-10-24-corriger-alias-fuseaux-horaires.md)
- [Constat 082 résolu](../../todos/082-pending-p2-accepter-alias-fuseaux-iana.md)

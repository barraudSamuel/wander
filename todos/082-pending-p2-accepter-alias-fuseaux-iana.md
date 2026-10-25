---
id: "082"
title: "Accepter les alias IANA valides pour publier un événement"
status: completed
priority: P2
source: simulator-validation
created: 2026-10-24
completed_at: 2026-10-24
tags: [todo, events, timezone, validation]
---

# Accepter les alias IANA valides pour publier un événement

## Constat

La publication échoue avec « Le fuseau horaire est invalide. » lorsque le système utilise `Asia/Kolkata`. `OutingPlanComposerView` transmet `TimeZone.current.identifier`, mais `OutingPlan.isValidTimeZoneIdentifier` exige la présence dans `TimeZone.knownTimeZoneIdentifiers`. Foundation sait interpréter cet identifiant ; sa liste énumère ici `Asia/Calcutta` à sa place.

Ce défaut précède le sprint des pins. Il concerne la validation des événements et nécessite une correction séparée, cohérente avec les règles Firestore. Le sprint ne modifie pas cette validation.

## Preuves

- `wander/OutingPlanComposerView.swift`, construction du brouillon avec le fuseau courant.
- `wander/OutingPlan.swift`, `isValidTimeZoneIdentifier`.
- Simulateur iPhone 18 Pro, iOS 27.0, `CD1E7A76-F65E-495D-A525-F328746F152F`. Diagnostic Foundation isolé : `Asia/Kolkata` est interprétable mais absent de la liste ; `Asia/Seoul` est interprétable et présent.
- `/private/tmp/wander-pins-ui-1.xcresult` : échecs des deux parcours de publication dans `NaverImportUITests`, préremplissage correct puis erreur de fuseau.
- Le scénario synthétique Naver fixe désormais `TZ=Asia/Seoul` dans l'environnement de lancement du test. Il ne change ni les réglages du simulateur ni la validation métier.

## Critères de résolution

- [x] Définir et approuver le traitement des alias IANA pour le modèle et les règles serveur.
- [x] Vérifier `Asia/Kolkata`, `Asia/Calcutta`, `Asia/Seoul` et le rejet d'un identifiant invalide.
- [x] Publier depuis un système configuré avec l'alias concerné, sans substitution de fuseau par le test.

## Résolution du 24 octobre 2026

Le helper conserve les identifiants déjà acceptés et reconnaît aussi les alias
avec `/` interprétables par Foundation, ainsi que `UTC`. Il reste partagé par
la validation du brouillon et la lecture Firestore. Les dates et identifiants
ne sont pas réécrits. `GMT+0530` reste rejeté.

Le contournement `TZ=Asia/Seoul` a été retiré des tests Naver. La sonde du
simulateur retourne `current=Asia/Kolkata known=false TZ=unset`.
Quatre tests Swift et les deux parcours UI de publication passent, soit 6/6,
dans `/private/tmp/wander-timezone-green.xcresult`. Les 49 tests serveur actifs
passent, dont les deux alias indiens ; cinq tests d'intégration restent ignorés.
Les règles Firestore n'imposent pas de liste de fuseaux et ne nécessitent aucun
changement. Aucun déploiement n'a été effectué.

La revue ciblée ne retient aucun constat. La lecture de DocumentSnapshot est
vérifiée par inspection du helper commun, sans test direct Firebase. Les tests
UI utilisent le scénario local et les tests serveur Node 24.19.0, alors que
la production déclare Node 22 ; aucune livraison réelle de notification testée.

Plan et preuves : [correctif des alias](../docs/plans/2026-10-24-corriger-alias-fuseaux-horaires.md).

Plan de découverte : [états et animations des pins](../docs/plans/2026-10-24-pins-adresses-etats-animations.md).

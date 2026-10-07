---
id: "071"
title: "Valider l’autorisation arrière-plan dans l’application complète"
status: ready
priority: P2
source: review
created: 2026-10-07
tags: [todo, location, validation]
---

# Valider l’autorisation arrière-plan

## Constat

La correction affiche l’autorisation réelle, propose les Réglages lorsque
Always manque, poursuit la première demande explicitement engagée et relit
le statut au retour au premier plan. La revue ciblée ne relève aucun défaut
concret introduit. La compilation complète et la validation de l’interface
restent bloquées avant compilation du code modifié par H3-product.

## Preuves

- Plan : [autorisation arrière-plan](../docs/plans/2026-10-07-autorisation-localisation-arriere-plan.md).
- Build complet : `/private/tmp/wander-location-permissions-tests.log` et
  `/private/tmp/wander-location-permissions-tests.xcresult`.
- Erreur : `The package product 'H3-product' cannot be used as a dependency of
  this target because it uses unsafe build flags.`
- La référence H3Swift n’a pas changé dans cette intervention ; la copie
  résolue de son manifeste contient `.unsafeFlags(["-w"])`.
- Les sept tests de `wanderTests/LocationTrackerTests.swift` passent sur
  l’iPhone 17 Pro existant, UUID `C0DADF07-7E14-4D5E-AE4B-B17844A9C454`,
  dans un paquet iOS temporaire utilisant la structure de production extraite
  sans modification. Preuve finale :
  `/private/tmp/wander-location-isolated-ios-final.xcresult` et `.log`.
- La syntaxe Swift des quatre fichiers de code/test modifiés passe.

## Limites

Ces tests valident `BackgroundAuthorizationRequest`, pas l’intégration de
`CLLocationManager`, les bindings SwiftUI ni le rendu. Ils ne prouvent pas
qu’un dialogue apparaît, ni que les Réglages iPhone ont changé. Le refus
« Conserver uniquement lorsque l’app est active » peut ne produire aucun
callback ; le message dépend de l’état réel, pas de ce callback.

## Critères de résolution

- [ ] Résoudre le blocage de dépendance dans un plan distinct approuvé.
- [ ] Compiler l’application et exécuter ses tests de permission intégrés.
- [ ] Vérifier la feuille Réglages : WhenInUse avec préférence active montre
  l’autorisation manquante et « Ouvrir Réglages » ; Always affiche « Toujours ».
- [ ] Vérifier le retour des Réglages dans les deux sens, y compris suivi suspendu.
- [ ] Vérifier première demande, refus, Allow Once, désactivation puis relancement.
- [ ] Confirmer sur appareil réel le surclassement Always et l’absence de
  nouvelle sollicitation au simple relancement.

## Notes de revue

Revue locale ciblée du parcours, du cycle de vie, du partage et de l’interface,
avec deux lecteurs distincts. Pas de revue cross-model ni de validation UI
complète annoncée. Aucun autre simulateur démarré, aucun Git mutateur exécuté.

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
concret introduit. La correction H3 du 7 octobre débloque la compilation
complète et l'exécution des sept tests dans le projet Wander. La validation
de la feuille des permissions et des dialogues système reste à effectuer.

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
- Après le [plan H3 approuvé](../docs/plans/2026-10-07-corriger-dependance-h3.md),
  compilation Debug réussie et sept tests de `LocationTrackerTests` réussis
  dans l'application complète. Un test UI de carte passe aussi, soit huit
  tests exécutés, zéro échec et zéro test ignoré. Résultat :
  `/private/tmp/wander-h3-fix/final-tests.xcresult` et `final-tests.log`.
  Cette preuve remplace la limitation de compilation des premières vérifications.

## Limites

Même exécutés dans l'application complète, ces tests valident
`BackgroundAuthorizationRequest`, pas l’intégration de `CLLocationManager`,
les bindings SwiftUI ni le rendu de la feuille des permissions. Ils ne prouvent pas
qu’un dialogue apparaît, ni que les Réglages iPhone ont changé. Le refus
« Conserver uniquement lorsque l’app est active » peut ne produire aucun
callback ; le message dépend de l’état réel, pas de ce callback.

## Critères de résolution

- [x] Résoudre le blocage de dépendance dans un plan distinct approuvé.
- [x] Compiler l’application et exécuter ses tests de permission intégrés.
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

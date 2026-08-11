---
id: "008"
title: "Valider les sorties sociales avec deux comptes"
status: blocked
priority: P1
source: review
created: 2026-08-11
tags: [todo, outings, mapkit, firebase, validation]
---

# Valider les sorties sociales avec deux comptes

## Finding

Le Sprint 3 compile et sa revue statique confirme les frontières attendues,
mais ses critères d'acceptation exigent un scénario interactif avec deux
comptes Apple amis. Le simulateur disponible s'arrête sur la connexion Apple ;
Codex ne peut pas saisir le compte du propriétaire ni accepter cette connexion.

La suite de règles Firestore n'a pas pu être relancée dans cette session parce
que Firebase CLI 15 exige un JDK 21 et que la machine expose uniquement le JDK
17. Les règles n'ont pas été modifiées par le Sprint 3 et leurs 18 tests avaient
réussi au Sprint 1, mais une nouvelle exécution reste requise pour fermer la
validation.

## Evidence

- Le build Debug pour le simulateur iOS réussit sans avertissement Swift dans
  les fichiers du Sprint 3.
- `git diff --check` réussit.
- Le simulateur iPhone 17 Pro ouvre Wander sur « Continue with Apple ».
- `npm run test:rules` s'arrête avant les tests avec l'exigence JDK 21.
- `firestore.rules` et `firebase-tests/` ne sont pas modifiés dans ce sprint.

## Acceptance criteria

- [ ] Relancer les 18 tests de règles Firestore avec un JDK 21 ou supérieur.
- [ ] Connecter deux comptes amis et publier une sortie depuis chacun.
- [ ] Vérifier que les deux sorties sont visibles et distinctes des positions
      réelles, en modes clair et sombre.
- [ ] Vérifier le callout, l'heure locale, l'adresse facultative, VoiceOver et
      Dynamic Type.
- [ ] Modifier puis annuler une sortie et confirmer qu'aucun marqueur en double
      ne reste affiché.
- [ ] Révoquer l'amitié et confirmer le retrait immédiat du marqueur.
- [ ] Vérifier l'expiration locale sans nouvelle écriture Firestore.

## Resolution notes

Le code est implémenté et compilé. Le Sprint 3 doit rester `in_progress` jusqu'à
la validation interactive et la nouvelle exécution des tests de règles.

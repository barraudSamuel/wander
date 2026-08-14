---
id: "008"
title: "Valider les sorties sociales avec deux comptes"
status: done
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

- [x] Relancer les 18 tests de règles Firestore avec un JDK 21 ou supérieur.
- [x] Connecter deux comptes amis et publier une sortie depuis chacun.
- [x] Vérifier que les deux sorties sont visibles et distinctes des positions
      réelles, en modes clair et sombre.
- [x] Vérifier le callout, l'heure locale, l'adresse facultative, VoiceOver et
      Dynamic Type.
- [x] Modifier puis annuler une sortie et confirmer qu'aucun marqueur en double
      ne reste affiché.
- [x] Révoquer l'amitié et confirmer le retrait immédiat du marqueur.
- [x] Vérifier l'expiration locale sans nouvelle écriture Firestore.

## Resolution notes

Résolu le 2026-08-12 :

- le propriétaire a confirmé la réussite du parcours interactif complet à deux
  comptes décrit dans les critères ci-dessus ;
- Java 21.0.12 a été installé via Homebrew ;
- `npm run test:rules` a réussi avec 18 tests sur 18, aucun échec ;
- le Sprint 3 a été marqué `completed`.

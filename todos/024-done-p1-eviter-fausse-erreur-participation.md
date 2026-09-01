---
id: "024"
title: "Éviter la fausse erreur après une participation enregistrée"
status: done
priority: P1
source: production-validation
created: 2026-09-01
resolved: 2026-09-01
tags: [todo, ios, firestore, participation, ux, regression]
---

# Éviter la fausse erreur après une participation enregistrée

## Finding

Après correction et déploiement des règles, la réponse à une sortie était bien
enregistrée mais l'application affichait encore « Participation impossible ».
Le service transformait une erreur de confirmation postérieure au commit en
échec de l'action déjà réussie.

## Evidence

- `batch.commit()` précédait la relecture serveur et le décodage strict.
- Le choix restait visible, ce qui confirmait l'écriture.
- Le message affiché était le fallback générique de `ContentView`, donc l'erreur
  n'était pas une erreur métier explicite du service.
- Le batch et la relecture serveur réussissaient ensemble dans l'émulateur avec
  les règles actuelles.

## Acceptance criteria

- [x] Une erreur secondaire après un commit réussi ne déclenche plus la popup
      affirmant que la modification a échoué.
- [x] Une confirmation valide conserve la mise à jour locale immédiate.
- [x] Les listeners restent responsables de la validation et de la
      réconciliation finales.
- [x] Une erreur réelle du commit continue à remonter au client.
- [x] Le build Debug générique réussit.

## Resolution notes

Résolu localement le 2026-09-01 par
`docs/plans/2026-09-01-eviter-fausse-erreur-participation.md` :

- seule la phase antérieure ou égale à `batch.commit()` peut désormais faire
  échouer `setResponse` ;
- la confirmation immédiate applique encore un document valide, mais retourne
  silencieusement en cas d'erreur secondaire ;
- les listeners personnels conservent leur validation stricte et deviennent le
  chemin de repli systématique ;
- le build Debug générique réussit avec uniquement les avertissements de
  versions d'extensions déjà présents.

Aucune règle Firebase et aucune donnée distante n'ont été modifiées. Une
nouvelle version de l'application doit être reconstruite et lancée sur
l'appareil pour valider la disparition effective de la popup.

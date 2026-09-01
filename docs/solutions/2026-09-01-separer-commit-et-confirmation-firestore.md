---
title: "Séparer le commit Firestore de sa confirmation client"
date: 2026-09-01
category: ios
tags: [solution, swift, firestore, ux, error-handling]
related_plan: "../plans/2026-09-01-eviter-fausse-erreur-participation.md"
---

# Séparer le commit Firestore de sa confirmation client

## Problem

Une réponse à une sortie était correctement enregistrée, puis l'application
affichait « Participation impossible ». Le service traitait le commit et sa
relecture de confirmation comme une seule opération lançante. Une erreur de
réseau ou de décodage après le commit transformait donc un succès distant en
échec UX.

## Root cause

`batch.commit()` était suivi d'un `getDocument(source: .server)` et d'un
décodage strict. Toutes leurs erreurs remontaient au même `catch` que l'échec
du commit. Le message ne pouvait pas distinguer une mutation refusée d'une
confirmation secondaire indisponible.

## Solution

La frontière d'échec de l'action s'arrête désormais au commit :

- les validations de session, de profil et d'état restent lançantes avant
  l'écriture ;
- `batch.commit()` reste lançant et continue d'afficher une erreur réelle ;
- la relecture post-commit est déplacée dans une méthode non lançante ;
- si le document confirmé est valide, l'état local est actualisé immédiatement ;
- si cette confirmation échoue, le service retourne normalement et laisse les
  listeners `attendees` et `declines` valider puis réconcilier l'état.

Les handlers des listeners conservent leurs contrôles complets de propriétaire,
participant, événement, publication, profil et timestamp. Aucun document
invalide n'est injecté dans l'état publié.

## Validation

- Le build Debug générique iOS réussit avec `CODE_SIGNING_ALLOWED=NO`.
- Aucun nouveau diagnostic de compilation n'est introduit ; seuls les deux
  avertissements préexistants de `CFBundleVersion` des extensions subsistent.
- `git diff --check` réussit.
- Les règles Firestore et les données distantes ne sont pas modifiées par ce
  correctif Swift.
- La validation finale de la disparition de la popup nécessite de reconstruire
  et relancer l'application sur l'appareil concerné.

## Reusable lesson

Une mutation réussie et sa confirmation locale sont deux phases distinctes.
Une erreur de confirmation ne doit jamais être présentée comme un échec de
mutation lorsque le backend a déjà validé le commit. Avec des listeners actifs,
la confirmation synchrone peut améliorer la réactivité, mais elle doit rester
opportuniste et non bloquante.


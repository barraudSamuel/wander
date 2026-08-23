---
id: "017"
title: "Gérer une publication confirmée dont la relecture échoue"
status: ready
priority: P2
source: review
created: 2026-08-18
tags: [todo, share-extension, firebase, events, reliability]
---

# Gérer une publication confirmée dont la relecture échoue

## Finding

Après la réussite de `setData`, le document a été accepté par Firestore, mais
une panne lors du `getDocument(source: .server)` suivant est remontée comme un
échec de publication. L’extension reste alors ouverte et indique une erreur
alors que l’événement existe déjà.

L’extension réutilise désormais le même `eventId` et le même `publicationId` :
un nouvel essai reste idempotent même si la catégorie a changé. Le problème
restant est l’état trompeur de l’interface entre l’écriture confirmée et la
relecture échouée.

## Evidence

- `wander/OutingPlanPublishing.swift:56-57` effectue l’écriture puis une seconde
  requête serveur indispensable au retour de la méthode.
- `WanderShareExtension/ShareComposerView.swift:215-227` traite toute erreur de
  cette méthode comme une publication échouée et réactive le formulaire.
- `wander/OutingPlanPublishing.swift:30-39` dérive l’identité de publication de
  l’`eventId` fourni par l’extension afin de rendre le rejeu stable.

## Acceptance criteria

- [ ] L’interface distingue une écriture non confirmée d’une écriture confirmée
      dont seule la relecture a échoué.
- [x] Un réessai après succès partiel reste idempotent, même si les contrôles du
      formulaire ont changé.
- [ ] L’utilisateur ne peut pas fermer en croyant qu’aucun événement n’existe
      alors que Firestore l’a déjà créé.
- [ ] Un test simule la réussite de l’écriture suivie de l’échec de relecture.

## Resolution notes

La correction restante doit préserver le publisher commun utilisé par
l’application et l’extension, tout en distinguant le succès de l’écriture de
celui de la relecture.

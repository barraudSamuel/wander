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

Le même `eventId` limite les doublons lors d’un nouvel essai, mais si
l’utilisateur change la catégorie avant de réessayer, les règles refusent la
mise à jour car la catégorie d’un événement existant est immuable.

## Evidence

- `wander/OutingPlanPublishing.swift:61-66` effectue l’écriture puis une seconde
  requête serveur indispensable au retour de la méthode.
- `WanderShareExtension/ShareComposerView.swift:215-227` traite toute erreur de
  cette méthode comme une publication échouée et réactive le formulaire.
- `firestore.rules:771-782` interdit de changer la catégorie lors d’une mise à
  jour.

## Acceptance criteria

- [ ] L’interface distingue une écriture non confirmée d’une écriture confirmée
      dont seule la relecture a échoué.
- [ ] Un réessai après succès partiel reste idempotent, même si les contrôles du
      formulaire ont changé.
- [ ] L’utilisateur ne peut pas fermer en croyant qu’aucun événement n’existe
      alors que Firestore l’a déjà créé.
- [ ] Un test simule la réussite de l’écriture suivie de l’échec de relecture.

## Resolution notes

La correction doit préserver le publisher commun utilisé par l’application et
l’extension.

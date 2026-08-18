---
id: "018"
title: "Normaliser les erreurs de l’extension de partage"
status: ready
priority: P2
source: review
created: 2026-08-18
tags: [todo, share-extension, ux, firebase, mapkit]
---

# Normaliser les erreurs de l’extension de partage

## Finding

Le compositeur affiche directement `error.localizedDescription` pour les
échecs de préparation et de publication. Les erreurs MapKit, URLSession et
Firebase qui ne sont pas déjà enveloppées exposent donc des messages système
techniques, parfois en anglais ou sous forme de domaine/code.

Le premier test appareil l’a déjà matérialisé avec
`MKErrorDomain erreur 4`, au lieu du message Wander prévu pour un lieu non
résolu.

## Evidence

- `WanderShareExtension/ShareComposerView.swift:193-197` affiche toute erreur de
  préparation sans traduction.
- `WanderShareExtension/ShareComposerView.swift:224-227` fait de même pour la
  publication.
- `wander/SharedPlaceImport.swift:334-345` relaie directement les erreurs
  `MKLocalSearch`.
- `WanderShareExtension/ShareExtensionFirebaseBootstrap.swift:29-33` relaie
  directement les erreurs Auth et Firestore.

## Acceptance criteria

- [ ] Hors-ligne, délai dépassé, lieu introuvable, session expirée, permission
      Firestore et erreur inconnue ont chacun un message français actionnable.
- [ ] Aucun domaine, code interne ou texte technique Firebase/MapKit n’est
      affiché à l’utilisateur.
- [ ] Les erreurs conservent une action cohérente : réessayer, ouvrir Wander ou
      fermer.
- [ ] Des tests couvrent la conversion des principales familles d’erreurs.

## Resolution notes

La normalisation doit rester sans log du contenu partagé ni des identifiants.

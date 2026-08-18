---
id: "016"
title: "Borner les téléchargements de redirection dans l’extension"
status: ready
priority: P2
source: review
created: 2026-08-18
tags: [todo, share-extension, networking, performance]
---

# Borner les téléchargements de redirection dans l’extension

## Finding

La résolution des redirections utilise `URLSession.data(for:)` avec une requête
`GET`. Pour une URL directe sans redirection, la réponse entière est donc
chargée en mémoire avant que le code conclue qu’il n’y a pas d’en-tête
`Location`. L’extension étant proposée pour toute URL web, une page ou un
fichier volumineux peut dépasser son budget mémoire et provoquer sa fermeture.

Chaque tentative crée aussi une session avec delegate sans l’invalider
explicitement à la fin du parcours.

## Evidence

- `wander/SharedPlaceImport.swift:181-212` crée une session par résolution et
  appelle `session.data(for:)` jusqu’à cinq fois.
- La taille de réponse n’est pas bornée et la session n’appelle ni
  `finishTasksAndInvalidate()` ni `invalidateAndCancel()`.

## Acceptance criteria

- [ ] Les redirections sont déterminées à partir des en-têtes sans conserver
      un corps de réponse arbitrairement volumineux.
- [ ] Un serveur qui ignore une requête légère ne peut pas faire croître la
      mémoire de l’extension sans limite définie.
- [ ] La session est invalidée sur succès, erreur et annulation.
- [ ] Un test couvre une URL sans redirection avec un corps volumineux simulé.

## Resolution notes

Conserver le support des redirections `naver.me` tout en respectant les limites
d’un processus d’extension iOS.

---
id: "013"
title: "Éviter la course entre profil et broadcast de participation"
status: ready
priority: P2
source: review
created: 2026-08-15
tags: [todo, notifications, profile, concurrency]
---

# Éviter la course entre profil et broadcast de participation

## Finding

Le trigger compare le pseudo et l'avatar figés dans la participation au profil
courant. Si le participant modifie légitimement son profil avant le traitement
asynchrone, le trigger abandonne silencieusement une arrivée pourtant valide.

## Evidence

- `functions/src/index.ts` exige l'égalité exacte entre l'instantané créé et le
  profil relu au moment du trigger.
- Les règles Firestore ont déjà validé cet instantané lors de sa création.

## Acceptance criteria

- [ ] Une modification de profil après l'inscription n'annule pas le broadcast.
- [ ] Le contenu visible reste issu d'une source validée et normalisée.
- [ ] Un test couvre la modification du profil entre création et traitement.

## Resolution notes

Finding reporté comme dette connue lors de la clôture demandée du Sprint 6 :
`docs/plans/2026-08-15-sorties-prevues-sprint-06-participation.md`.

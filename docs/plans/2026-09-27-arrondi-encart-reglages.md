---
title: "Rétablir l'arrondi d'origine de l'encart des réglages"
status: completed
date: 2026-09-27
completed_at: 2026-09-27T17:34:42+09:00
owner: Samuel
tags: [plan, profile, ux, settings]
---

# Rétablir l'arrondi d'origine de l'encart des réglages

## Outcome

Les deux courbes de l'encart de la roue des réglages utilisent le rayon d'origine de 16 pt.

## Scope

- Inclus : retour du coin inférieur droit à 16 pt, documentation UX.
- Exclus : coin supérieur, taille de l'encart, action de la roue, profil ami.
- Dépendance : `ProfileCardBackgroundShape` dans `FriendProfileSheet.swift`.

## Affected files

- `wander/FriendProfileSheet.swift` : supprimer le rayon inférieur distinct de 36 pt et réutiliser celui de 16 pt.
- Ce plan.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md` : précision du dessin de l'encart et actualisation de `updated`.

## Implementation

- [x] Restaurer le tracé d'origine à 16 pt pour les deux courbes.
- [x] Retirer la mention de l'arrondi supplémentaire dans la note UX et actualiser son frontmatter.
- [x] Consigner la validation omise à la demande de Samuel.

## Risks

- Le rendu après retour au tracé d'origine ne sera pas contrôlé, selon la consigne de Samuel.

## Validation and acceptance

- Le tracé utilise le même rayon de 16 pt pour les deux courbes.
- Aucun build, test ou contrôle du simulateur, selon la consigne explicite « verifie pas ».

## Review notes

- Plan présenté dans la conversation et approuvé explicitement par Samuel le 27 septembre 2026 : « je valide verifie pas ».
- Les compétences Compound Engineering citées par `AGENTS.md` ne sont pas disponibles ; appliquer le workflow manuellement pour les étapes autorisées.
- Samuel a ensuite demandé « met a 36 » ; le rayon du bas passe de 16 à 36 pt et celui du haut reste à 16 pt. La note `Documentation UX.md` a été actualisée.
- Aucune compilation, aucun test, aucune capture ou inspection du simulateur et aucune relecture du diff n'ont été effectués, conformément à la demande « verifie pas ».
- Le 27 septembre 2026, Samuel a demandé le retour au rayon d'origine de 16 pt après lecture du tracé historique, puis a approuvé explicitement ce plan par « je vlaide ».
- Le tracé reprend l'unique constante `notchRadius` de 16 pt pour les deux courbes ; la constante inférieure distincte a été retirée. La phrase UX devenue fausse a été supprimée.
- Aucun build, test, contrôle visuel ou relecture du diff n'a été effectué pour ce retour, conformément à la consigne de Samuel.

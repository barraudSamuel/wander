---
title: "Corriger le titre d’un lieu partagé depuis Naver"
status: completed
date: 2026-09-04
completed_at: 2026-09-04T11:56:00+09:00
owner: "Samuel"
related:
  - "./2026-08-17-import-lieu-partage-ios-sprint-01.md"
tags: [plan, ios, share-extension, naver, bugfix]
---

# Corriger le titre d’un lieu partagé depuis Naver

## Outcome

Un lieu partagé par Naver affiche son vrai nom dans le compositeur Wander, par
exemple `녹녹`, au lieu du libellé générique `[NAVER Maps]`. Son adresse et ses
coordonnées restent correctement préremplies avant publication.

## Context

Le payload réel signalé est compacté sur une seule ligne :
`[NAVER Maps] 녹녹 서울 마포구 연남동 249-11 https://naver.me/xB7Oc7MR`.
La redirection HTTP expose bien `title=녹녹`, `lat=37.5637823` et
`lng=126.9220025`, mais le parseur reconnaît seulement la variante singulière
`NAVER MAP` et découpe le texte partagé uniquement aux retours à la ligne.

## Scope

- Included:
  - reconnaître les variantes génériques `NAVER MAP` et `NAVER Maps` ;
  - traiter les payloads Naver sur une ou plusieurs lignes ;
  - retirer le préfixe et l’URL du texte utile ;
  - utiliser le titre de la redirection comme ancrage fiable pour séparer le
    nom et l’adresse ;
  - préserver les partages non-Naver et les replis MapKit existants.
- Not included:
  - ajout d’une API, d’un SDK ou d’une clé Naver ;
  - modification du modèle Firestore ou de la publication ;
  - ajout d’une target XCTest dans cet incrément ;
  - distribution ou déploiement de l’application.

## Proposed approach

Résoudre d’abord l’URL courte, lire son paramètre `title`, puis normaliser le
texte partagé en supprimant l’URL et le préfixe Naver. Lorsque le texte est sur
une seule ligne, le titre de l’URL sert de frontière déterministe entre le nom
et l’adresse. Pour les payloads multilignes ou génériques, conserver le
comportement actuel avec un filtrage élargi des titres Naver génériques.

## Affected files

- `docs/plans/2026-09-04-corriger-titre-partage-naver.md` — suivi du correctif.
- `wander/SharedPlaceImport.swift` — extraction robuste du nom et de l’adresse.
- `docs/solutions/2026-09-04-parser-payload-naver-inline.md` — leçon
  réutilisable après validation.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md`
  — état de la validation du partage Naver.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md`
  — stratégie de parsing du payload et de la redirection.
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`
  — nom et adresse attendus dans le compositeur partagé.

Le vault Obsidian est lisible et les trois notes prévues ont été mises à jour
sur place, sans créer de copie du vault.

## Implementation checklist

- [x] Faire précéder le parsing du texte par l’extraction du titre de l’URL
  redirigée.
- [x] Normaliser les préfixes Naver singuliers et pluriels et retirer les URLs.
- [x] Séparer le nom et l’adresse dans les payloads mono-ligne et multi-lignes.
- [x] Vérifier les replis existants et compiler le scheme `wander`.
- [x] Effectuer la revue ciblée et documenter le résultat.

## Risks

- Un nom ou une adresse contenant des espaces ne fournit pas de frontière
  intrinsèque ; le titre décodé de la redirection sert d’ancrage au lieu d’une
  découpe heuristique arbitraire.
- Naver peut changer son payload ; les replis existants par lignes, paramètres
  URL, métadonnées et MapKit sont conservés.
- Une validation Naver de bout en bout peut exiger un iPhone équipé de Naver
  Map ; la compilation et les contrôles déterministes ne la remplacent pas.

## Validation

- [x] Le payload signalé produit `녹녹` et
  `서울 마포구 연남동 249-11`.
- [x] Les variantes mono-ligne, multi-lignes, `NAVER MAP` et `NAVER Maps` sont
  cohérentes.
- [x] Le scheme `wander` compile pour simulateur iOS sans nouvel avertissement.
- [x] La Share Extension est vérifiée sur le simulateur ou la limite de
  validation réelle est explicitement consignée.
- [x] Les notes Obsidian modifiées sont vérifiées en lecture et leur propriété
  `updated` est actualisée.

Le build Debug final du scheme `wander` réussit pour simulateur iOS. Le build
a été installé sur l’iPhone 17 Pro Simulator déjà démarré, mais Naver Map n’y
est pas disponible : le parcours inter-app réel reste donc à confirmer sur
l’iPhone équipé de Naver. Les deux avertissements `CFBundleVersion` des
extensions sont préexistants et documentés dans plusieurs plans antérieurs.

La revue statique suit le payload signalé de bout en bout : la redirection
fournit `title=녹녹`, le préfixe et l’URL sont retirés, puis le titre sert de
frontière et laisse `서울 마포구 연남동 249-11` comme adresse. La même résolution
s’applique lorsque les quatre éléments sont séparés par des retours à la ligne.
`git diff --check` ne relève aucune erreur d’espace.

Les trois notes Obsidian ont été ouvertes en lecture. Leurs propriétés
`updated`, leurs wikilinks, le tableau technique et les passages Naver modifiés
s’affichent correctement.

## Acceptance criteria

- Le titre générique Naver n’est jamais utilisé comme nom de l’événement.
- Le nom `녹녹`, l’adresse coréenne et les coordonnées de la redirection sont
  conservés.
- Les autres formats de partage restent pris en charge.
- Aucun contenu partagé ou identifiant précis n’est ajouté aux logs.

## Review notes

- Hardest decision: limiter le titre structuré aux hôtes Naver reconnus afin de
  corriger ce fournisseur sans modifier la priorité des autres partages.
- Rejected alternatives: découper l’unique ligne au premier espace, ce qui
  casserait les noms de lieux composés ; ajouter seulement la variante plurielle
  n’aurait pas résolu les payloads mono-ligne.
- Least certain: comportement de la feuille de partage Naver sur un appareil
  réel après une future mise à jour de l’application.
- Review result: aucun finding nouveau. Le durcissement final ignore les titres
  Naver vides ou génériques et exige une frontière complète après le préfixe.

---
id: "054"
title: "Aligner les numéros de build des extensions"
status: ready
priority: P2
source: review
created: 2026-09-20
tags: [todo, build]
---

## Constat

La compilation de validation réussit mais signale deux avertissements existants :
les extensions ont les CFBundleVersion 15 et 27, contre 42 pour l’application.
Les valeurs viennent de `CURRENT_PROJECT_VERSION` dans
`wander.xcodeproj/project.pbxproj`, non modifié par la suppression du rail.

Reconfirmé le 23 septembre pendant la validation du détail événement : extensions
15 et 27, application 46. Compilation réussie, journal
`/tmp/wander-event-detail-build.log`. Ce changement ne modifie pas les versions.

## Critères d’acceptation

- [ ] Aligner les versions après approbation d’un plan dédié.
- [ ] Compiler sans ces avertissements.

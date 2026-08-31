---
id: "019"
title: "Déployer et valider l’actualisation Location Push"
status: ready
priority: P1
source: review
created: 2026-08-31
tags: [todo, location, apns, firebase, validation]
---

# Déployer et valider l’actualisation Location Push

## Finding

L’implémentation, les règles et le build local sont validés, mais un Location
Push ne peut pas être exercé fidèlement dans le simulateur. La fonctionnalité
reste inactive en production tant que la capability et les profils Apple, les
secrets APNs et le déploiement Firebase ne sont pas configurés par le
propriétaire.

Ce point est P1 car il conditionne directement la disponibilité de
l’actualisation à la demande et sa validation avant distribution.

## Evidence

- `docs/plans/2026-08-31-actualisation-localisation-ami.md` consigne les
  validations locales réussies et les limites restantes.
- `docs/notifications-apns-configuration.md` décrit les secrets, les commandes
  de déploiement ciblées et le scénario sur deux appareils.
- Le 2026-08-31, le build Debug app + extension, les 38 tests backend et les 42
  tests de règles Firestore ont terminé sans échec.

## Acceptance criteria

- [ ] La capability Location Push et les profils de signature de l’app et de
      l’extension sont valides dans Apple Developer et Xcode.
- [ ] Les trois secrets APNs sont configurés, puis les règles et la fonction
      ciblée sont déployées dans le bon projet Firebase.
- [ ] Deux appareils physiques avec une amitié acceptée valident le chemin
      sandbox : loader immédiat, réveil de l’appareil cible, nouvelle position
      et arrêt du loader.
- [ ] Les cas position fraîche, partage désactivé, autorisation insuffisante,
      token absent, erreur APNs et timeout conservent la dernière position sans
      loader permanent.
- [ ] VoiceOver, contraste, mode sombre et Réduire les animations sont vérifiés
      sur l’avatar en actualisation.
- [ ] Une archive distribuable valide ensuite le même scénario en production.
- [ ] Les quatre notes Obsidian listées dans le plan sont mises à jour avec leur
      propriété `updated`, puis vérifiées en mode lecture.

## Resolution notes

Ne pas marquer ce point terminé sur la seule base du simulateur. Les étapes
externes restent manuelles et aucun secret ni profil ne doit être commité.

---
title: Déplacer le code ami et l’ajout d’amis dans le profil
status: completed
completed_at: 2026-09-22T16:45:15+09:00
approved_at: 2026-09-22
---

# Résultat attendu

Le profil personnel affiche « Ton code ami », Copier, Partager et « Ajouter un ami »
juste après le résumé. Amis conserve les demandes reçues, la liste et les demandes
en attente. Samuel a approuvé ce périmètre le 22 septembre 2026 avec « je valide ».

## Périmètre et fichiers

- `wander/FriendsPanelView.swift` : retirer les deux sections et leurs actions.
- `wander/ProfilePanelView.swift` : intégrer les sections et les erreurs d’envoi.
- `wander/ContentView.swift` : transmettre le brouillon au profil.
- `wander/DebugSocialMapScenario.swift` : aligner le scénario local.
- `wanderUITests/MotionDockUITests.swift` et `MapSocialGestureUITests.swift` :
  adapter les repères Amis et la persistance de la saisie dans le profil.
- Ce plan et, si nécessaire, les constats de revue dans `todos/`.
- Vault `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander` :
  `Backlog features.md`, `Documentation UX.md`, `Documentation technique.md`.
  Mettre à jour les parcours Amis/Profil, la responsabilité des vues et `updated`.

Les modèles, Firebase et la hauteur compacte de `OwnProfileSheet` restent inchangés.
Une seule étape d’implémentation. Aucun changement Git mutatif ni publication.

## Implémentation

- [x] Déplacer les sections et conserver les contrôles SwiftUI natifs.
- [x] Conserver le brouillon dans ContentView, vider seulement le code envoyé
  après succès et présenter les erreurs dans le profil.
- [x] Adapter le scénario et les tests de navigation existants.
- [x] Simplifier, compiler, relire et consigner la validation exacte.
- [x] Mettre à jour les trois notes Obsidian et leur propriété updated.

## Risques et validation

- Vérifier que les alertes d’envoi ne sont pas présentées derrière la feuille.
- Vérifier le défilement et le clavier, la persistance à la fermeture et les deux
  accès au profil. Vérifier que les demandes reçues restent accessibles dans Amis.
- Compiler l’application et les cibles de tests pour iOS Simulator en réutilisant
  le cache Xcode. Adapter les tests existants plutôt que créer une suite dédiée.
- Le déplacement de contrôles est vérifié par compilation, revue et adaptation
  des tests UI existants ; aucun cycle rouge/vert n’est revendiqué.
- Au démarrage du travail, `simctl list devices booted` confirme uniquement
  l’iPhone 16e, aucun iPhone 17. Ne pas démarrer de simulateur ni exécuter les
  tests sur un autre appareil ; la validation UI reste à réaliser sur iPhone 17.
- Les notes Obsidian sont hors des racines d’écriture par défaut. Demander
  l’escalade pour les seules notes approuvées ; consigner toute limite réelle.

## Critères d’acceptation

- Les deux sections existent uniquement dans le profil personnel.
- La copie, le partage, la préparation du profil et l’ajout conservent leur logique.
- La saisie survit aux fermetures du profil, le succès efface seulement le code envoyé.
- Les tests existants suivent la nouvelle navigation et les cibles compilent.
- Les limites de validation sont documentées et les vues gardent le style natif.

## Validation et revue

- `xcodebuild -project wander.xcodeproj -scheme wander -configuration Debug
  -destination 'generic/platform=iOS Simulator' -disableAutomaticPackageResolution
  build-for-testing` : `TEST BUILD SUCCEEDED`, sortie 0.
- Journal : `/tmp/wander-friend-profile-build.log`.
- Aucune nouvelle erreur ni alerte Swift. Diagnostics préexistants AppIntents
  et CFBundleVersion des extensions 15/27 contre 44 pour l’app. Suivi existant :
  `todos/054-ready-p2-aligner-build-extensions.md`.
- `git diff --check` : réussi.
- `ce-simplify-code` : trois relectures, aucune réutilisation utile, un même
  problème signalé par qualité et efficacité puis corrigé. L’alerte commune
  efface uniquement sa source ; une erreur de compte ne déclenche pas
  `FriendSyncService.clearError()` ni son éventuelle reprise du profil.
- `ce-test-xcode` : résultat PARTIAL. XcodeBuildMCP absent et aucun iPhone 17
  démarré. Compilation équivalente via CLI ; aucun lancement, test exécuté,
  screenshot ni validation Firebase revendiqué. Suivi :
  `todos/061-ready-p2-valider-invitations-profil.md`.
- Notes Obsidian mises à jour avec leur propriété `updated` le 22 septembre.
  Écriture vérifiée dans le vault existant après escalade autorisée.
- `ce-code-review` : terminé, `status: complete`, `Ready to merge`, aucun
  constat actionnable. Huit relectures locales ; le manque de preuve Firebase
  du scénario est conservé comme limite de couverture, suivie dans le todo 061.
  Reçu : `/tmp/compound-engineering-501/20260922-profile-2jtax_4n/review.json`.
  La tentative de revue externe Composer a été refusée par le contrôle
  automatique d’approbation, faute d’autorisation d’exporter le code ; aucune
  donnée n’a été envoyée. La revue a été menée à terme localement.
- Compound : déplacement courant sans nouvelle connaissance réutilisable ;
  aucune note de solution supplémentaire nécessaire.

## Choix et limites

Le choix principal est de conserver le brouillon dans `ContentView`, puis de
transmettre son Binding au profil. Un état local à la feuille perdrait la saisie
à sa fermeture. Les sections natives sont déplacées sans modifier le service.

Le scénario de test conserve sa source de données locale. Une refonte par
injection de dépendances pour tester Firebase depuis ce scénario dépasse ce
déplacement ; les parcours réels de réussite et d’erreur restent à vérifier
sur l’iPhone 17. C’est l’incertitude restante, avec les gestes et le clavier.

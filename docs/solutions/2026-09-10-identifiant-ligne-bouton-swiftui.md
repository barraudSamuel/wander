---
title: "Conserver l’identifiant des boutons dans une liste SwiftUI"
date: 2026-09-10
tags: [ios, swiftui, events, testing]
---

# Libellé de ligne et identité du bouton

Dans la liste d’événements, appliquer `accessibilityElement(children: .ignore)`
au `Button` lui-même faisait perdre son identifiant et son libellé personnalisé
dans l’arbre XCTest. Le bouton restait visible sous son libellé textuel implicite ;
les tests fonctionnels de sélection ne le retrouvaient plus par identifiant.

Le groupement et le libellé descriptif sont maintenant appliqués au `HStack` du
label. `buttonStyle`, `accessibilityIdentifier` et `accessibilityHint` restent
sur le bouton natif. Les parcours retrouvent alors l’identifiant stable et
le texte décrivant activité, date, lieu et réponse.

Preuves : première passe `/tmp/wander-social-list-tests.xcresult`, puis parcours
corrigé `/tmp/wander-social-list-accessibility-fix.xcresult` et trois parcours
fonctionnels dans `/tmp/wander-social-list-render.xcresult`. Le diagnostic porte
sur cette composition SwiftUI ; ne pas en déduire que tout groupement de bouton
présente le même comportement.

Source : `../plans/2026-09-10-liste-evenements-sociale-emojis.md`.

---
title: Diagnostiquer la rotation avant validation paysage
status: ready
priority: p2
date: 2026-09-11
---

## Observation

Sur l’iPhone 17 existant, `testCompactGuestActionsAndMapRemainAvailable` échoue
deux fois sur le prédicat `window.width > window.height`, après la demande
`XCUIDevice.shared.orientation = .landscapeLeft`.
Le journal confirme le changement d’orientation de l’appareil ; la capture montre
l’interface toujours en portrait. Les boutons sont visibles et utilisables aux
trois hauteurs du divider avant cette demande. La cause n’est pas établie.

Résultats : `/tmp/wander-map-event-actions.xcresult` et
`/tmp/wander-map-event-actions-final.xcresult`.
Capture : `/tmp/wander-map-event-actions-final-screens/6B8E01B7-39BB-4F33-95D3-AE45641E28D3.png`.
Le plist compilé annonce portrait et les deux paysages ; aucune surcharge
d’orientation n’a été trouvée dans les sources Swift de l’app.

## Suite à prévoir

Déterminer si l’absence de rotation vient de l’environnement ou du conteneur iOS,
puis vérifier l’interface paysage et les zones sûres. Ne pas affaiblir le prédicat
ni annoncer ce test réussi. Réutiliser le simulateur existant, sans nouveau runtime.
Une modification du conteneur ou de la configuration nécessite un plan distinct.

Les parcours demandés en portrait sont validés : sélection sans fiche, réponse
sur la bonne cible, recentrage, défilement, édition/annulation et profils d’amis.
Plan : `../docs/plans/2026-09-11-actions-evenement-sur-carte.md`.

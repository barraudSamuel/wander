---
title: "Porter la confirmation de retrait sur le conteneur du profil"
date: 2026-09-27
module: Profil et amis
problem_type: ui_bug
component: frontend
symptoms:
  - "Le bouton Retirer apparaît après un balayage, mais sa confirmation ne s’affiche pas."
root_cause: wrong_api
resolution_type: code_fix
severity: medium
framework_version: "SwiftUI, simulateur iOS 26.3.1"
tags: [ios, swiftui, profile, friends, alerts]
---

# Confirmation de retrait dans un formulaire composé

## Problème

Pendant le déplacement des amis dans le profil, `FriendsPanelView` est passé
d’une `List` autonome à un `Group` de sections, inséré dans le formulaire parent.
Conserver le modificateur `.alert` sur ce groupe empêchait la confirmation de
retrait de s’afficher dans le scénario UI local.

## Cause et correction

Dans cette composition, les sections fournissent le contenu d’un formulaire ;
le groupe ne constituait pas un hôte de présentation fiable. La tentative
d’attacher l’alerte directement à ce groupe a échoué sur le simulateur utilisé.
Ce constat ne prouve pas que toute alerte appliquée à un `Group` échoue.

La correction locale, en attente de commit, donne au profil la propriété de
l’ami à retirer. Les sections reçoivent une liaison et définissent cette valeur
depuis l’action de balayage :

```swift
@Binding var friendPendingRemoval: FriendMapSummary?

Button(role: .destructive) {
    friendPendingRemoval = friend
} label: {
    Label("Retirer", systemImage: "person.badge.minus")
}
```

`ProfilePanelView` porte l’alerte sur son conteneur de navigation, avec
`presenting: friendPendingRemoval`. Le service ne reçoit la demande de retrait
qu’après confirmation. Le scénario local porte l’alerte sur son formulaire.
Les deux hôtes restent présents quand les sections changent.

## Validation et prévention

Le test `testFriendRemovalRequiresConfirmationInProfile` a d’abord échoué sur
l’absence de l’alerte, puis a réussi après son déplacement : annuler conserve
l’ami ; confirmer le retire du scénario local. Cette preuve ne couvre pas une
écriture Firebase distante.

Lorsqu’une liste autonome devient un ensemble de sections, vérifier aussi ses
présentations modales et garder un test qui exerce annulation et confirmation.

Sources : `wander/FriendsPanelView.swift`, `wander/ProfilePanelView.swift`,
`wander/DebugSocialMapScenario.swift`, `wanderUITests/MotionDockUITests.swift`.
Plan : [Amis dans le profil](../plans/2026-09-27-amis-dans-profil.md).

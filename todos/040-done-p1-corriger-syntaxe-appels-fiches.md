---
id: "040"
title: "Corriger la syntaxe des appels aux fiches"
status: done
priority: P1
source: user-screenshot
created: 2026-09-08
tags: [todo, map, swift, compilation]
---

# Corriger la syntaxe des appels aux fiches

La capture Xcode fournie par Samuel affiche huit erreurs dans
FriendProfileSheet.swift et OutingPlanDetailCardView.swift. Les deux appels
à MapDetailPanel écrivaient `) supporting: {`, alors que la première trailing
closure ne porte pas de label en Swift. Les diagnostics sur `actions:` sont
consécutifs à cette erreur de syntaxe.

Les deux appels utilisent désormais `) { ... } actions: { ... }`. Aucun contenu
ni callback ne change. Les deux occurrences sont corrigées et le diff est relu.
Aucun test ni build exécuté, conformément à la consigne maintenue de Samuel.
La réussite de la compilation complète n'est pas revendiquée.

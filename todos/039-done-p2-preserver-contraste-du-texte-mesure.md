---
id: "039"
title: "Préserver le contraste du texte mesuré"
status: done
priority: P2
source: code-review
created: 2026-09-08
tags: [todo, map, accessibility, uikit]
---

# Préserver le contraste du texte mesuré

## Constat de revue

Le nouveau label résolvait les couleurs sémantiques avec seulement le mode
clair ou sombre. Le réglage Augmenter le contraste était donc perdu, ainsi
que pour les contours et les images de remplacement des avatars.

## Résolution

Le pont transmet aussi le contraste de l'environnement SwiftUI au rendu UIKit.
Sa modification invalide le cache des mesures et reconstruit le texte avec
les couleurs sémantiques adaptées. La clé des images d'avatars inclut le mode
clair/sombre et le contraste pour éviter la réutilisation d'une ancienne image.

Validation par relecture uniquement. Aucun test, build ou contrôle visuel
exécuté, conformément à la demande de Samuel.

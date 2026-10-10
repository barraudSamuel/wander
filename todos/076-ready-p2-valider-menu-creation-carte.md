---
title: "Valider le menu de création sur une session connectée"
status: ready
priority: p2
date: 2026-10-10
tags: [review, ios, ux]
---

# Valider le menu de création sur une session connectée

La compilation et l’installation réussissent sur l’iPhone 17 Pro existant.
L’app affiche l’écran de connexion Apple. Le scénario de test local utilise
une autre vue et ne couvre pas le nouveau bouton de `ContentView`.

Après connexion par Samuel, vérifier à taille de texte standard :

- Bouton + en bas à droite, sous le crosshair avec 12 points d’écart,
  sans chevauchement avec le calendrier ni les mentions Mapbox.
- Centre du + aligné sur celui des événements, liste ouverte ou fermée,
  et lorsque le clavier déplace la rangée inférieure.
- Taille identique des boutons + et crosshair et même retour visuel natif à l’appui.
- Le + ne grise pas à l’ouverture de son menu ; des appuis répétés n’ouvrent qu’une feuille.
- Absence de titre, de croix et de barre de navigation.
- Ouverture, fermeture par glissement vers le bas, puis réouverture de la feuille.
- Deux options « Bientôt » désactivées.
- Événement à la position actuelle : fermeture du menu puis ouverture du formulaire.
- Annulation du formulaire et retrait du marqueur de brouillon.
- Sans position : explication du parcours existant par appui long sur la carte.
- Même accès lorsque la liste des événements est ouverte.

Ne pas publier d’événement réel pour cette validation.
Plan : [Menu de création](../docs/plans/2026-10-10-menu-creation-carte.md).

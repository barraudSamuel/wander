---
id: "059"
title: "Valider le bouton événements et la liste sous la carte sur appareil"
status: ready
priority: P2
source: review
created: 2026-09-20
tags: [todo, events, ui]
---

# Valider le bouton événements et la liste sous la carte sur appareil

## Constat

Un bouton calendrier séparé à droite de la barre native ouvre et ferme la liste
sous la carte. Le rail de badges est supprimé. La poignée règle la hauteur et
replie le panneau. Samuel limite la session à la compilation, sans simulateur.
La capture fournie le 21 septembre montre le calendrier plus bas que les
onglets. Le correctif l'ancre au bord supérieur converti de la barre au lieu
de le centrer dans une zone qui inclut l'espace sous la capsule. La compilation
ne confirme pas à elle seule sa résolution visuelle. La seconde capture du
21 septembre et le retour de Samuel confirment que l'alignement en portrait
lui paraît correct. Le calendrier est ensuite rapproché de 8 points de la barre
et le recentrage remonté de 12 points, selon le nouvel ajustement approuvé.
Leurs nouveaux espacements restent à vérifier avec clavier et en vue partagée.

La vidéo du 21 septembre montre aussi le cercle du calendrier réduit après
Profil → Événements, puis toujours réduit après fermeture. Le correctif approuvé
fixe sa géométrie au repos à 54 points via `bounds`/`center` et calcule la réserve
du contenu sans lire son `frame` transformé. Il supprime le diamètre variable
44–54 points et l'assignation de `frame` pendant les interactions natives.
La cause dynamique précise reste non mesurée. Aucun simulateur n'était démarré
lors du contrôle ; aucun appareil n'a été lancé. Compilation app et tests
réussie, mais résolution du défaut visuel encore à confirmer.

## Preuves

- [Nouvelle icône calendrier](../docs/plans/2026-09-21-icone-evenements.md) :
  illustration fournie, fond bleu et rendu original, variantes 40/80/120 pixels,
  image circulaire de 36 points dans le bouton de 54 points. Rendu sur appareil
  encore à confirmer ; les fichiers d'asset sont inspectés localement.
- [Plan approuvé](../docs/plans/2026-09-20-bouton-evenements-navigation.md).
- [Correctif de stabilité](../docs/plans/2026-09-21-stabiliser-bouton-evenements.md),
  compilation `TEST BUILD SUCCEEDED`, code 0,
  `/tmp/wander-events-stable-size-build.log`.
- `wander/NativeMapTabView.swift` et `wander/MotionDockView.swift` : bouton natif,
  alignement avec la barre, clavier et état de présentation.
- `wander/MapEventsPanelView.swift` : liste persistante et observations actives.
- `wander/MapDetailSplitView.swift` : carte stable, panneau inférieur et poignée.
- `wander/ContentView.swift` : navigation et garde des confirmations de compte.
- Tests fonctionnels adaptés dans `MapSocialGestureUITests.swift` et
  `MotionDockUITests.swift`, compilation seulement. Journaux dans le plan.

## Critères d'acceptation

- [ ] Confirmer le cadrage circulaire, la lisibilité et la taille de la nouvelle
  icône calendrier par rapport aux autres icônes, dans les deux états du bouton.
- [ ] Vérifier que le cercle garde le même diamètre après Profil → Événements,
  Amis → Événements et plusieurs ouvertures/fermetures, y compris au relâchement
  d'un appui. Les assertions existantes contrôlent taille et position à un point
  près ; elles ont été compilées mais pas exécutées.
- [ ] À taille standard, confirmer les centres verticaux du calendrier et des
  onglets alignés à deux points près, avec le bouton à droite de la barre, sans
  chevauchement ni sortie d'écran en portrait/paysage et avec le clavier.
- [ ] Confirmer les nouveaux espacements : calendrier 8 points plus proche de
  la barre et recentrage 12 points plus haut, également en vue partagée.
- [ ] Confirmer ouverture/fermeture par le bouton depuis Explorer, Amis, Profil
  et une fiche d'ami ; vérifier l'état actif et les confirmations de compte.
- [ ] Confirmer la liste sous la carte, sa poignée, le repli et la carte seule
  sans aucun badge au-dessus de la navigation lorsque la liste est fermée.
- [ ] Confirmer le nouveau seuil approuvé : fermeture au relâchement lorsque
  la hauteur utile est inférieure à `min(120 points, 10 % de la hauteur disponible)`.
  Le geste doit descendre davantage qu'avec le précédent coefficient de 20 %.
- [ ] Sur iPhone, confirmer un impact léger au premier franchissement du seuil,
  sans répétition dans le même glissement, et à nouveau possible au geste suivant.
- [ ] Confirmer le défilement conservé, la sélection, l'appui long, les actions,
  les observations suspendues et l'absence de conflit avec les gestes de carte.
- [ ] Confirmer les états vide, chargement, erreur partielle et réessai.
- [ ] Rejouer les tests fonctionnels lorsque l'exécution sera autorisée.
  Aucun contrôle dédié d'accessibilité ajouté à ce suivi.

Les échanges Firestore authentifiés restent suivis dans 047 ; les avertissements
de versions des extensions sont déjà suivis dans 054.

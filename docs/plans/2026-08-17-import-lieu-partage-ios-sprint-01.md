---
title: "Import de lieu — Sprint 1 — Publication depuis la feuille de partage"
status: in_progress
sprint: 1
date: 2026-08-17
approved_at: "2026-08-17T16:29:12+09:00"
started_at: "2026-08-17T16:29:12+09:00"
tags: [plan, sprint, ios, share-extension, naver, events]
---

# Sprint 1 — Publier un événement depuis la feuille de partage

## Outcome

Depuis Naver Map ou une autre application qui partage un lieu sous forme d’URL
ou de texte, l’utilisateur choisit Wander dans la feuille de partage iOS. Une
interface Wander native s’affiche dans l’extension, résout automatiquement le
lieu, préremplit le formulaire de création et publie directement l’événement
après le choix de la catégorie et de l’heure.

Le parcours cible est :

`Naver → Partager → Wander → vérifier le lieu → catégorie + heure → Publier`.

Après le succès, l’extension se ferme et rend la main à Naver. Elle ne force pas
le lancement de l’application principale, comportement non autorisé pour une
Share Extension iOS standard. Comme WhatsApp ou une action Papago, l’interface
plein écran appartient visuellement à Wander mais s’exécute dans l’extension.

## Platform contract

- Apple prévoit une Share Extension pour recevoir du contenu, afficher une
  interface de composition personnalisée et le publier depuis la feuille de
  partage :
  <https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/Share.html>.
- Une Share Extension ne peut pas demander au système d’ouvrir directement son
  application conteneur ; le flux doit donc être terminé dans l’extension :
  <https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/ExtensionOverview.html>.
- L’application et l’extension peuvent partager des données et un accès au
  trousseau via un App Group :
  <https://developer.apple.com/documentation/xcode/configuring-app-groups>.
- Firebase Auth prend explicitement en charge un état d’authentification partagé
  entre applications et extensions au moyen d’un groupe de trousseau :
  <https://firebase.google.com/docs/auth/ios/single-sign-on>.

## Scope

- Ajouter un target iOS `WanderShareExtension`, embarqué et signé avec
  l’application Wander.
- Faire apparaître Wander uniquement pour les éléments `public.url` et
  `public.plain-text` pertinents.
- Charger les pièces jointes avec `NSItemProvider` sans journaliser leur contenu.
- Normaliser le titre, le texte et l’URL reçus, suivre les redirections avec une
  session éphémère et extraire une coordonnée lorsqu’elle est présente.
- Résoudre automatiquement le lieu sans saisie cartographique : métadonnées de
  l’URL, texte partagé, recherche MapKit automatique, puis géocodage inverse.
- Refuser de publier lorsqu’aucune coordonnée fiable ne peut être déterminée ;
  ne jamais inventer un point ou utiliser la position courante par défaut.
- Présenter une interface SwiftUI plein écran et native : lieu en lecture seule,
  catégorie explicite sans présélection, heure dans les prochaines 24 heures,
  état de chargement, erreur récupérable et bouton Publier.
- Partager l’état Firebase Auth avec l’extension via Keychain Sharing et un App
  Group commun, avec migration idempotente de la session existante.
- Lire le profil `users/{uid}` pour obtenir le nom de publication et confirmer
  que le compte est utilisable.
- Extraire la construction et la publication Firestore d’un événement dans un
  composant commun à l’application et à l’extension afin de conserver un seul
  contrat de données.
- Publier directement dans `users/{uid}/events/{eventId}` avec le contrat strict
  existant, empêcher les doubles soumissions et fermer l’extension après succès.
- Afficher un message clair si Wander n’a jamais été ouvert, si la session n’est
  pas disponible, si le lieu est illisible ou si le réseau échoue.
- Conserver l’appui long cartographique actuel comme parcours interne à
  l’application.

## Non-goals

- Aucun contournement privé pour forcer l’ouverture de l’application conteneur.
- Aucun deep link, Universal Link ou URL scheme ajouté uniquement pour essayer
  d’échapper à la Share Extension.
- Aucun formulaire dupliquant l’édition ou l’annulation d’un événement existant.
- Aucune importation de capture d’écran, d’image, d’itinéraire ou de liste de
  lieux dans ce sprint.
- Aucune dépendance à une API privée Naver, aucun scraping HTML fragile et
  aucune clé Naver ajoutée au projet.
- Aucune coordonnée déduite de la position courante lorsqu’un partage est
  ambigu.
- Aucune file de publication hors ligne ou tâche réseau longue en arrière-plan.
- Aucun changement du schéma Firestore, des notifications ou de la durée de vie
  des événements.
- Aucun déploiement Firebase, publication App Store, commit ou changement
  distant du portail Apple par Codex.
- Aucun secret, contenu partagé, adresse, coordonnée ou identifiant
  d’authentification ajouté aux logs.

## Dependencies

- Les trois sprints des événements multiples sont terminés.
- Le contrat Firestore strict avec catégorie obligatoire est déployé dans le
  projet Firebase utilisé par l’iPhone de test.
- L’équipe Apple `MDSH9S69B9` doit autoriser les capacités App Groups et Keychain
  Sharing pour l’app et l’extension avec la signature automatique Xcode.
- `wander/GoogleService-Info.plist` reste un fichier local non versionné ; il
  peut être inclus comme ressource du target d’extension sans modifier ni
  exposer son contenu.
- Au moins un partage réel d’un lieu Naver doit être disponible sur l’iPhone de
  validation afin de confirmer les types et la forme du payload effectivement
  fournis par Naver.

## Affected files

- `wander.xcodeproj/project.pbxproj`
- `wander/wander.entitlements`
- `wander/Info.plist`
- `wander/FirebaseService.swift`
- `wander/OutingPlan.swift`
- `wander/OutingPlanService.swift`
- `wander/OutingPlanPublishing.swift` — nouveau composant de publication commun
- `wander/SharedFirebaseAuthConfiguration.swift` — nouvelle configuration du
  groupe d’accès et migration de session
- `wander/SharedPlaceImport.swift` — nouveau modèle et résolveur d’entrée
- `WanderShareExtension/Info.plist` — nouveau
- `WanderShareExtension/WanderShareExtension.entitlements` — nouveau
- `WanderShareExtension/ShareViewController.swift` — nouveau
- `WanderShareExtension/ShareComposerView.swift` — nouveau
- `WanderShareExtension/ShareExtensionFirebaseBootstrap.swift` — nouveau
- `firestore.rules` — lecture seule attendue ; modification uniquement si une
  incompatibilité réelle est démontrée et après nouvelle approbation
- `firebase-tests/tests/outing-events.rules.test.mjs` — réutilisation ou cas
  supplémentaire si le publisher commun révèle un contrat non couvert
- `docs/plans/2026-08-17-import-lieu-partage-ios-sprint-01.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Backlog features.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation technique.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/Documentation UX.md`
- `/Users/samuelbarraud/Library/Mobile Documents/iCloud~md~obsidian/Documents/sam/wander/00 - Wander.md`

## Implementation checklist

- [x] Passer le plan à `approved`, puis `in_progress`, après approbation explicite.
- [x] Ajouter le target Share Extension, son produit `.appex`, son embedding et
  ses dépendances Firebase Auth/Firestore.
- [x] Configurer les bundle identifiers, Info.plist, App Group et Keychain
  Sharing communs sans élargir les autres capacités.
- [x] Implémenter la migration idempotente de la session Firebase Auth vers le
  groupe partagé avant l’installation du listener d’authentification.
- [x] Implémenter le bootstrap Firebase minimal de l’extension et ses états
  « session absente » ou « profil indisponible ».
- [x] Extraire un publisher Firestore commun et faire déléguer
  `OutingPlanService.publish` sans modifier le contrat existant.
- [x] Charger URL et texte depuis `NSItemProvider` avec annulation propre.
- [x] Implémenter la chaîne de résolution du lieu, les délais, les validations
  et les messages d’erreur sans log sensible.
- [x] Construire le formulaire SwiftUI natif de l’extension avec lieu fixe,
  catégorie obligatoire et date limitée à 24 heures.
- [x] Empêcher les doubles publications, afficher la progression et terminer la
  requête de l’extension uniquement après confirmation Firestore.
- [x] Gérer annulation, entrée non prise en charge, hors-ligne et expiration de
  session sans perdre le contrôle de la feuille de partage.
- [x] Simplifier le code commun et revoir les appartenances de target pour ne
  pas embarquer les services UI ou Messaging inutiles dans l’extension.
- [x] Mettre à jour les quatre notes Obsidian et vérifier leur rendu en mode
  Aperçu.
- [x] Exécuter le build et les tests Firestore/Functions.
- [ ] Exécuter la validation réelle sur l’iPhone.
- [x] Effectuer la revue de code finale et consigner tout finding non résolu
  sous `todos/`.

## Risks and mitigations

- **Payload Naver variable** — Naver peut partager une URL courte, une URL
  redirigée ou du texte. Le résolveur suit une chaîne déterministe et échoue
  explicitement si aucun point fiable n’est obtenu. Toute nécessité d’une API
  privée ou d’un scraping constituerait un changement matériel de scope.
- **Migration Firebase Auth** — `useUserAccessGroup` change le stockage de la
  session et peut déconnecter l’utilisateur si la migration est mal ordonnée.
  Le code conserve l’utilisateur courant, bascule une seule fois, appelle
  `updateCurrentUser`, vérifie le résultat et expose une erreur récupérable.
- **Processus d’extension limité** — le target reste léger, ne démarre ni
  Messaging, ni SwiftData, ni les listeners sociaux, annule les requêtes
  obsolètes et ne lance aucune tâche de fond indéfinie.
- **Configuration Firebase** — l’extension doit trouver la configuration locale
  au runtime sans créer une seconde copie versionnée du plist ni imprimer ses
  valeurs.
- **Écriture partielle ou doublon** — un seul `eventId` est généré par session
  de composition, le bouton est verrouillé pendant l’écriture et l’extension ne
  se ferme qu’après relecture serveur réussie.
- **Lieu homonyme** — un résultat MapKit n’est accepté que si la chaîne partagée
  fournit assez de contexte ; l’interface montre le lieu et l’adresse avant la
  publication pour que l’utilisateur puisse annuler.
- **Retour à Naver** — c’est le comportement normal et App-Store-safe après la
  fin de l’extension. Le succès doit être explicite avant la fermeture afin que
  ce retour ne ressemble pas à un échec.

## Validation

- [x] Le schéma `wander` compile avec l’app et `WanderShareExtension` pour la
  destination générique iOS Simulator, sans nouvel avertissement Swift.
- [ ] L’application s’installe et démarre sur l’iPhone sans perdre la session
  Apple existante après migration du trousseau.
- [ ] Après déconnexion de Wander, l’extension ne peut plus publier et affiche
  un état explicite ; après reconnexion, elle récupère la session partagée.
- [ ] Wander apparaît dans la feuille de partage Naver pour un lieu et n’apparaît
  pas pour des types de contenu non pris en charge.
- [ ] Choisir Wander affiche le compositeur de l’extension sans ouvrir une
  seconde carte d’application dans le sélecteur iOS.
- [ ] Une URL Naver courte ou redirigée réelle résout le bon nom, la bonne
  adresse et une coordonnée cohérente avec le lieu affiché par Naver.
- [ ] Le formulaire ne permet pas de publier sans catégorie ni avec une date
  hors des prochaines 24 heures.
- [ ] Une publication crée exactement un nouvel événement Firestore avec les
  champs stricts existants et aucun doublon après double-tap.
- [ ] Après succès, l’extension se ferme ; en ouvrant ensuite Wander,
  l’événement apparaît au bon endroit sur la carte.
- [ ] Une URL ambiguë, un texte vide, une absence de réseau et une session
  expirée produisent chacun un état explicite, annulable ou réessayable.
- [ ] Le formulaire est vérifié en Dynamic Type, VoiceOver, modes clair/sombre
  et avec Réduire les animations.
- [x] Les tests complets des règles Firestore et des Cloud Functions réussissent.
- [x] Les quatre notes Wander sont vérifiées en mode Aperçu dans Obsidian.
- [x] Aucun contenu partagé, adresse, coordonnée, token ou UID n’apparaît dans
  les logs.
- [x] Aucun déploiement, commit ou modification distante n’est exécuté.

### Résultats automatisés du 17 août 2026

- `plutil` valide le projet Xcode, les deux `Info.plist` et les deux fichiers
  d’entitlements.
- Le build Debug du scheme `wander`, qui embarque `WanderShareExtension`,
  réussit pour la destination générique iOS Simulator avec la résolution de
  paquets figée et sans nouvel avertissement Swift.
- La suite des règles Firestore réussit : 30 tests sur 30.
- La suite des Cloud Functions réussit : 26 tests sur 26, avec le scénario
  d’intégration déjà déclaré `skip`.
- La revue initiale ne trouvait aucun log ni finding non résolu avant les essais
  réels sur appareil ; la revue post-correctifs du 18 août ci-dessous la
  remplace pour l’état courant.
- Les quatre notes Wander affichent leurs nouvelles propriétés, sections,
  listes et tableaux correctement en mode Aperçu dans Obsidian.
- Les critères liés à la signature, à la session partagée, au payload Naver et
  à l’accessibilité restent volontairement ouverts jusqu’au test physique.

### Correctif appareil du 17 août 2026

- Le premier essai réel faisait apparaître Wander dans la feuille Naver, puis
  l’extension se fermait immédiatement sans créer d’événement.
- Le crash log système `WanderShareExtension-2026-08-17-165841.ips` confirme un
  `SIGABRT` dans `FIRFirestore.firestore()` depuis
  `ShareComposerView.init` : le publisher Firestore était construit avant le
  bootstrap `FirebaseApp.configure()` de l’extension.
- `OutingPlanPublisher` est désormais construit seulement au moment de publier,
  après la réussite du bootstrap Firebase et de la session partagée.
- Le build Debug complet du scheme `wander` réussit après ce correctif, sans
  avertissement ni erreur.
- Le nouvel essai sur l’iPhone confirme que le compositeur reste ouvert. La
  résolution échouait ensuite avec `MKErrorDomain` code 4.
- Le payload réel communiqué contient le nom, l’adresse et l’URL courte
  `naver.me`. Sa première redirection HTTP expose directement `lat`, `lng` et
  `title`, mais le suivi automatique atteignait ensuite une page Naver qui ne
  conservait plus ces paramètres.
- Le résolveur intercepte désormais chaque redirection avant de la suivre,
  utilise immédiatement les coordonnées trouvées et conserve le nom et
  l’adresse du texte partagé au lieu de dépendre d’une recherche Apple Plans.
- Le build Debug complet du scheme `wander` réussit après ce second correctif.
- Un nouvel essai sur l’iPhone reste requis pour confirmer l’affichage du lieu
  et la publication Firestore de bout en bout.

### Revue post-correctifs du 18 août 2026

La revue statique ciblée ne relève aucun nouveau problème de signature,
d’entitlements, d’appartenance de target, de contrat Firestore ou de fuite de
données dans les logs. Elle ouvre quatre findings avant clôture du sprint :

- `todos/015-ready-p1-valider-resultat-recherche-lieu-partage.md` — le premier
  résultat global de `MKLocalSearch` est accepté sans preuve suffisante.
- `todos/016-ready-p2-borner-resolution-redirections-partage.md` — les requêtes
  `GET` de redirection peuvent charger un corps arbitrairement volumineux dans
  le processus d’extension.
- `todos/017-ready-p2-gerer-publication-confirmee-relecture-echouee.md` — une
  écriture Firestore réussie suivie d’une relecture échouée est présentée comme
  un échec total.
- `todos/018-ready-p2-normaliser-erreurs-extension-partage.md` — certaines
  erreurs système sont encore affichées directement à l’utilisateur.

La validation appareil et la résolution du finding P1 restent nécessaires
avant de marquer le sprint `completed`.

## Acceptance criteria

- Wander est sélectionnable directement depuis la feuille de partage d’un lieu
  Naver sur l’iPhone de validation.
- Le lieu est résolu et présenté sans recherche manuelle sur la carte Wander.
- La catégorie et l’heure peuvent être choisies dans une interface native qui
  ressemble au parcours Wander existant.
- La publication est effectuée depuis l’extension avec la session Wander déjà
  ouverte, sans ressaisie de connexion.
- Un partage valide crée un seul événement au bon point et le rend visible dans
  Wander.
- Les échecs ne publient rien à une coordonnée supposée et donnent une action
  compréhensible.
- L’implémentation reste conforme au modèle Share Extension : aucun lancement
  forcé de l’app conteneur ni API privée.

## Approval gate

Le propriétaire a explicitement approuvé ce plan le 17 août 2026. Toute
modification matérielle du périmètre ou de l’approche nécessite une nouvelle
approbation avant mise en œuvre.

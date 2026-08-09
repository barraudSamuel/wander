# Concepts

Shared domain vocabulary for this project — entities, named processes, and status concepts with project-specific meaning. Seeded with core domain vocabulary, then accretes as ce-compound and ce-compound-refresh process learnings; direct edits are fine. Glossary only, not a spec or catch-all.

## Social exploration

### Ami accepté
Une personne dont la relation d’amitié avec l’utilisateur courant est dans l’état accepté, ce qui autorise les fonctions sociales de Wander tant que cette relation reste active.

### Présence d’ami
La position récemment partagée d’un Ami accepté, accompagnée des informations temporelles nécessaires pour décider si elle est encore utilisable.

Une Présence d’ami cesse d’être disponible lorsqu’elle expire, lorsque son partage disparaît ou lorsque l’amitié est révoquée ; une vue déjà ouverte ne prolonge pas sa validité.

## Exploration cartographique

### Exploration
L’ensemble cumulatif des zones de carte révélées par une personne au fil de ses déplacements.

Une Exploration vide après chargement est une valeur valide et reste distincte d’une Exploration qui n’a pas encore été chargée.

### Ville prise en charge
Une ville pour laquelle Wander possède les limites et les zones nécessaires au calcul d’une progression locale.

### Progression urbaine
La part des zones d’une Ville prise en charge qui appartient à l’Exploration d’une personne.

La Progression urbaine dépend à la fois d’une Exploration chargée, d’une position disponible et des données de la ville ; son indisponibilité ne signifie pas une progression de zéro.

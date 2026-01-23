# Plan d'Action 02 : Transition vers v0.26 (Tags & Sécurité Création)

## Objectif
S'adapter aux changements de la v0.26 (isolation des tags) et sécuriser la création d'utilisateurs pour éviter les collisions de tags dans un environnement potentiellement multi-domaine.

## Comparaison avec le code actuel
*   **Tags** : Actuellement, `normalizeUserName` transforme `User@domaine.com` en `user`. Si `User@autre.com` est créé, les deux auront le même tag `tag:user-client`, créant un conflit ACL.
*   **Création** : `CreateUserDialog` ajoute le suffixe mais ne vérifie pas si le nom (ou sa version normalisée) existe déjà.

## Éléments à modifier (Certitude)
- [x] **`lib/widgets/create_user_dialog.dart`** : 
    *   Récupérer la liste des utilisateurs existants avant la création.
    *   Vérifier si le nouveau nom (une fois normalisé) existe déjà.
    *   Afficher un Warning si un doublon est détecté et suggérer un renommage (ex: `user1`, `user2`).
- [x] **`lib/models/node.dart`** : Modifier le `fromJson` pour supporter les champs snake_case (`forced_tags`, `valid_tags`) car la v0.27+ semble les utiliser en plus du camelCase.

## Éléments à vérifier (Incertitude)
- [x] **Impact OIDC** : Discussion effectuée. La vérification à la création dans l'app couvre l'usage manuel.
- [x] **Groupement Dashboard** : Confirmé par le test CLI, Headscale v0.27 continue de renvoyer l'objet `user` même pour les nœuds tagués. Le groupement actuel reste donc fonctionnel.

## Étapes de réalisation
- [x] **Étape 1** : Mettre à jour le modèle `Node` pour assurer la lecture des tags sur toutes les versions (v0.25 à v0.28).
- [x] **Étape 2** : Implémenter la logique de détection de collision dans `CreateUserDialog`.
- [x] **Étape 3** : Ajouter l'affichage de l'alerte et la suggestion de nom automatique dans l'UI.
- [x] **Étape 4** : Tests de création avec des noms provoquant des collisions (ex: `Alice@abc.com` vs `alice@xyz.com`).

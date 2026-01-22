# Plan d'Action 04 : Transition vers v0.28 (Sécurité & Simplification)

## Objectif
Migrer vers l'API par ID pour les clés et gérer la suppression de l'endpoint de déplacement de nœuds.

## Comparaison avec le code actuel
*   **Clés** : Actuellement identifiées par `user` + `key`. La v0.28 utilise un `id` numérique unique.
*   **Mouvement** : L'app permet de déplacer un nœud entre utilisateurs. Cette fonction est supprimée en v0.28.

## Éléments à modifier (Certitude)
- [ ] **`lib/models/pre_auth_key.dart`** : Ajouter et parser le champ `id`.
- [ ] **`lib/api/headscale_api_service.dart`** : Adapter `expirePreAuthKey` pour utiliser l' `id` si `serverVersion >= 0.28.0`.
- [ ] **`lib/screens/node_detail_screen.dart`** : Masquer le bouton de déplacement si `serverVersion >= 0.28.0`.

## Éléments à vérifier (Incertitude)
*   **Listing global** : Confirmer que l'appel global `/api/v1/preauthkey` est suffisant sans itérer sur chaque utilisateur en v0.28.
*   **Formats de clés** : Vérifier l'affichage des nouveaux formats `hskey-auth-...` dans la liste.

## Étapes de réalisation
- [ ] Mettre à jour le modèle `PreAuthKey` avec son `id`.
- [ ] Implémenter la logique conditionnelle dans `HeadscaleApiService` pour l'expiration des clés.
- [ ] Refactoriser `getPreAuthKeys` pour supprimer la boucle sur les utilisateurs si v0.28 détectée.
- [ ] Masquer les fonctionnalités obsolètes (Move Node) dans l'interface.

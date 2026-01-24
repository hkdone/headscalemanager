# Plan d'Action 04 : Transition vers v0.28 (Sécurité & Simplification)

## Objectif
Migrer vers l'API par ID pour les clés et gérer la suppression de l'endpoint de déplacement de nœuds.

## Comparaison avec le code actuel
*   **Clés** : Actuellement identifiées par `user` + `key`. La v0.28 utilise un `id` numérique unique.
*   **Mouvement** : L'app permet de déplacer un nœud entre utilisateurs. Cette fonction est supprimée en v0.28.

## Éléments à modifier (Certitude)
- [x] **`lib/models/pre_auth_key.dart`** : 
    *   Ajouter le champ `id` (String?, nullable).
    *   Dans `fromJson`, parser `id` si présent.
- [x] **`lib/api/headscale_api_service.dart`** : 
    *   **PreAuthKeys** : 
        *   Si `serverVersion >= 0.28` : Appeler `GET /preauthkey` (global) et filtrer par `user.id` côté client.
        *   Sinon : Garder la boucle actuelle sur `GET /preauthkey?user=ID`.
    *   **Expiration** :
        *   Si `id` est présent (v0.28+) : Utiliser `POST /preauthkey/expire` avec `{id: ...}`.
        *   Sinon (Legacy/v0.27) : Utiliser `POST /preauthkey/expire` avec `{user: ..., key: ...}`.
- [x] **`lib/screens/node_detail_screen.dart`** et **`lib/screens/user_detail_screen.dart`** : 
    *   Récupérer la version via `context.read<AppProvider>().serverVersion`.
    *   Condition : Si `>= 0.28.0`, ne pas afficher l'option "Changer d'utilisateur".

## Stratégie d'Adaptation (Clés)
L'objectif est de ne pas casser l'existant pour les utilisateurs en v0.27 ou ceux qui migrent (clés existantes non expirées).
1.  **Modèle Hybride** : Le modèle `PreAuthKey` supportera à la fois `id` (nouveau) et l'ancienne méthode.
2.  **Hashing / Migration** :
    *   **Clés existantes (Legacy)** : Elles restent en clair (`{secret}`) et continuent de fonctionner jusqu'à expiration. Elles ne sont **PAS** converties automatiquement au nouveau format `hskey-auth`.
    *   **Nouvelles clés (v0.28)** : Sont générées au format haché (`hskey-auth-`). Seul le préfixe est visible après création.
3.  **Affichage** :
    *   Si la clé commence par `hskey-auth-`, afficher "Prefix: hskey-auth-..." (nouveau format sécurisé).
    *   Sinon, afficher la clé complète (si disponible, comportement legacy).
4.  **Actions** :
    *   Le bouton "Expirer" choisira intelligemment la méthode API en fonction de la présence de l'ID.

## Éléments à vérifier (Incertitude)
*   **Endpoint Expire v0.28** : Vérifier si `POST /preauthkey/expire` accepte bien `{id: "..."}` ou si c'est une autre route. (Documentation suggère ID replacement).

## Étapes de réalisation
- [x] Mettre à jour `PreAuthKey.dart` (ajout `id`).
- [x] Mettre à jour `HeadscaleApiService.dart` (logique conditionnelle version).
- [x] Mettre à jour l'UI des clés (affichage préfixe vs full key).
- [x] Mettre à jour `UserDetailScreen` (masquer Move Node).

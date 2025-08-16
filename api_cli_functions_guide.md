# Guide des Fonctions API et CLI de HeadscaleManager

Ce document a pour but de clarifier les interactions de l'application HeadscaleManager avec votre serveur Headscale, en distinguant les opérations qui utilisent directement l'API REST de Headscale de celles qui génèrent des commandes CLI (Command Line Interface) à exécuter manuellement.

## 1. Fonctions utilisant directement l'API REST de Headscale

Ces fonctions sont exécutées en arrière-plan par l'application. Elles communiquent directement avec votre serveur Headscale via son API REST. Les résultats sont traités et affichés dans l'interface utilisateur de l'application.

**Fichier : `lib/api/headscale_api_service.dart`**

*   `getNodes()`: Récupère tous les nœuds enregistrés.
*   `getNodeDetails(String nodeId)`: Récupère les détails d'un nœud spécifique.
*   `registerMachine(String machineKey, String userName)`: Enregistre une nouvelle machine pour un utilisateur.
*   `getUsers()`: Récupère tous les utilisateurs.
*   `createUser(String name)`: Crée un nouvel utilisateur.
*   `createPreAuthKey(String userId, bool reusable, bool ephemeral, {DateTime? expiration})`: Crée une clé de pré-authentification.
*   `getAclPolicy()`: Récupère la politique ACL actuelle.
*   `setAclPolicy(Map<dynamic, dynamic> aclMap)`: Définit la politique ACL.
*   `deleteUser(String userId)`: Supprime un utilisateur.
*   `deleteNode(String nodeId)`: Supprime un nœud.
*   `setNodeRoutes(String nodeId, List<String> routes)`: Définit les routes pour un nœud.
*   `renameNode(String nodeId, String newName)`: Renomme un nœud.
*   `moveNode(String nodeId, String userName)`: Déplace un nœud vers un autre utilisateur.
*   `setMachineTags(String machineId, List<String> tags)`: Définit les tags pour une machine.
*   `getPreAuthKeys()`: Récupère toutes les clés de pré-authentification.
*   `deletePreAuthKey(String keyId)`: Supprime une clé de pré-authentification.

## 2. Fonctions générant des Commandes CLI pour exécution manuelle

Ces fonctions ne modifient pas directement votre serveur Headscale. Elles construisent une chaîne de commande que vous devez copier et exécuter manuellement dans un terminal où la CLI `headscale` ou `tailscale` est installée et configurée.

*   **Dans `lib/screens/users_screen.dart`:**
    *   **`_showCreatePreAuthKeyDialog`**: Après la création d'une clé de pré-authentification via l'API, cette fonction génère la commande `tailscale up --login-server=... --authkey=...` complète.
        *   **Quand l'utiliser :** Pour enregistrer un nouveau nœud Tailscale en utilisant la clé de pré-authentification générée.
        *   **Action requise :** Copiez la commande affichée et exécutez-la sur la machine que vous souhaitez enregistrer.

*   **Dans `lib/screens/node_detail_screen.dart`:**
    *   **`_showEditTagsDialog`**: Cette fonction génère une commande `headscale nodes tag -i <node_id> -t "tag:..."` pour modifier les tags d'un nœud.
        *   **Quand l'utiliser :** Pour appliquer ou modifier les tags d'un nœud Headscale existant.
        *   **Action requise :** Copiez la commande affichée et exécutez-la sur votre serveur Headscale (ou sur une machine ayant accès à la CLI `headscale` et à votre configuration).

## 3. Guide pour l'Administrateur de l'Application

En tant qu'administrateur de l'application HeadscaleManager, il est important de comprendre la distinction entre les opérations API et CLI pour une gestion efficace et un dépannage précis.

*   **Opérations API (Section 1) :**
    *   **Nature :** Ces actions sont automatiques et se reflètent immédiatement (ou après un court délai de rafraîchissement) dans l'application.
    *   **Dépannage :** Si une opération API échoue (par exemple, un utilisateur n'est pas créé, un nœud n'apparaît pas), vérifiez les logs de l'application (si disponibles) et les logs de votre serveur Headscale pour des messages d'erreur détaillés. Assurez-vous que votre clé API et l'URL du serveur sont correctement configurées dans les paramètres de l'application.

*   **Opérations CLI (Section 2) :**
    *   **Nature :** Ces actions nécessitent une intervention manuelle. L'application vous fournit l'outil (la commande), mais l'exécution et la vérification du succès se font en dehors de l'application.
    *   **Dépannage :**
        *   **"500 Not Found" ou "user not found" lors de la génération de clé :** Si vous rencontrez des erreurs lors de la *génération* de la clé (avant même de copier la commande CLI), cela indique un problème avec la communication API (voir Section 1) ou la configuration de votre serveur Headscale.
        *   **Problèmes après exécution de la commande CLI :** Si la commande CLI ne fonctionne pas comme prévu (par exemple, le nœud ne s'enregistre pas, les tags ne sont pas appliqués), vérifiez :
            *   Que vous avez copié la commande *exactement* telle qu'elle est affichée.
            *   Que la CLI `headscale` ou `tailscale` est correctement installée et configurée sur la machine où vous exécutez la commande.
            *   Les messages d'erreur dans votre terminal après l'exécution de la commande.
            *   Les logs de votre serveur Headscale.
            *   Que le nœud ou l'utilisateur concerné existe et est dans un état valide.
    *   **Mise à jour de l'application :** Après avoir exécuté une commande CLI qui modifie l'état de votre serveur Headscale (comme l'enregistrement d'un nœud ou la modification de tags), vous devrez peut-être rafraîchir manuellement l'écran pertinent dans l'application HeadscaleManager pour voir les changements reflétés.

En comprenant ces distinctions, vous serez mieux équipé pour utiliser et dépanner l'application HeadscaleManager efficacement.
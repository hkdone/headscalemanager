# Résumé du Projet HeadscaleManager

Ce document récapitule les travaux effectués sur l'application HeadscaleManager, les fichiers clés impliqués, et le fonctionnement détaillé de ses fonctionnalités principales.

## Vue d'ensemble de l'application

HeadscaleManager est une application mobile (Flutter) conçue pour faciliter la gestion d'un serveur Headscale. Elle permet aux utilisateurs d'interagir avec leur instance Headscale via son API REST, offrant une interface conviviale pour des tâches telles que la gestion des nœuds (appareils), des utilisateurs et des politiques de contrôle d'accès (ACL).

## Fonctionnalités Clés

### Gestion des Nœuds et Utilisateurs
*   Visualisation de la liste des utilisateurs et de leurs nœuds respectifs.
*   Affichage des détails des nœuds, incluant les adresses IP, le statut, les routes partagées et les tags.
*   Création de clés de pré-authentification pour l'enregistrement de nouveaux nœuds.
*   Interface pour l'édition des tags des nœuds via la génération de commandes CLI `headscale`.

### Gestion des Politiques ACL (Access Control List)

La gestion des ACL a été entièrement revue pour s'adapter au comportement spécifique de l'instance Headscale cible. La nouvelle approche est basée exclusivement sur les **tags**.

*   **Principe Fondamental du "Tout-Tag" :** Le fonctionnement repose sur une règle simple mais stricte : **pour qu'un nœud puisse communiquer, il doit obligatoirement avoir au moins un tag**. Un nœud qui n'est pas tagué sera, par défaut, isolé du réseau une fois la politique appliquée.

*   **Bouton "Générer la configuration de base" :** Le bouton sur l'écran ACL (`AclScreen`) est le cœur de cette fonctionnalité. Il ne génère pas un modèle statique, mais inspecte l'ensemble de vos nœuds et génère dynamiquement une politique ACL complète et fonctionnelle basée sur les tags existants.
    1.  Il identifie tous les tags appartenant à un utilisateur donné.
    2.  Il génère une règle de "flotte" qui autorise tous les tags d'un même utilisateur à communiquer librement entre eux.
    3.  Il étend cette règle pour donner à la flotte l'accès à toutes les ressources partagées par ses membres (sous-réseaux et exit nodes).
    4.  Il génère des règles spécifiques pour les nœuds "routeurs" (ceux avec des tags fournissant des routes ou un service d'exit node), leur donnant explicitement la permission de communiquer avec la flotte de l'utilisateur et de contacter les destinations qu'ils partagent.

*   **Abandon des Alias d'Utilisateurs/Groupes dans les Règles :** Suite à un débogage approfondi, il a été déterminé que la version de Headscale utilisée interprétait mal les règles de communication basées sur les alias d'utilisateurs (ex: `jean@...`) ou les groupes (`group:jean@...`) dès que des tags étaient présents. La logique actuelle n'utilise donc que les **tags** comme source (`src`) et destination (`dst`) dans les règles de communication, ce qui garantit un fonctionnement stable et prévisible.

## Fichiers Clés

*   `lib/screens/acl_screen.dart` : Contient toute la logique de génération de la politique ACL "tout-tag".
*   `lib/screens/node_detail_screen.dart` : Permet de visualiser les informations d'un nœud et de générer la commande pour modifier ses tags.
*   `lib/models/node.dart` / `lib/models/user.dart` : Modèles de données pour les objets retournés par l'API Headscale.
*   `lib/api/headscale_api_service.dart` : Service de communication avec l'API REST de Headscale.
*   `project_summary.md` : Ce document.
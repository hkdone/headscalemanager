# Résumé du Projet : HeadscaleManager

Ce document synthétise l'application HeadscaleManager, ses fonctionnalités principales, son architecture et ses fichiers clés.

## 1. Vue d'ensemble de l'application

HeadscaleManager est une application mobile développée avec Flutter, conçue pour offrir une interface graphique conviviale pour la gestion d'un serveur Headscale. Elle interagit avec l'API REST de Headscale pour permettre la gestion des nœuds, des utilisateurs, des clés de pré-authentification et des politiques de contrôle d'accès (ACL).

## 2. Architecture

L'application s'appuie sur une architecture simple et efficace utilisant le package `provider` pour la gestion de l'état.

- **`lib/providers/app_provider.dart`** : Sert de hub central pour l'accès aux services principaux. Il fournit des instances de `HeadscaleApiService` (pour les interactions API) et `StorageService` (pour le stockage local sécurisé).

- **`lib/api/headscale_api_service.dart`** : Gère toute la communication avec l'API REST de Headscale. Cette classe est responsable de l'authentification, de la construction des requêtes et de la gestion des réponses pour toutes les opérations (nœuds, utilisateurs, clés, ACLs).

- **`lib/services/storage_service.dart`** : Utilise `flutter_secure_storage` pour stocker de manière sécurisée les informations sensibles, telles que l'URL du serveur Headscale et la clé d'API.

## 3. Fonctionnalités principales

### 3.1. Connexion et Configuration

- **Écran de démarrage (`lib/screens/splash_screen.dart`)** : Vérifie la présence des identifiants de connexion. Si les informations sont présentes, l'application navigue vers l'écran d'accueil ; sinon, elle redirige l'utilisateur vers l'écran de configuration.

- **Écran des paramètres (`lib/screens/settings_screen.dart`)** : Permet aux utilisateurs de saisir et de sauvegarder l'URL de leur serveur Headscale et leur clé d'API.

### 3.2. Tableau de Bord et Nœuds

- **Tableau de bord (`lib/screens/dashboard_screen.dart`)** : Offre une vue d'ensemble de l'état du réseau avec des indicateurs clés :
    - Nombre total d'utilisateurs.
    - Nombre de nœuds actuellement en ligne.
    - Nombre de nœuds déconnectés.
- Affiche une liste des nœuds regroupés par utilisateur, avec un indicateur de statut (en ligne/hors ligne). Chaque groupe peut être déplié pour voir les détails.

### 3.3. Détails et Actions sur les Nœuds

- **Écran de détail (`lib/screens/node_detail_screen.dart`)** : Fournit des informations complètes sur un nœud sélectionné, y compris son nom d'hôte, son FQDN (avec un bouton de copie), ses adresses IP, les routes annoncées et ses tags.

- **Outil de Ping Avancé** : Une fonctionnalité de diagnostic réseau a été intégrée :
    - **Ping simple** : Lance 5 pings et affiche un résumé avec la latence moyenne et le pourcentage de paquets perdus.
    - **Ping en continu** : Un interrupteur permet de lancer un ping en temps réel, affichant un journal des réponses et des statistiques qui se mettent à jour dynamiquement. Le processus s'arrête automatiquement lorsque l'on quitte la page.

### 3.4. Gestion des Utilisateurs

- **Écran des utilisateurs (`lib/screens/users_screen.dart`)** : Affiche la liste de tous les utilisateurs Headscale. Permet de créer de nouveaux utilisateurs et de supprimer des utilisateurs existants via des dialogues dédiés.

### 3.5. Gestion des Clés de Pré-authentification

- **Écran dédié (`lib/screens/pre_auth_keys_screen.dart`)** : Bien qu'un dialogue de création soit accessible depuis l'écran des utilisateurs, un écran dédié pourrait être envisagé pour lister, créer et supprimer les clés de manière centralisée.
- **Création de clés** : Un dialogue (`lib/widgets/create_pre_auth_key_dialog.dart`) permet de créer des clés de pré-authentification en spécifiant l'utilisateur, la réutilisabilité, le statut éphémère et une date d'expiration.

### 3.6. Gestion des Politiques ACL

- **Écran ACL (`lib/screens/acl_screen.dart`)** : Permet de gérer la politique de contrôle d'accès.
    - **Visualisation et Édition** : Affiche la politique ACL actuelle dans un champ de texte éditable au format JSON.
    - **Génération automatique** : Une fonctionnalité clé permet de générer une politique ACL complète basée sur le principe du "Tag-Everything". Le service `AclGeneratorService` analyse tous les utilisateurs, nœuds et tags pour créer des règles autorisant la communication entre les nœuds d'un même utilisateur et l'accès aux ressources partagées (subnets, exit nodes).
    - **Partage** : Permet de partager la politique ACL générée sous forme de fichier JSON.

## 4. Fichiers Clés

- `lib/main.dart`: Point d'entrée de l'application.
- `lib/api/headscale_api_service.dart`: Cœur de la communication avec l'API Headscale.
- `lib/providers/app_provider.dart`: Fournisseur d'état central.
- `lib/services/storage_service.dart`: Service de stockage sécurisé.
- `lib/services/acl_generator_service.dart`: Logique de génération de la politique ACL.
- `lib/screens/home_screen.dart`: Navigation principale de l'application.
- `lib/screens/dashboard_screen.dart`: Vue d'ensemble des nœuds et des indicateurs.
- `lib/screens/node_detail_screen.dart`: Détails et outils de diagnostic pour un nœud.
- `lib/screens/users_screen.dart`: Gestion des utilisateurs.
- `lib/screens/acl_screen.dart`: Gestion des politiques ACL.
- `project_summary.md`: Ce document.

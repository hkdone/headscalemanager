# Résumé du Projet : HeadscaleManager

Ce document synthétise l'application HeadscaleManager, ses fonctionnalités principales, son architecture et ses fichiers clés.

## 1. Vue d'ensemble de l'application

HeadscaleManager est une application mobile développée avec Flutter, conçue pour offrir une interface graphique conviviale pour la gestion d'un serveur Headscale. Elle interagit avec l'API REST de Headscale pour permettre une gestion complète des nœuds, des utilisateurs, des clés de pré-authentification, des clés d'API et des politiques de contrôle d'accès (ACL).

L'application intègre également des fonctionnalités avancées telles que la surveillance en arrière-plan avec des notifications et des outils de diagnostic réseau.

## 2. Architecture

L'application s'appuie sur une architecture claire et maintenable utilisant le package `provider` pour la gestion de l'état et la localisation des services.

- **`lib/providers/app_provider.dart`**: Agit comme le cœur de l'application. C'est un `ChangeNotifier` qui instancie et fournit un accès aux services singleton `HeadscaleApiService` et `StorageService` à l'ensemble de l'arbre de widgets. Il gère également des états globaux comme l'indicateur de chargement (`isLoading`) et la locale de l'application.

- **`lib/api/headscale_api_service.dart`**: Cette classe fonctionne comme un "Repository", encapsulant toute la communication avec l'API REST de Headscale. Elle gère l'authentification (en récupérant la clé API via le `StorageService`), la construction des requêtes, la gestion des réponses et la désérialisation JSON.

- **`lib/services/storage_service.dart`**: Ce service abstrait la couche de persistance en utilisant `flutter_secure_storage` pour stocker de manière sécurisée les informations sensibles (URL du serveur et clé API).

- **`lib/models/*.dart`**: Le répertoire contient des classes de modèle de données immuables (ex: `Node`, `User`, `PreAuthKey`). Ces classes ne sont pas de simples conteneurs de données ; elles intègrent une logique métier cruciale dans leurs constructeurs `fromJson` pour transformer les données brutes de l'API en objets Dart typés et exploitables.

- **`lib/services/notification_service.dart`**: Utilise les packages `workmanager` et `flutter_local_notifications` pour exécuter des tâches en arrière-plan. Celles-ci vérifient périodiquement l'état des nœuds (changements de statut, demandes d'approbation de routes) et envoient des notifications locales à l'utilisateur.

- **`lib/screens/` et `lib/widgets/`**: Les écrans (`screens`) représentent les différentes pages de l'application. Ils utilisent les services fournis par `AppProvider` pour récupérer et afficher les données. Ils emploient des `FutureBuilder` ou une logique interne aux `StatefulWidget` pour gérer les états de chargement et d'erreur. Les `widgets` sont des composants d'interface utilisateur réutilisables, promouvant la modularité.

## 3. Fonctionnalités principales

### 3.1. Connexion et Configuration
- **`splash_screen.dart`**: Vérifie la présence des identifiants. Si absents, redirige vers l'écran de configuration.
- **`settings_screen.dart`**: Permet de saisir et sauvegarder l'URL du serveur et la clé API. Offre aussi la gestion de la langue (Français/Anglais) et l'activation des notifications en arrière-plan.

### 3.2. Tableau de Bord et Nœuds
- **`dashboard_screen.dart`**: Affiche une vue d'ensemble du réseau avec des indicateurs sur les utilisateurs et le statut des nœuds. Une fonctionnalité clé ici est la **gestion automatisée des approbations** : des icônes d'avertissement apparaissent pour les nœuds nécessitant une approbation de route ou un nettoyage, permettant à l'utilisateur d'approuver les routes, de mettre à jour les tags et de régénérer les ACLs en un seul clic.

### 3.3. Gestion des Utilisateurs
- **`users_screen.dart`**: Affiche une grille des utilisateurs. Permet de créer de nouveaux utilisateurs et de les supprimer.
- **`user_detail_screen.dart`**: Affiche les appareils (`Node`) appartenant à un utilisateur spécifique et permet d'enregistrer un nouvel appareil pour cet utilisateur.

### 3.4. Gestion des Clés
- **`api_keys_screen.dart`**: Interface pour lister, créer (avec une durée de validité) et supprimer les clés d'API du serveur Headscale.
- **`pre_auth_keys_screen.dart`**: Interface pour lister les clés de pré-authentification actives, en créer de nouvelles (réutilisables, éphémères, avec expiration et tags ACL) et les faire expirer. Affiche la commande `tailscale up` correspondante avec un QR code pour une configuration facile.

### 3.5. Gestion des Politiques ACL
- **`acl_screen.dart`**: Permet la gestion manuelle et semi-automatique des ACLs.
    - **Génération de politique**: Un générateur (`new_acl_generator_service.dart`) crée une politique de base sécurisée qui isole les utilisateurs par défaut.
    - **Exceptions Manuelles**: Permet de créer des règles spécifiques pour autoriser la communication entre des nœuds d'utilisateurs différents, avec une gestion fine de l'accès aux sous-réseaux partagés (accès complet ou personnalisé par IP/port).
- **`acl_manager_screen.dart`**: Offre une vue graphique interactive (`GraphView`) de la topologie du réseau et des permissions définies par les ACLs, permettant de visualiser les flux de communication autorisés.

### 3.6. Outils Réseau
- **`network_overview_screen.dart`**: Outil de diagnostic qui affiche une carte du chemin réseau depuis un appareil sélectionné vers Internet, en identifiant l'utilisation d'un `exit node`. Il effectue également un ping sur les autres nœuds du réseau pour afficher leur latence.
- **`dns_screen.dart`**: Affiche la liste des enregistrements DNS "MagicDNS" pour chaque nœud (nom, FQDN, IPs), avec des options pour copier/partager les informations.
- **`client_commands_screen.dart`**: Fournit une bibliothèque de commandes CLI pour le client Tailscale, filtrables par plateforme et catégorie, avec des paramètres dynamiques pré-remplis.

## 4. Fichiers Clés

- `lib/main.dart`: Point d'entrée de l'application.
- `lib/providers/app_provider.dart`: Fournisseur d'état et de services central.
- `lib/api/headscale_api_service.dart`: Cœur de la communication avec l'API Headscale.
- `lib/services/storage_service.dart`: Stockage sécurisé des identifiants.
- `lib/services/new_acl_generator_service.dart`: Logique de génération des politiques ACL.
- `lib/services/notification_service.dart`: Gestion des tâches de fond et des notifications.
- `lib/screens/`: Contient tous les écrans principaux de l'application.
- `lib/models/`: Contient les modèles de données (`Node`, `User`, etc.).
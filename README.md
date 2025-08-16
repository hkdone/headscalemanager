# Headscale Manager

Une application mobile Flutter pour gérer un serveur Headscale auto-hébergé.

## Fonctionnalités

- **Tableau de bord :** Visualisez tous les nœuds connectés et leur statut (en ligne/hors ligne) en temps réel.
- **Gestion des utilisateurs :** Créez et gérez les utilisateurs de votre réseau Headscale.
- **Génération d'invitations :** Générez des clés de pré-authentification pour les nouveaux utilisateurs et partagez-les via un QR code ou un lien direct.
- **Gestion des ACLs :** Modifiez la politique de contrôle d'accès (ACL) de votre serveur directement depuis l'application.
- **Sécurité :** La clé d'API et l'URL de votre serveur sont stockées de manière sécurisée sur votre appareil à l'aide de `flutter_secure_storage`.

## Architecture

L'application est construite autour d'une architecture simple et modulaire :

- `main.dart`: Point d'entrée de l'application, initialise le `ChangeNotifierProvider` pour la gestion d'état.
- `lib/services/`
  - `storage_service.dart`: Gère le stockage et la récupération sécurisés de l'URL du serveur et de la clé d'API.
  - `headscale_api_service.dart`: Contient toute la logique pour communiquer avec l'API REST de Headscale.
- `lib/models/`: Contient les classes de modèle de données (`User`, `Node`, `PreAuthKey`).
- `lib/providers/`: Contient le `AppProvider` qui expose les services à l'arbre de widgets.
- `lib/screens/`: Contient toutes les vues de l'application, séparées logiquement par fonctionnalité.
- `lib/widgets/`: (Optionnel) Pour les composants d'interface réutilisables.

La gestion d'état est assurée par le package `provider` pour notifier l'interface utilisateur des changements de données.

## Démarrage

### 1. Prérequis

- Un serveur Headscale fonctionnel.
- Une clé d'API Headscale. Vous pouvez en créer une avec la commande suivante sur votre serveur :
  ```sh
  headscale apikeys create
  ```

### 2. Configuration de l'application

Au premier lancement, l'application vous demandera de saisir l'URL de votre serveur Headscale (par exemple, `https://headscale.votre-domaine.com`) et la clé d'API que vous venez de créer.

### 3. Compilation et lancement

1.  Assurez-vous d'avoir le SDK Flutter installé.
2.  Clonez ce dépôt.
3.  Installez les dépendances :
    ```sh
    flutter pub get
    ```
4.  Lancez l'application :
    ```sh
    flutter run
    ```
# Plan d'Optimisation et de Fonctionnalités pour HeadscaleManager

Ce document détaille plusieurs axes d'amélioration pour l'application, en précisant les actions à entreprendre, les fichiers à modifier et les raisons de ces changements.

---

### 1. Journal d'Audit Local

*   **Quoi faire :** Créer une base de données SQLite locale pour enregistrer un journal des actions critiques effectuées par l'utilisateur. Chaque entrée de journal devrait contenir un horodatage, le type d'action (ex: 'CREATE', 'DELETE'), l'entité concernée (ex: 'USER', 'NODE'), et une description (ex: "Suppression du nœud 'mon-serveur'").

*   **Où le faire :**
    *   **Dépendances :** Ajouter les packages `sqflite` et `path` au fichier `pubspec.yaml`.
    *   **Service de base de données :** Créer un nouveau fichier `lib/services/audit_log_service.dart`. Ce service sera responsable d'initialiser la base de données et fournira des méthodes pour ajouter des entrées (ex: `logAction(String action, String description)`).
    *   **Intégration :**
        *   Instancier ce nouveau service dans `lib/providers/app_provider.dart` pour le rendre accessible globalement.
        *   Appeler la méthode `logAction` depuis `lib/api/headscale_api_service.dart` à la fin des fonctions qui modifient l'état du serveur, comme `deleteUser`, `deleteNode`, `createPreAuthKey`, `setAclPolicy`, etc.
    *   **UI (Optionnel) :** Créer un nouvel écran `lib/screens/audit_log_screen.dart` pour afficher les journaux, accessible via un nouveau bouton dans les paramètres ou sur le tableau de bord.

*   **Pourquoi :** Offrir une traçabilité complète des actions de gestion. Cela est crucial pour la sécurité, le débogage et la surveillance, en permettant de savoir qui a fait quoi et quand.

---

### 3. Sécurité d'Accès à l'Application

*   **Quoi faire :** Ajouter une option pour verrouiller l'application avec un code PIN ou une authentification biométrique (empreinte digitale, reconnaissance faciale).

*   **Où le faire :**
    *   **Dépendances :** Ajouter le package `local_auth` à `pubspec.yaml`.
    *   **Service de sécurité :** Créer un service `lib/services/security_service.dart` pour encapsuler la logique de `local_auth`. Il contiendrait des méthodes comme `isSecurityEnabled()` et `authenticate()`.
    *   **UI :**
        *   Ajouter un interrupteur dans `lib/screens/settings_screen.dart` pour que l'utilisateur puisse activer/désactiver cette fonctionnalité.
        *   Modifier le `lib/screens/splash_screen.dart` : après avoir vérifié la présence des identifiants (`hasCreds`), si la sécurité est activée, naviguer vers un nouvel écran de verrouillage (`lib/screens/lock_screen.dart`) qui demandera l'authentification avant de permettre l'accès à `HomeScreen`.

*   **Pourquoi :** Protéger l'accès à l'interface d'administration du serveur Headscale, même si l'appareil de l'utilisateur est déjà déverrouillé. C'est une mesure de sécurité fondamentale pour une application de ce type.

---

### 4. Interface Optimisée pour Tablette et Bureau

*   **Quoi faire :** Adapter l'interface pour mieux exploiter l'espace disponible sur les écrans plus grands (tablettes, web, bureau).

*   **Où le faire :**
    *   **Fichiers UI :** Principalement dans les écrans qui affichent des listes, comme `lib/screens/users_screen.dart`, `lib/screens/dashboard_screen.dart` ou `lib/screens/pre_auth_keys_screen.dart`.
    *   **Technique :** Utiliser le widget `LayoutBuilder`. Dans sa méthode `builder`, vérifier la contrainte de largeur (`constraints.maxWidth`).
        *   Si la largeur est **supérieure à un seuil** (ex: 600 pixels), afficher une `Row` avec deux `Expanded` : un pour la liste (vue maître) et un pour le contenu détaillé (vue détail).
        *   Si la largeur est **inférieure**, conserver la navigation actuelle (la `ListView` qui pousse une nouvelle page de détail).
    *   **Exemple pour `lib/screens/dashboard_screen.dart` :** Sur un grand écran, la liste des utilisateurs et de leurs nœuds serait à gauche. Cliquer sur un nœud ne naviguerait pas vers une nouvelle page, mais mettrait à jour le panneau de droite pour afficher le contenu de `NodeDetailScreen`.

*   **Pourquoi :** Améliorer l'ergonomie et la productivité sur les plateformes autres que les téléphones. Cela offre une expérience utilisateur plus riche et plus proche d'une application native de bureau.

---

### 5. Personnalisation du Tableau de Bord

*   **Quoi faire :** Permettre à l'utilisateur de réorganiser les cartes d'information sur l'écran d'accueil.

*   **Où le faire :**
    *   **Fichier UI :** `lib/screens/dashboard_screen.dart`.
    *   **Technique :** Remplacer la `ListView` (ou `Column`) principale par une `ReorderableListView`.
    *   **Persistance :** Utiliser `shared_preferences` (via le `StorageService` existant) pour sauvegarder l'ordre préféré de l'utilisateur. De nouvelles méthodes `saveDashboardOrder(List<String> order)` et `getDashboardOrder()` seraient à ajouter dans `lib/services/storage_service.dart`.
    *   **Logique :** Dans le `initState` de `DashboardScreen`, charger l'ordre sauvegardé, puis construire la liste de widgets en respectant cet ordre.

*   **Pourquoi :** Améliorer l'expérience utilisateur en lui donnant le contrôle sur la disposition des informations qu'il consulte le plus fréquemment.
# Plan de Refactorisation de la Haute Disponibilité (HA)

## Objectif Final

Centraliser toute la logique de basculement manuel (failover/takeover) dans un service unique, `HaFailoverService`, afin de supprimer la duplication de code, de simplifier la maintenance et d'assurer un comportement cohérent à travers l'application.

## Historique des Actions

1.  **Création du Service de Basculement :**
    *   Une nouvelle méthode, `performManualFailover`, a été ajoutée au fichier `lib/services/ha_failover_service.dart`.
    *   **Logique de la méthode :**
        1.  Trouve le nœud primaire actuel pour la route donnée.
        2.  Désactive la route sur l'ancien nœud primaire.
        3.  Active la route sur le nouveau nœud primaire (celui choisi par l'utilisateur).
        4.  Régénère la politique ACL complète en se basant sur le nouvel état des routes.
        5.  Applique la nouvelle politique ACL via l'API.

2.  **Première Refactorisation (Réussie) :**
    *   L'écran de gestion de la HA (`lib/screens/ha_management_screen.dart`) a été modifié.
    *   La méthode `_performHaReorder` a été mise à jour pour appeler `HaFailoverService.performManualFailover`.
    *   Cette modification a été un succès et a validé le bon fonctionnement de la logique centralisée.

## Problème Actuel

La tâche actuelle consiste à appliquer la même refactorisation à l'écran du **Dashboard** (`lib/screens/dashboard_screen.dart`).

*   **Complexité :** Ce fichier est très volumineux et contient deux méthodes distinctes qui implémentent une logique de basculement manuel :
    1.  `_showHaSwapDialog`: Utilisée pour forcer un basculement depuis un nœud **maître** vers un backup.
    2.  `_showHaTakeoverDialog`: Utilisée par un nœud **backup** pour prendre le contrôle d'une route.
*   **Échecs :** Mes tentatives de modification de ce fichier ont été refusées. La raison la plus probable est un conflit ou une désynchronisation du contenu du fichier, m'empêchant d'appliquer les changements correctement. L'utilisateur a demandé de procéder par étapes plus petites.

## Plan d'Action Détaillé (Prochaines Étapes)

Pour résoudre ce problème, je vais procéder de manière séquentielle et prudente.

### Étape 1 : Refactoriser `_showHaSwapDialog`

1.  **Lecture :** Relire le fichier `lib/screens/dashboard_screen.dart` pour garantir que je travaille sur la version la plus à jour.
2.  **Localisation :** Identifier le bloc de code `onPressed` du bouton "Confirmer" à l'intérieur de la méthode `_showHaSwapDialog`.
3.  **Remplacement :** Remplacer toute la logique manuelle de basculement (le bloc `try-catch` contenant les appels `setNodeRoutes` et la régénération des ACLs) par un appel unique :
    ```dart
    await HaFailoverService.performManualFailover(
      route: routeToSwap,
      newPrimaryNode: selectedBackup!,
      allNodes: allNodes,
      appProvider: appProvider,
    );
    ```
4.  **Validation :** Soumettre cette modification unique pour validation par l'utilisateur.

### Étape 2 : Refactoriser `_showHaTakeoverDialog`

1.  **Lecture :** (Si nécessaire) Relire `lib/screens/dashboard_screen.dart`.
2.  **Localisation :** Identifier le bloc de code `onPressed` du bouton "Oui" à l'intérieur de la méthode `_showHaTakeoverDialog`.
3.  **Remplacement :** Remplacer la logique manuelle de basculement par l'appel au service :
    ```dart
    await HaFailoverService.performManualFailover(
      route: routeToTakeover,
      newPrimaryNode: backupNode,
      allNodes: allNodes,
      appProvider: appProvider,
    );
    ```
4.  **Validation :** Soumettre cette seconde modification pour validation.

### Étape 3 : Finalisation

1.  Une fois les deux méthodes refactorisées et validées, la tâche sera terminée.
2.  La logique de basculement manuel sera entièrement centralisée dans `HaFailoverService`.

## Dépendances Clés

*   **Fichiers à modifier :** `lib/screens/dashboard_screen.dart`
*   **Service central :** `lib/services/ha_failover_service.dart`

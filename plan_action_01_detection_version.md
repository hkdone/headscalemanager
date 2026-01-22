# Plan d'Action 01 : Détection de la Version du Serveur

## Objectif
Permettre à l'application d'identifier la version du serveur Headscale pour adapter son comportement dynamiquement (hybridation).

## Comparaison avec le code actuel
*   **Actuel** : L'app ne connaît pas la version du serveur.
*   **Requis** : Un mécanisme pour appeler `/version` (endpoint PUBLIC), stocker le résultat et le rendre accessible globalement.

## Éléments à modifier (Certitude)
- [ ] **`lib/api/headscale_api_service.dart`** : Ajouter la méthode `getVersion()`. (Note: Pas besoin de header Authorization car l'endpoint est en dehors du subrouter protégé dans `app.go`).
- [ ] **`lib/providers/app_provider.dart`** : Ajouter `_serverVersion` et son getter. Récupérer la version à l'initialisation.
- [ ] **`lib/models/server.dart`** : Ajouter un champ `version` pour sauvegarder la version détectée de chaque serveur configuré.
- [ ] **`lib/screens/settings_screen.dart`** : Afficher la version du serveur actuellement sélectionné.
- [ ] **`lib/screens/server_list_screen.dart`** : Afficher la version à côté du nom/URL de chaque serveur dans la liste.

## Éléments à vérifier (Incertitude)
- [x] **Format exact de réponse** : Le JSON suit la structure `VersionInfo` avec le champ `version` à la racine (confirmé par `version.go`).
- [x] **Permissions API** : L'endpoint `/version` est **PUBLIC** et ne nécessite pas d'authentification (confirmé par `app.go`).
- [ ] **Anciennes versions** : L'endpoint `/version` existait-il déjà en v0.25 ?
- [ ] **Fallback** : Si `/version` renvoie 404, on utilisera "0.25.0" par défaut.

## Étapes de réalisation
- [ ] **Étape 1** : Créer le modèle Dart `VersionInfo` correspondant au JSON de Headscale.
- [ ] **Étape 2** : Implémenter `getVersion` dans `HeadscaleApiService` (appel GET simple).
- [ ] **Étape 3** : Modifier `Server` et `StorageService` pour persister la version.
- [ ] **Étape 4** : Intégrer la logique de détection automatique dans `AppProvider`.
- [ ] **Étape 5** : Mettre à jour l'UI des Paramètres.
- [ ] **Étape 6** : Mettre à jour l'UI de la Liste des Serveurs.
- [ ] **Étape 7** : Ajouter un test pour vérifier le comportement si le serveur est inaccessible.

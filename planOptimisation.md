# Plan for Multi-Server Management and Settings Screen Refactoring

This document outlines the plan to refactor the application to support multi-server management and to improve the settings screen.

## Phase 1: Core Refactoring with Data Migration

### 1. Create Server Model

*   **File:** `lib/models/server.dart`
*   **Action:** Create a new file with a `Server` class.
    ```dart
    class Server {
      final String id;
      final String name;
      final String url;
      final String apiKey;

      Server({
        required this.id,
        required this.name,
        required this.url,
        required this.apiKey,
      });

      // Add fromJson and toJson methods for serialization
    }
    ```

### 2. Refactor `StorageService` for Multi-Server and Migration

*   **File:** `lib/services/storage_service.dart`
*   **Action:**
    *   **Data Migration:**
        *   Create a new private method `_migrateToServerList()` that will be called during the `StorageService` initialization.
        *   This method will check for the old `HEADSCALE_SERVER_URL` and `HEADSCALE_API_KEY` keys.
        *   If found, it will create a `Server` object with a default name, save it as the first server in a new list, and then delete the old keys.
    *   **New Methods:**
        *   Replace `saveCredentials`, `getApiKey`, and `getServerUrl` with:
            *   `Future<List<Server>> getServers()`: Reads the list of servers from secure storage.
            *   `Future<void> saveServers(List<Server> servers)`: Saves the list of servers to secure storage.
            *   `Future<String?> getActiveServerId()`: Gets the ID of the active server.
            *   `Future<void> setActiveServerId(String serverId)`: Sets the active server.

### 3. Refactor `HeadscaleApiService`

*   **File:** `lib/api/headscale_api_service.dart`
*   **Action:**
    *   Remove the dependency on `StorageService`.
    *   Update the constructor to accept `url` and `apiKey` as required parameters.
    *   The `_getHeaders` and `_getBaseUrl` methods will now use the `url` and `apiKey` provided in the constructor.

### 4. Refactor `AppProvider`

*   **File:** `lib/providers/app_provider.dart`
*   **Action:**
    *   Add new state properties: `List<Server> servers`, `Server? activeServer`.
    *   On initialization, load the servers and the active server from `StorageService`.
    *   Instantiate `HeadscaleApiService` with the active server's credentials.
    *   Create a `switchServer(String serverId)` method that updates the `activeServer`, re-instantiates `HeadscaleApiService`, and calls `notifyListeners()`.

## Phase 2: UI for Server Management

### 1. Refactor Settings Screen

*   **File:** `lib/screens/settings_screen.dart`
*   **Action:**
    *   The existing form for URL and API key will be removed.
    *   A new `ServerList` widget will be created to display the list of servers.
    *   An "Add Server" button will be added, which will navigate to a new screen or show a dialog to add a new server.

### 2. Create Server Management UI

*   **New Files:**
    *   `lib/widgets/server_list_tile.dart`: A widget to display a single server in the list, with options to edit or delete.
    *   `lib/screens/add_edit_server_screen.dart`: A new screen for adding or editing a server configuration.
*   **Functionality:**
    *   The settings screen will display a list of servers using `ListView.builder`.
    *   Each server in the list will have a "Set Active" button.
    *   Each server will have an "Edit" and "Delete" button (delete will be disabled for the last server).
    *   The "Add Server" button will navigate to the `AddEditServerScreen`.

This plan ensures a robust and scalable implementation of the multi-server feature while maintaining data integrity for existing users.

# Project Summary: HeadscaleManager

This document summarizes the HeadscaleManager application, its core functionalities, architectural overview, and key files.

## Application Overview

HeadscaleManager is a Flutter mobile application designed to provide a user-friendly interface for managing a Headscale server. It interacts with the Headscale REST API to offer functionalities related to node, user, pre-authentication key, and Access Control List (ACL) policy management.

## Architectural Overview

The application follows a Provider-based state management pattern.

*   **`lib/main.dart`**: The application's entry point, responsible for setting up the `ChangeNotifierProvider` for `AppProvider` and defining the basic application theme. It navigates to `SplashScreen` initially.
*   **`lib/providers/app_provider.dart`**: Acts as a central hub for accessing core services. It provides instances of `HeadscaleApiService` (for API interactions) and `StorageService` (for secure local storage). It also manages a global loading state.
*   **`lib/api/headscale_api_service.dart`**: Handles all communication with the Headscale REST API. It includes methods for:
    *   Fetching and managing Tailscale nodes.
    *   Fetching and managing Headscale users.
    *   Creating and managing pre-authentication keys.
    *   Retrieving and setting ACL policies.
    It manages authentication headers and constructs API request URLs.
*   **`lib/services/storage_service.dart`**: Utilizes `flutter_secure_storage` to securely store sensitive information such as the Headscale API key and server URL. It provides methods for saving, retrieving, checking existence, and clearing these credentials.

## Core Functionalities

### 1. Authentication & Setup
*   **Splash Screen (`lib/screens/splash_screen.dart`)**: Checks for existing API credentials. If found, navigates to the main application (`HomeScreen`); otherwise, directs the user to the `SettingsScreen` for configuration.
*   **Settings Screen (`lib/screens/settings_screen.dart`)**: Allows users to configure the Headscale server URL and API key, and to clear saved credentials.

### 2. User Management (`lib/screens/users_screen.dart`)
*   Displays a list of all registered Headscale users.
*   Provides functionality to create new users.
*   Allows deletion of existing users.
*   Includes a dialog for generating pre-authentication keys for users.

### 3. Node Management (`lib/screens/dashboard_screen.dart` & `lib/screens/node_detail_screen.dart`)
*   **Dashboard**: Presents a grouped view of Tailscale nodes by their associated Headscale user. Each group can be expanded to show individual nodes.
*   **Node Details**: Provides detailed information about a selected node, including its online status, IP addresses, advertised routes, and tags.
*   **Node Actions**: Supports actions like renaming nodes, moving nodes between users, and setting machine tags.

### 4. Pre-Authentication Key Generation
*   Integrated within the `UsersScreen`, a dialog (`_showCreatePreAuthKeyDialog`) facilitates the creation of new pre-authentication keys.
*   Users can specify the associated user, reusability, ephemerality, and an optional expiration date for the key.
*   Upon successful creation, it provides the full `tailscale up` command, including the generated key, for easy node registration.

### 5. ACL Policy Management (`lib/screens/acl_screen.dart`)
The ACL management is designed around a "Tag-Everything" principle, where nodes must have at least one tag to communicate.

*   **Policy Display**: Shows the current ACL policy in a JSON editor.
*   **Dynamic Generation (`_initializeAcl`)**: A key feature that dynamically generates a comprehensive ACL policy based on existing users and their associated nodes and tags. This includes:
    *   Identifying all tags belonging to a given user.
    *   Generating "fleet" rules allowing communication between tags of the same user.
    *   Extending rules to grant access to user-owned resources (subnets, exit nodes).
    *   Generating specific rules for "router" nodes (those providing routes or exit node services).
*   **Rule Addition**: Allows adding individual ACL rules via a dedicated dialog (`AclGeneratorDialog`).
*   **Sharing**: Enables sharing the generated ACL policy as a JSON file.

## Key Files

*   `lib/main.dart`: Application entry point and root widget setup.
*   `lib/api/headscale_api_service.dart`: Handles all Headscale API calls.
*   `lib/models/user.dart`: Data model for Headscale users.
*   `lib/models/node.dart`: Data model for Tailscale nodes.
*   `lib/models/pre_auth_key.dart`: Data model for pre-authentication keys.
*   `lib/providers/app_provider.dart`: Central state management and service provider.
*   `lib/screens/splash_screen.dart`: Initial loading and credential check.
*   `lib/screens/home_screen.dart`: Main application navigation.
*   `lib/screens/settings_screen.dart`: Server configuration and credential management.
*   `lib/screens/users_screen.dart`: User listing, creation, deletion, and pre-auth key generation.
*   `lib/screens/dashboard_screen.dart`: Node listing and overview.
*   `lib/screens/node_detail_screen.dart`: Detailed node information and actions.
*   `lib/screens/acl_screen.dart`: ACL policy viewing, generation, and sharing.
*   `lib/services/storage_service.dart`: Secure local storage for credentials.
*   `lib/widgets/acl_generator_dialog.dart`: Dialog for generating individual ACL rules.
*   `project_summary.md`: This document.
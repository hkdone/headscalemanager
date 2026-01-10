# GEMINI.md - Headscale Manager

## Project Overview

This is a Flutter-based mobile application designed to manage a [Headscale](https.github.com/juanfont/headscale) server. Headscale is an open-source, self-hosted implementation of the Tailscale coordination server. The application provides a user-friendly interface to manage users, devices (nodes), ACLs (Access Control Lists), and other Headscale features directly from a mobile device or desktop.

The application is built with Flutter, allowing it to be compiled for various platforms including Android, iOS, macOS, Web, and Windows. It interacts with the Headscale server through its REST API.

**Key Technologies:**

*   **Framework:** Flutter
*   **Language:** Dart
*   **State Management:** `provider`
*   **HTTP Client:** `http` package
*   **Storage:** `flutter_secure_storage` for sensitive data (API key) and `shared_preferences` for settings.
*   **Background Tasks:** `workmanager` for periodic checks and notifications.
*   **UI/UX:** The project uses several packages to create a rich user experience, including `fl_chart` for data visualization and `graphview` for network topology.

## Building and Running

To build and run this project, you will need to have the Flutter SDK installed.

1.  **Clone the repository:**
    ```bash
    git clone <repository-url>
    cd headscaleManager
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Run the application:**
    ```bash
    flutter run
    ```
    This will run the app on a connected device, emulator, or the desktop environment.

**Configuration:**

Before the app can connect to your Headscale server, you need to configure the server URL and API key within the app's settings screen. The `README.md` file provides detailed instructions on how to set up a Headscale server and generate an API key.

## Development Conventions

*   **State Management:** The project uses the `provider` package for state management. The `AppProvider` class (`lib/providers/app_provider.dart`) holds the main application state.
*   **Code Structure:** The `lib` directory is organized by feature, with separate directories for `api`, `models`, `providers`, `screens`, `services`, `utils`, and `widgets`. This separation of concerns makes the codebase easy to navigate and maintain.
*   **API Interaction:** All interactions with the Headscale API are centralized in the `HeadscaleApiService` class (`lib/api/headscale_api_service.dart`).
*   **Internationalization:** The application supports multiple languages (English and French). Text strings should be added to the localization files.
*   **Security:** The Headscale API key is stored securely using `flutter_secure_storage`.
*   **Background Processing:** `workmanager` is used to run background tasks, such as checking for network status changes and sending notifications. This is configured in `notification_service.dart`.

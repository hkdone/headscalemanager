# GEMINI.md - Headscale Manager

## 🚀 Project Overview
Headscale Manager is a Flutter-based multi-platform application (Android, iOS, macOS, Windows, Web) designed to manage a [Headscale](https://github.com/juanfont/headscale) server. It provides a user-friendly interface for managing nodes, users, ACLs, API keys, and pre-auth keys.

## 🛠 Tech Stack
- **Framework**: Flutter (Dart)
- **State Management**: `provider` (centralized in `AppProvider`)
- **API Communication**: `http` package (centralized in `HeadscaleApiService`)
- **Persistence**: 
  - `flutter_secure_storage`: Sensitive data (API keys, Server URLs).
  - `shared_preferences`: Application settings (locale, UI preferences).
- **Background Tasks**: `workmanager` & `flutter_local_notifications` (for node status monitoring).
- **UI Libraries**: `eva_icons_flutter`, `fl_chart` (analytics/viz), `graphview` (network topology UI).

## 📁 Project Structure & Key Files

### Core Architecture
- [**main.dart**](file:///c:/Users/dkdone/StudioProjects/headscaleManager/lib/main.dart): Entry point, initializes `AppProvider` and `MaterialApp`.
- [**lib/providers/app_provider.dart**](file:///c:/Users/dkdone/StudioProjects/headscaleManager/lib/providers/app_provider.dart): The "Brain". Manages active server switching, locale, global loading state, and holds the `HeadscaleApiService` instance.
- [**lib/api/headscale_api_service.dart**](file:///c:/Users/dkdone/StudioProjects/headscaleManager/lib/api/headscale_api_service.dart): Implements the REST client for Headscale API. Handles error wrapping and JSON deserialization.
- [**lib/services/storage_service.dart**](file:///c:/Users/dkdone/StudioProjects/headscaleManager/lib/services/storage_service.dart): Handles multi-server storage and secure persistence of API keys.

### Logic & Features
- [**lib/services/new_acl_generator_service.dart**](file:///c:/Users/dkdone/StudioProjects/headscaleManager/lib/services/new_acl_generator_service.dart): Generates secure ACL policies based on users and node tags. Implements user isolation and automatic route approval logic.
- [**lib/services/notification_service.dart**](file:///c:/Users/dkdone/StudioProjects/headscaleManager/lib/services/notification_service.dart): Configures background workers to check for network changes and alert the user.
- [**lib/models/**](file:///c:/Users/dkdone/StudioProjects/headscaleManager/lib/models/): Contains typed data structures (`Node`, `User`, `PreAuthKey`, etc.) with `fromJson` logic.

### UI / Screens
- **Dashboard**: Overview of nodes & users. Automated workflow for route approval.
- **ACL Manager**: Interactive graph of network topology and connectivity rules.
- **Network Overview**: Diagnostic tool for pinging nodes and checking exit node paths.
- **Key Management**: Interfaces for API Keys and Pre-Auth Keys (includes QR code generation for `tailscale up`).

## 📖 External Documentation References
- [**ListeApiAvaible.md**](file:///c:/Users/dkdone/StudioProjects/headscaleManager/ListeApiAvaible.md): Full Headscale Swagger API definition. Use this to find available endpoints and request/response schemas.
- [**project_summary.md**](file:///c:/Users/dkdone/StudioProjects/headscaleManager/project_summary.md): Functional summary of pages and their corresponding Dart files.
- [**api_cli_functions_guide.md**](file:///c:/Users/dkdone/StudioProjects/headscaleManager/api_cli_functions_guide.md): Guide on mapping Headscale CLI commands to API calls.

## ⚙️ Development Guidelines
1. **API first**: Always use `HeadscaleApiService` for backend communication. If a new endpoint is needed, add it there following the pattern.
2. **State Management**: Access services and global state via `context.read<AppProvider>()` or `Consumer<AppProvider>`.
3. **Data Mapping**: Complex API data should always be mapped to a Model in `lib/models/`.
4. **Localization**: The app supports French (`fr`) and English (`en`). Use the localization delegates.
5. **Security**: Never log API keys. Use `StorageService` for sensitive persistence.

## 🧪 Testing & Verification
- **Manual**: Test UI flows on an emulator or physical device.
- **Network**: Use the "Network Overview" screen to verify routing logic (pings, exit nodes).
- **ACLs**: Profile generation can be verified by inspecting the JSON output in the ACL screen.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service de stockage sécurisé pour les identifiants de l'application.
///
/// Utilise `flutter_secure_storage` pour stocker et récupérer de manière sécurisée
/// la clé API et l'URL du serveur Headscale.
class StorageService {
  /// Instance de `FlutterSecureStorage` utilisée pour les opérations de stockage.
  final _storage = const FlutterSecureStorage();

  /// Clé utilisée pour stocker la clé API Headscale.
  static const _apiKey = 'HEADSCALE_API_KEY';

  /// Clé utilisée pour stocker l'URL du serveur Headscale.
  static const _serverUrl = 'HEADSCALE_SERVER_URL';

  /// Sauvegarde les identifiants de connexion (clé API et URL du serveur) de manière sécurisée.
  ///
  /// [apiKey] : La clé API à sauvegarder.
  /// [serverUrl] : L'URL du serveur à sauvegarder.
  Future<void> saveCredentials({required String apiKey, required String serverUrl}) async {
    await _storage.write(key: _apiKey, value: apiKey);
    await _storage.write(key: _serverUrl, value: serverUrl);
  }

  /// Récupère la clé API Headscale stockée.
  ///
  /// Retourne la clé API sous forme de [String] ou `null` si elle n'est pas trouvée.
  Future<String?> getApiKey() async {
    return await _storage.read(key: _apiKey);
  }

  /// Récupère l'URL du serveur Headscale stockée.
  ///
  /// Retourne l'URL du serveur sous forme de [String] ou `null` si elle n'est pas trouvée.
  Future<String?> getServerUrl() async {
    return await _storage.read(key: _serverUrl);
  }

  /// Vérifie si les identifiants de connexion (clé API et URL du serveur) sont présents et valides.
  ///
  /// Retourne `true` si les deux identifiants sont trouvés et non vides, `false` sinon.
  Future<bool> hasCredentials() async {
    final apiKey = await getApiKey();
    final serverUrl = await getServerUrl();
    return apiKey != null && serverUrl != null && apiKey.isNotEmpty && serverUrl.isNotEmpty;
  }

  /// Efface tous les identifiants de connexion stockés.
  Future<void> clearCredentials() async {
    await _storage.delete(key: _apiKey);
    await _storage.delete(key: _serverUrl);
  }
}
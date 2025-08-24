import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service de stockage sécurisé pour les identifiants et les configurations de l'application.
class StorageService {
  final _storage = const FlutterSecureStorage();

  static const _apiKey = 'HEADSCALE_API_KEY';
  static const _serverUrl = 'HEADSCALE_SERVER_URL';
  static const _temporaryAclRules = 'TEMPORARY_ACL_RULES';

  /// Sauvegarde les identifiants de connexion.
  Future<void> saveCredentials({required String apiKey, required String serverUrl}) async {
    await _storage.write(key: _apiKey, value: apiKey);
    await _storage.write(key: _serverUrl, value: serverUrl);
  }

  /// Récupère la clé API Headscale stockée.
  Future<String?> getApiKey() async {
    return await _storage.read(key: _apiKey);
  }

  /// Récupère l'URL du serveur Headscale stockée.
  Future<String?> getServerUrl() async {
    return await _storage.read(key: _serverUrl);
  }

  /// Vérifie si les identifiants de connexion sont présents.
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

  /// Sauvegarde les règles ACL temporaires.
  Future<void> saveTemporaryRules(List<Map<String, String>> rules) async {
    final String rulesJson = json.encode(rules);
    await _storage.write(key: _temporaryAclRules, value: rulesJson);
  }

  /// Récupère les règles ACL temporaires.
  Future<List<Map<String, String>>> getTemporaryRules() async {
    final String? rulesJson = await _storage.read(key: _temporaryAclRules);
    if (rulesJson != null && rulesJson.isNotEmpty) {
      try {
        final List<dynamic> decodedList = json.decode(rulesJson);
        return decodedList.map((item) => Map<String, String>.from(item)).toList();
      } catch (e) {
        // En cas d'erreur de décodage, retourne une liste vide.
        return [];
      }
    }
    return [];
  }
}

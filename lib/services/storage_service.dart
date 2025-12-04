import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:headscalemanager/models/server.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  final _storage = const FlutterSecureStorage();

  static const _oldApiKey = 'HEADSCALE_API_KEY';
  static const _oldServerUrl = 'HEADSCALE_SERVER_URL';
  static const _serversKey = 'SERVERS_LIST';
  static const _activeServerIdKey = 'ACTIVE_SERVER_ID';

  static const _temporaryAclRules = 'TEMPORARY_ACL_RULES';
  static const _languageKey = 'APP_LANGUAGE';

  Future<void> init() async {
    await _migrateToServerList();
  }

  Future<void> _migrateToServerList() async {
    final oldApiKey = await _storage.read(key: _oldApiKey);
    final oldServerUrl = await _storage.read(key: _oldServerUrl);

    if (oldApiKey != null && oldServerUrl != null) {
      final server = Server(
        name: 'Default Server',
        url: oldServerUrl,
        apiKey: oldApiKey,
      );
      await saveServers([server]);
      await setActiveServerId(server.id);

      await _storage.delete(key: _oldApiKey);
      await _storage.delete(key: _oldServerUrl);
    }
  }

  Future<List<Server>> getServers() async {
    final serversJson = await _storage.read(key: _serversKey);
    if (serversJson == null) {
      return [];
    }
    final List<dynamic> serversList = json.decode(serversJson);
    return serversList.map((json) => Server.fromJson(json)).toList();
  }

  Future<void> saveServers(List<Server> servers) async {
    final serversJson = json.encode(servers.map((s) => s.toJson()).toList());
    await _storage.write(key: _serversKey, value: serversJson);
  }

  Future<String?> getActiveServerId() async {
    return await _storage.read(key: _activeServerIdKey);
  }

  Future<void> setActiveServerId(String serverId) async {
    await _storage.write(key: _activeServerIdKey, value: serverId);
  }

  Future<void> saveLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
  }

  Future<String?> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey);
  }

  Future<void> saveTemporaryRules(List<Map<String, dynamic>> rules) async {
    final String rulesJson = json.encode(rules);
    await _storage.write(key: _temporaryAclRules, value: rulesJson);
  }

  Future<List<Map<String, dynamic>>> getTemporaryRules() async {
    final String? rulesJson = await _storage.read(key: _temporaryAclRules);
    if (rulesJson != null && rulesJson.isNotEmpty) {
      try {
        final List<dynamic> decodedList = json.decode(rulesJson);
        return decodedList.map((item) => Map<String, dynamic>.from(item)).toList();
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  Future<void> saveData(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> getData(String key) async {
    return await _storage.read(key: key);
  }
}
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:headscalemanager/models/acl_engine_mode.dart';
import 'package:headscalemanager/models/server.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  final _storage = _SafeSecureStorage();

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

  Future<void> saveTemporaryRules(
      String serverId, List<Map<String, dynamic>> rules) async {
    final String rulesJson = json.encode(rules);
    await _storage.write(
        key: '${_temporaryAclRules}_$serverId', value: rulesJson);
  }

  Future<List<Map<String, dynamic>>> getTemporaryRules(String serverId) async {
    final String? rulesJson =
        await _storage.read(key: '${_temporaryAclRules}_$serverId');
    if (rulesJson != null && rulesJson.isNotEmpty) {
      try {
        final List<dynamic> decodedList = json.decode(rulesJson);
        return decodedList
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
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

  Future<void> saveCustomDnsRecords(
      String serverId, Map<String, String> records) async {
    final String recordsJson = json.encode(records);
    await _storage.write(
        key: 'CUSTOM_DNS_RECORDS_$serverId', value: recordsJson);
  }

  Future<Map<String, String>> getCustomDnsRecords(String serverId) async {
    final String? recordsJson =
        await _storage.read(key: 'CUSTOM_DNS_RECORDS_$serverId');
    if (recordsJson != null && recordsJson.isNotEmpty) {
      try {
        final Map<String, dynamic> decodedMap = json.decode(recordsJson);
        return decodedMap.map((key, value) => MapEntry(key, value.toString()));
      } catch (e) {
        return {};
      }
    }
    return {};
  }

  static const _aclEngineKey = 'ACL_ENGINE_STANDARD_ENABLED';
  static const _aclEngineModeKey = 'ACL_ENGINE_MODE';
  static const _aclEngineExplicitKey = 'ACL_ENGINE_MODE_EXPLICIT';
  static const _taildriveSharesPrefix = 'TAILDRIVE_SHARES_';

  Future<void> saveTaildriveShares(
      String serverId, List<Map<String, dynamic>> shares) async {
    final String sharesJson = json.encode(shares);
    await _storage.write(
        key: '$_taildriveSharesPrefix$serverId', value: sharesJson);
  }

  Future<List<Map<String, dynamic>>> getTaildriveShares(String serverId) async {
    final String? sharesJson =
        await _storage.read(key: '$_taildriveSharesPrefix$serverId');
    if (sharesJson != null && sharesJson.isNotEmpty) {
      try {
        final List<dynamic> decodedList = json.decode(sharesJson);
        return decodedList
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  Future<void> setStandardAclEngineEnabled(bool enabled) async {
    await saveAclEngineMode(
      enabled ? AclEngineMode.standard : AclEngineMode.legacy,
    );
  }

  Future<bool> getStandardAclEngineEnabled() async {
    final mode = await getAclEngineMode();
    return mode != AclEngineMode.legacy;
  }

  Future<AclEngineMode> getAclEngineMode() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_aclEngineModeKey);
    if (stored != null) {
      return AclEngineModeStorage.fromStorageKey(stored);
    }
    final legacyStandard = prefs.getBool(_aclEngineKey) ?? false;
    return legacyStandard ? AclEngineMode.standard : AclEngineMode.legacy;
  }

  Future<void> saveAclEngineMode(AclEngineMode mode,
      {bool explicit = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aclEngineModeKey, mode.storageKey);
    await prefs.setBool(_aclEngineKey, mode != AclEngineMode.legacy);
    if (explicit) {
      await prefs.setBool(_aclEngineExplicitKey, true);
    }
  }

  Future<bool> hasExplicitAclEngineMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_aclEngineExplicitKey) ?? false;
  }

  Future<void> setGrantsMigrationCompleted(String serverId, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('GRANTS_MIGRATION_DONE_$serverId', value);
  }

  Future<bool> isGrantsMigrationCompleted(String serverId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('GRANTS_MIGRATION_DONE_$serverId') ?? false;
  }

  Future<void> setGrantsMigrationDismissed(String serverId, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('GRANTS_MIGRATION_DISMISSED_$serverId', value);
  }

  Future<bool> isGrantsMigrationDismissed(String serverId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('GRANTS_MIGRATION_DISMISSED_$serverId') ?? false;
  }

  Future<void> savePuzzleEntityAliases(
      String serverId, Map<String, String> aliases) async {
    final String aliasesJson = json.encode(aliases);
    await _storage.write(
        key: 'PUZZLE_ENTITY_ALIASES_$serverId', value: aliasesJson);
  }

  Future<Map<String, String>> getPuzzleEntityAliases(String serverId) async {
    final String? aliasesJson =
        await _storage.read(key: 'PUZZLE_ENTITY_ALIASES_$serverId');
    if (aliasesJson != null && aliasesJson.isNotEmpty) {
      try {
        final Map<String, dynamic> decodedMap = json.decode(aliasesJson);
        return decodedMap.map((key, value) => MapEntry(key, value.toString()));
      } catch (e) {
        return {};
      }
    }
    return {};
  }

  Future<void> savePuzzleBlocksMeta(
      String serverId, Map<String, Map<String, dynamic>> meta) async {
    final String metaJson = json.encode(meta);
    await _storage.write(
        key: 'PUZZLE_BLOCKS_META_$serverId', value: metaJson);
  }

  Future<Map<String, Map<String, dynamic>>> getPuzzleBlocksMeta(
      String serverId) async {
    final String? metaJson =
        await _storage.read(key: 'PUZZLE_BLOCKS_META_$serverId');
    if (metaJson != null && metaJson.isNotEmpty) {
      try {
        final Map<String, dynamic> decodedMap = json.decode(metaJson);
        return decodedMap.map((key, value) =>
            MapEntry(key, Map<String, dynamic>.from(value)));
      } catch (e) {
        return {};
      }
    }
    return {};
  }

  Future<void> savePuzzleVisualOrder(
      String serverId, List<String> order) async {
    final String orderJson = json.encode(order);
    await _storage.write(
        key: 'PUZZLE_VISUAL_ORDER_$serverId', value: orderJson);
  }

  Future<List<String>> getPuzzleVisualOrder(String serverId) async {
    final String? orderJson =
        await _storage.read(key: 'PUZZLE_VISUAL_ORDER_$serverId');
    if (orderJson != null && orderJson.isNotEmpty) {
      try {
        final List<dynamic> decodedList = json.decode(orderJson);
        return decodedList.map((e) => e.toString()).toList();
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  static const _usersViewModeKey = 'USERS_VIEW_MODE';

  Future<void> saveUsersViewMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usersViewModeKey, mode);
  }

  Future<String> getUsersViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usersViewModeKey) ?? 'grid';
  }

  Future<void> saveUserNotes(String serverId, String userId, String notes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('USER_NOTES_${serverId}_$userId', notes);
  }

  Future<String> getUserNotes(String serverId, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('USER_NOTES_${serverId}_$userId') ?? '';
  }

  Future<void> saveDeviceTypeIcon(String serverId, String nodeId, String deviceType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('DEVICE_TYPE_ICON_${serverId}_$nodeId', deviceType);
  }

  Future<String?> getDeviceTypeIcon(String serverId, String nodeId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('DEVICE_TYPE_ICON_${serverId}_$nodeId');
  }

  Future<void> savePingLatencyThreshold(String serverId, String nodeId, double threshold) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('PING_LATENCY_THRESHOLD_${serverId}_$nodeId', threshold);
  }

  Future<double> getPingLatencyThreshold(String serverId, String nodeId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('PING_LATENCY_THRESHOLD_${serverId}_$nodeId') ?? 100.0;
  }
}

class _SafeSecureStorage {
  final _storage = const FlutterSecureStorage();

  Future<String?> read({required String key}) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      return null;
    }
  }

  Future<void> write({required String key, required String value}) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      try {
        await _storage.delete(key: key);
        await _storage.write(key: key, value: value);
      } catch (_) {}
    }
  }

  Future<void> delete({required String key}) async {
    try {
      await _storage.delete(key: key);
    } catch (_) {}
  }
}

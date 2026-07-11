import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:headscalemanager/api/headscale_api_service.dart';
import 'package:headscalemanager/models/server.dart';
import 'package:headscalemanager/models/taildrive_share.dart';
import 'package:headscalemanager/services/notification_service.dart';
import 'package:headscalemanager/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:headscalemanager/models/acl_engine_mode.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/version_info.dart';

class AppProvider extends ChangeNotifier {

  final StorageService _storageService = StorageService();
  HeadscaleApiService? _apiService;

  final Completer<void> _initializationCompleter = Completer<void>();
  bool _isLoading = false;
  Locale _locale = const Locale('fr');
  List<Server> _servers = [];
  Server? _activeServer;
  List<TaildriveShare> _taildriveShares = [];
  Map<String, String> _customUserIcons = {};

  Map<String, String> _puzzleEntityAliases = {};
  Map<String, Map<String, dynamic>> _puzzleBlocksMeta = {};
  List<String> _puzzleVisualOrder = [];

  String _usersViewMode = 'grid';
  final Map<String, String> _userNotesCache = {};
  final Map<String, String> _deviceCustomIcons = {};
  final Map<String, double> _pingLatencyThresholds = {};

  AppProvider() {
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await _storageService.init();
      await _loadLocale();
      await _loadServers();
      await _loadAclEnginePreference();
      await _loadTaildriveShares();
      await _loadUserIcons();
      await _loadPuzzleMetadata();
      await _loadUsersViewMode();
      await _loadCustomDeviceData();

      // Auto-detect if we should benefit from Standard ACL Engine
      if (_activeServer != null && _aclEngineMode == AclEngineMode.legacy) {
        try {
          final nodes = await _apiService!.getNodes();
          bool hasStandardTags = false;
          bool hasLegacyMergedTags = false;

          for (var node in nodes) {
            for (var tag in node.tags) {
              if (tag.contains(';') &&
                  (tag.contains('exit-node') || tag.contains('lan-sharer'))) {
                hasLegacyMergedTags = true;
              }
              if (!tag.contains(';') &&
                  (tag.endsWith('-exit-node') || tag.endsWith('-lan-sharer'))) {
                hasStandardTags = true;
              }
            }
          }

          if (hasStandardTags && !hasLegacyMergedTags) {
            await setStandardAclEngineEnabled(true);
            debugPrint(
                'Auto-enabled Standard ACL Engine due to detected standard tags.');
          }
        } catch (e) {
          debugPrint('Error auto-detecting ACL engine: $e');
        }
      }

      await NotificationService.initialize();

      if (_activeServer != null) {
        _detectServerVersion(); // Détection asynchrone au démarrage
      }
    } catch (e) {
      debugPrint('CRITICAL: Error during services initialization: $e');
    } finally {
      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.complete();
      }
    }
  }

  Future<void> get isInitialized => _initializationCompleter.future;

  HeadscaleApiService get apiService {
    if (_apiService == null) {
      throw Exception("ApiService not initialized. No active server found.");
    }
    return _apiService!;
  }

  StorageService get storageService => _storageService;
  bool get isLoading => _isLoading;
  Locale get locale => _locale;
  List<Server> get servers => _servers;
  Server? get activeServer => _activeServer;
  String get serverVersion => _activeServer?.version ?? '0.25.0';
  List<TaildriveShare> get taildriveShares => _taildriveShares;

  Map<String, String> get puzzleEntityAliases => _puzzleEntityAliases;
  Map<String, Map<String, dynamic>> get puzzleBlocksMeta => _puzzleBlocksMeta;
  List<String> get puzzleVisualOrder => _puzzleVisualOrder;

  Future<void> _loadPuzzleMetadata() async {
    if (_activeServer == null) {
      _puzzleEntityAliases = {};
      _puzzleBlocksMeta = {};
      _puzzleVisualOrder = [];
      return;
    }
    _puzzleEntityAliases = await _storageService.getPuzzleEntityAliases(_activeServer!.id);
    _puzzleBlocksMeta = await _storageService.getPuzzleBlocksMeta(_activeServer!.id);
    _puzzleVisualOrder = await _storageService.getPuzzleVisualOrder(_activeServer!.id);
    notifyListeners();
  }

  String get usersViewMode => _usersViewMode;

  Future<void> _loadUsersViewMode() async {
    _usersViewMode = await _storageService.getUsersViewMode();
    notifyListeners();
  }

  Future<void> setUsersViewMode(String mode) async {
    _usersViewMode = mode;
    await _storageService.saveUsersViewMode(mode);
    notifyListeners();
  }

  Future<void> _loadCustomDeviceData() async {
    if (_activeServer == null) {
      _deviceCustomIcons.clear();
      _pingLatencyThresholds.clear();
      _userNotesCache.clear();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final serverId = _activeServer!.id;
    
    final keys = prefs.getKeys();
    for (var key in keys) {
      if (key.startsWith('DEVICE_TYPE_ICON_${serverId}_')) {
        final nodeId = key.substring('DEVICE_TYPE_ICON_${serverId}_'.length);
        _deviceCustomIcons[nodeId] = prefs.getString(key) ?? 'generic';
      } else if (key.startsWith('PING_LATENCY_THRESHOLD_${serverId}_')) {
        final nodeId = key.substring('PING_LATENCY_THRESHOLD_${serverId}_'.length);
        _pingLatencyThresholds[nodeId] = prefs.getDouble(key) ?? 100.0;
      } else if (key.startsWith('USER_NOTES_${serverId}_')) {
        final userId = key.substring('USER_NOTES_${serverId}_'.length);
        _userNotesCache[userId] = prefs.getString(key) ?? '';
      }
    }
    notifyListeners();
  }

  String getUserNotesSync(String userId) {
    return _userNotesCache[userId] ?? '';
  }

  Future<void> setUserNotes(String userId, String notes) async {
    if (_activeServer == null) return;
    _userNotesCache[userId] = notes;
    await _storageService.saveUserNotes(_activeServer!.id, userId, notes);
    notifyListeners();
  }

  String getDeviceIconKey(Node node) {
    if (_deviceCustomIcons.containsKey(node.id)) {
      return _deviceCustomIcons[node.id]!;
    }
    final nameLower = node.name.toLowerCase();
    final hostLower = node.hostname.toLowerCase();
    
    if (hostLower.contains('win') || nameLower.contains('win')) {
      return 'windows';
    }
    if (hostLower.contains('android') || nameLower.contains('android')) {
      return 'android';
    }
    if (hostLower.contains('iphone') || nameLower.contains('iphone') || 
        hostLower.contains('ipad') || nameLower.contains('ipad') ||
        hostLower.contains('ios') || nameLower.contains('ios')) {
      return 'iphone';
    }
    if (hostLower.contains('mac') || nameLower.contains('mac') ||
        hostLower.contains('darwin') || nameLower.contains('darwin') ||
        hostLower.contains('apple') || nameLower.contains('apple')) {
      return 'mac';
    }
    if (hostLower.contains('server') || nameLower.contains('server') ||
        hostLower.contains('nas') || nameLower.contains('nas') ||
        hostLower.contains('dns') || nameLower.contains('dns')) {
      return 'server';
    }
    if (hostLower.contains('ubuntu') || nameLower.contains('ubuntu') ||
        hostLower.contains('debian') || nameLower.contains('debian') ||
        hostLower.contains('centos') || nameLower.contains('centos') ||
        hostLower.contains('linux') || nameLower.contains('linux')) {
      return 'linux';
    }
    
    return 'generic';
  }

  IconData getDeviceIcon(Node node) {
    final key = getDeviceIconKey(node);
    return deviceIconsPalette[key] ?? Icons.devices;
  }

  Future<void> setDeviceTypeIcon(String nodeId, String deviceType) async {
    if (_activeServer == null) return;
    _deviceCustomIcons[nodeId] = deviceType;
    await _storageService.saveDeviceTypeIcon(_activeServer!.id, nodeId, deviceType);
    notifyListeners();
  }

  double getPingLatencyThresholdSync(String nodeId) {
    return _pingLatencyThresholds[nodeId] ?? 100.0;
  }

  Future<void> setPingLatencyThreshold(String nodeId, double threshold) async {
    if (_activeServer == null) return;
    _pingLatencyThresholds[nodeId] = threshold;
    await _storageService.savePingLatencyThreshold(_activeServer!.id, nodeId, threshold);
    notifyListeners();
  }

  Future<void> setPuzzleVisualOrder(List<String> order) async {
    if (_activeServer == null) return;
    _puzzleVisualOrder = order;
    await _storageService.savePuzzleVisualOrder(_activeServer!.id, _puzzleVisualOrder);
    notifyListeners();
  }

  String? getEntityAlias(String value) {
    return _puzzleEntityAliases[value];
  }

  Future<void> setEntityAlias(String value, String alias) async {
    if (_activeServer == null) return;
    if (alias.trim().isEmpty) {
      _puzzleEntityAliases.remove(value);
    } else {
      _puzzleEntityAliases[value] = alias.trim();
    }
    await _storageService.savePuzzleEntityAliases(_activeServer!.id, _puzzleEntityAliases);
    notifyListeners();
  }

  Map<String, dynamic>? getBlockMeta(String signature) {
    return _puzzleBlocksMeta[signature];
  }

  Future<void> setBlockMeta(String signature, {String? name, String? iconKey, String? imagePath, String? colorHex}) async {
    if (_activeServer == null) return;
    
    final meta = _puzzleBlocksMeta[signature] ?? {};
    if (name != null) meta['name'] = name.trim();
    if (iconKey != null) meta['iconKey'] = iconKey;
    if (imagePath != null) {
      meta['imagePath'] = imagePath;
    }
    if (colorHex != null) {
      meta['colorHex'] = colorHex;
    }
    
    _puzzleBlocksMeta[signature] = meta;
    await _storageService.savePuzzleBlocksMeta(_activeServer!.id, _puzzleBlocksMeta);
    notifyListeners();
  }

  Future<void> deleteBlockMeta(String signature) async {
    if (_activeServer == null) return;
    _puzzleBlocksMeta.remove(signature);
    await _storageService.savePuzzleBlocksMeta(_activeServer!.id, _puzzleBlocksMeta);
    notifyListeners();
  }

  Future<void> _loadTaildriveShares() async {

    if (_activeServer == null) {
      _taildriveShares = [];
      return;
    }
    final sharesJson =
        await _storageService.getTaildriveShares(_activeServer!.id);
    _taildriveShares =
        sharesJson.map((j) => TaildriveShare.fromJson(j)).toList();
    notifyListeners();
  }

  Future<void> _loadUserIcons() async {
    final jsonStr = await _storageService.getData('USER_CUSTOM_ICONS');
    if (jsonStr != null) {
      try {
        _customUserIcons = Map<String, String>.from(json.decode(jsonStr));
      } catch (_) {}
    }
  }

  String getUserIcon(String userId) => _customUserIcons[userId] ?? 'person';

  Future<void> setUserIcon(String userId, String iconNameOrPath) async {
    _customUserIcons[userId] = iconNameOrPath;
    await _storageService.saveData('USER_CUSTOM_ICONS', json.encode(_customUserIcons));
    notifyListeners();
  }

  Future<void> addTaildriveShare(TaildriveShare share) async {
    if (_activeServer == null) return;
    _taildriveShares.add(share);
    await _storageService.saveTaildriveShares(
        _activeServer!.id, _taildriveShares.map((s) => s.toJson()).toList());
    notifyListeners();
  }

  Future<void> deleteTaildriveShare(String shareId) async {
    if (_activeServer == null) return;
    _taildriveShares.removeWhere((s) => s.id == shareId);
    await _storageService.saveTaildriveShares(
        _activeServer!.id, _taildriveShares.map((s) => s.toJson()).toList());
    notifyListeners();
  }

  Future<void> _loadLocale() async {
    final languageCode = await _storageService.getLanguage();
    if (languageCode != null) {
      _locale = Locale(languageCode);
      notifyListeners();
    }
  }

  Future<void> _loadServers() async {
    _servers = await _storageService.getServers();
    final activeServerId = await _storageService.getActiveServerId();

    Server? foundActiveServer;
    if (activeServerId != null) {
      for (var server in _servers) {
        if (server.id == activeServerId) {
          foundActiveServer = server;
          break;
        }
      }
    }

    if (foundActiveServer != null) {
      _activeServer = foundActiveServer;
    } else if (_servers.isNotEmpty) {
      _activeServer = _servers.first;
      await _storageService.setActiveServerId(_activeServer!.id);
    } else {
      _activeServer = null;
    }

    if (_activeServer != null) {
      _apiService = HeadscaleApiService(
        apiKey: _activeServer!.apiKey,
        baseUrl: _activeServer!.url,
      );
    }
    notifyListeners();
  }

  Future<void> setLocale(Locale newLocale) async {
    if (_locale != newLocale) {
      _locale = newLocale;
      await _storageService.saveLanguage(newLocale.languageCode);
      notifyListeners();
    }
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> addServer(Server server) async {
    _servers.add(server);
    await _storageService.saveServers(_servers);
    if (_activeServer == null) {
      await switchServer(server.id);
    }
    notifyListeners();
  }

  Future<void> updateServer(Server server) async {
    final index = _servers.indexWhere((s) => s.id == server.id);
    if (index != -1) {
      _servers[index] = server;
      await _storageService.saveServers(_servers);
      if (_activeServer?.id == server.id) {
        await switchServer(server.id);
      }
      notifyListeners();
    }
  }

  Future<void> deleteServer(String serverId) async {
    if (_servers.length > 1) {
      _servers.removeWhere((s) => s.id == serverId);
      await _storageService.saveServers(_servers);
      if (_activeServer?.id == serverId) {
        await switchServer(_servers.first.id);
      }
      notifyListeners();
    }
  }

  Future<void> switchServer(String serverId) async {
    _activeServer = _servers.firstWhere((s) => s.id == serverId);
    await _storageService.setActiveServerId(serverId);
    _apiService = HeadscaleApiService(
      apiKey: _activeServer!.apiKey,
      baseUrl: _activeServer!.url,
    );
    await _loadTaildriveShares();
    await _loadPuzzleMetadata();
    await _loadCustomDeviceData();
    notifyListeners();
    _detectServerVersion(); // Détecter la version après le changement
  }

  Future<void> _detectServerVersion() async {
    if (_apiService == null || _activeServer == null) return;

    try {
      final versionInfo = await _apiService!.getVersion();
      final updatedServer =
          _activeServer!.copyWith(version: versionInfo.version);

      // Update local state and persistence
      _activeServer = updatedServer;
      final index = _servers.indexWhere((s) => s.id == updatedServer.id);
      if (index != -1) {
        _servers[index] = updatedServer;
        await _storageService.saveServers(_servers);
        notifyListeners();
      }
      await _maybeAutoEnableGrantsEngine();
    } catch (e) {
      debugPrint('Erreur lors de la détection de la version : $e');
      // On garde la version actuelle ou le défaut s'il n'y a pas de réponse
    }
  }

  AclEngineMode _aclEngineMode = AclEngineMode.standard;
  AclEngineMode get aclEngineMode => _aclEngineMode;

  /// Vrai pour Standard et Grants V29 (tags séparés).
  bool get useStandardAclEngine => _aclEngineMode != AclEngineMode.legacy;

  Future<void> _loadAclEnginePreference() async {
    _aclEngineMode = await _storageService.getAclEngineMode();
    notifyListeners();
  }

  Future<void> setAclEngineMode(AclEngineMode mode) async {
    _aclEngineMode = mode;
    await _storageService.saveAclEngineMode(mode);
    notifyListeners();
  }

  Future<void> setStandardAclEngineEnabled(bool enabled) async {
    await setAclEngineMode(
      enabled ? AclEngineMode.standard : AclEngineMode.legacy,
    );
  }

  Future<void> _maybeAutoEnableGrantsEngine() async {
    if (_activeServer == null) return;
    if (!VersionInfo.checkVersionAtLeast(serverVersion, '0.29.0')) return;
    if (_aclEngineMode == AclEngineMode.grantsV29) return;
    if (await _storageService.hasExplicitAclEngineMode()) return;
    if (_aclEngineMode == AclEngineMode.standard) {
      _aclEngineMode = AclEngineMode.grantsV29;
      await _storageService.saveAclEngineMode(
        AclEngineMode.grantsV29,
        explicit: false,
      );
      notifyListeners();
    }
  }
}

const Map<String, IconData> deviceIconsPalette = {
  'windows': Icons.laptop_windows,
  'mac': Icons.laptop_mac,
  'linux': Icons.terminal,
  'android': Icons.phone_android,
  'iphone': Icons.phone_iphone,
  'server': Icons.dns,
  'generic': Icons.devices,
};

const Map<String, IconData> userIconsPalette = {
  'person': Icons.person,
  'laptop': Icons.laptop,
  'desktop': Icons.desktop_windows,
  'phone': Icons.phone_android,
  'tablet': Icons.tablet_android,
  'router': Icons.router,
  'dns': Icons.dns,
  'storage': Icons.storage,
  'cloud': Icons.cloud,
  'security': Icons.security,
  'home': Icons.home,
  'business': Icons.business,
  'key': Icons.vpn_key,
  'devices': Icons.devices,
  'settings': Icons.settings,
  'star': Icons.star,
};

const Map<String, Map<String, IconData>> puzzleIconsPalette = {
  'Réseau': {
    'dns': Icons.dns,
    'router': Icons.router,
    'wifi': Icons.wifi,
    'vpn_lock': Icons.vpn_lock,
    'settings_ethernet': Icons.settings_ethernet,
    'sync_alt': Icons.sync_alt,
    'lan': Icons.lan,
    'hub': Icons.hub,
  },
  'Sécurité': {
    'security': Icons.security,
    'shield': Icons.shield,
    'lock': Icons.lock,
    'vpn_key': Icons.vpn_key,
    'enhanced_encryption': Icons.enhanced_encryption,
    'policy': Icons.policy,
    'gavel': Icons.gavel,
    'admin_panel_settings': Icons.admin_panel_settings,
  },
  'Matériel': {
    'computer': Icons.computer,
    'laptop': Icons.laptop,
    'phone_android': Icons.phone_android,
    'tablet_android': Icons.tablet_android,
    'desktop_windows': Icons.desktop_windows,
    'storage': Icons.storage,
    'tv': Icons.tv,
    'print': Icons.print,
  },
  'Cloud & Web': {
    'cloud': Icons.cloud,
    'public': Icons.public,
    'web': Icons.web,
    'cloud_done': Icons.cloud_done,
    'cloud_download': Icons.cloud_download,
    'api': Icons.api,
    'terminal': Icons.terminal,
  },
  'Actions': {
    'share': Icons.share,
    'folder_shared': Icons.folder_shared,
    'import_export': Icons.import_export,
    'settings': Icons.settings,
    'info': Icons.info,
    'help': Icons.help,
    'star': Icons.star,
    'favorite': Icons.favorite,
  }
};



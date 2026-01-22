import 'dart:async';
import 'package:flutter/material.dart';
import 'package:headscalemanager/api/headscale_api_service.dart';
import 'package:headscalemanager/models/server.dart';
import 'package:headscalemanager/services/notification_service.dart';
import 'package:headscalemanager/services/storage_service.dart';

class AppProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  HeadscaleApiService? _apiService;

  final Completer<void> _initializationCompleter = Completer<void>();
  bool _isLoading = false;
  Locale _locale = const Locale('fr');
  List<Server> _servers = [];
  Server? _activeServer;

  AppProvider() {
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _storageService.init();
    await _loadLocale();
    await _loadServers();
    await _loadAclEnginePreference();

    // Auto-detect if we should benefit from Standard ACL Engine
    if (_activeServer != null && !_useStandardAclEngine) {
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
          print(
              'Auto-enabled Standard ACL Engine due to detected standard tags.');
        }
      } catch (e) {
        print('Error auto-detecting ACL engine: $e');
      }
    }

    await NotificationService.initialize();

    if (_activeServer != null) {
      _detectServerVersion(); // Détection asynchrone au démarrage
    }

    _initializationCompleter.complete();
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
    } catch (e) {
      print('Erreur lors de la détection de la version : $e');
      // On garde la version actuelle ou le défaut s'il n'y a pas de réponse
    }
  }

  bool _useStandardAclEngine = false;
  bool get useStandardAclEngine => _useStandardAclEngine;

  Future<void> _loadAclEnginePreference() async {
    _useStandardAclEngine = await _storageService.getStandardAclEngineEnabled();
    notifyListeners();
  }

  Future<void> setStandardAclEngineEnabled(bool enabled) async {
    _useStandardAclEngine = enabled;
    await _storageService.setStandardAclEngineEnabled(enabled);
    notifyListeners();
  }
}

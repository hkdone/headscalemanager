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
    await NotificationService.initialize();
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
  }
}

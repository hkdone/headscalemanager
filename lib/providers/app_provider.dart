import 'package:flutter/material.dart';
import 'package:headscalemanager/api/headscale_api_service.dart';
import 'package:headscalemanager/services/notification_service.dart';
import 'package:headscalemanager/services/storage_service.dart';

/// Fournisseur d'application pour la gestion de l'état global.
///
/// Cette classe étend [ChangeNotifier] et est utilisée avec le package `provider`
/// pour fournir un accès aux services API et de stockage, ainsi que pour gérer
/// un état de chargement global.
class AppProvider extends ChangeNotifier {
  /// Instance du service API Headscale.
  final HeadscaleApiService _apiService = HeadscaleApiService();

  /// Instance du service de stockage.
  final StorageService _storageService = StorageService();

  /// État indiquant si une opération de chargement est en cours.
  bool _isLoading = false;

  /// Locale (langue) actuelle de l'application.
  Locale _locale = const Locale('fr');

  /// Constructeur par défaut de [AppProvider].
  ///
  /// Initialise les services API et de stockage directement et charge la locale.
  AppProvider() {
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _loadLocale();
    // Initialise le service de notification après le chargement des autres services.
    await NotificationService.initialize();
  }

  /// Getter pour accéder à l'instance de [HeadscaleApiService].
  HeadscaleApiService get apiService => _apiService;

  /// Getter pour accéder à l'instance de [StorageService].
  StorageService get storageService => _storageService;

  /// Getter pour obtenir l'état actuel de chargement.
  bool get isLoading => _isLoading;

  /// Getter pour la locale actuelle.
  Locale get locale => _locale;

  /// Charge la locale depuis le stockage.
  Future<void> _loadLocale() async {
    final languageCode = await _storageService.getLanguage();
    if (languageCode != null) {
      _locale = Locale(languageCode);
      notifyListeners();
    }
  }

  /// Définit la nouvelle locale et la sauvegarde.
  Future<void> setLocale(Locale newLocale) async {
    if (_locale != newLocale) {
      _locale = newLocale;
      await _storageService.saveLanguage(newLocale.languageCode);
      notifyListeners();
    }
  }

  /// Définit l'état de chargement et notifie les auditeurs des changements.
  ///
  /// [value] : Le nouvel état de chargement (true si en cours, false sinon).
  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}

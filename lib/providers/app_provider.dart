import 'package:flutter/material.dart';
import 'package:headscalemanager/api/headscale_api_service.dart';
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

  /// Constructeur par défaut de [AppProvider].
  ///
  /// Initialise les services API et de stockage directement.
  AppProvider();

  /// Getter pour accéder à l'instance de [HeadscaleApiService].
  HeadscaleApiService get apiService => _apiService;

  /// Getter pour accéder à l'instance de [StorageService].
  StorageService get storageService => _storageService;

  /// Getter pour obtenir l'état actuel de chargement.
  bool get isLoading => _isLoading;

  /// Définit l'état de chargement et notifie les auditeurs des changements.
  ///
  /// [value] : Le nouvel état de chargement (true si en cours, false sinon).
  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
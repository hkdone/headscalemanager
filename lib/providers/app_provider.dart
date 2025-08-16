import 'package:flutter/material.dart';
import 'package:headscalemanager/api/headscale_api_service.dart';
import 'package:headscalemanager/services/storage_service.dart';
import 'package:provider/provider.dart';

class AppProvider extends ChangeNotifier {
  final HeadscaleApiService _apiService = HeadscaleApiService();
  final StorageService _storageService = StorageService();

  HeadscaleApiService get apiService => _apiService;
  StorageService get storageService => _storageService;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}

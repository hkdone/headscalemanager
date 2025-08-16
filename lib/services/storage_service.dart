import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final _storage = const FlutterSecureStorage();

  static const _apiKey = 'HEADSCALE_API_KEY';
  static const _serverUrl = 'HEADSCALE_SERVER_URL';

  Future<void> saveCredentials({required String apiKey, required String serverUrl}) async {
    await _storage.write(key: _apiKey, value: apiKey);
    await _storage.write(key: _serverUrl, value: serverUrl);
  }

  Future<String?> getApiKey() async {
    return await _storage.read(key: _apiKey);
  }

  Future<String?> getServerUrl() async {
    return await _storage.read(key: _serverUrl);
  }

  Future<bool> hasCredentials() async {
    final apiKey = await getApiKey();
    final serverUrl = await getServerUrl();
    return apiKey != null && serverUrl != null && apiKey.isNotEmpty && serverUrl.isNotEmpty;
  }

  Future<void> clearCredentials() async {
    await _storage.delete(key: _apiKey);
    await _storage.delete(key: _serverUrl);
  }
}

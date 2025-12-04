import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class SecurityService {
  final _storage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();

  static const _pinKey = 'APP_PIN_HASH';
  static const _biometricsEnabledKey = 'APP_BIOMETRICS_ENABLED';

  // --- PIN Management ---

  Future<void> savePin(String pin) async {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    await _storage.write(key: _pinKey, value: digest.toString());
  }

  Future<bool> verifyPin(String pin) async {
    final storedHash = await _storage.read(key: _pinKey);
    if (storedHash == null) {
      return false; // No PIN configured
    }
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString() == storedHash;
  }

  Future<bool> isPinConfigured() async {
    final pinHash = await _storage.read(key: _pinKey);
    return pinHash != null && pinHash.isNotEmpty;
  }

  Future<void> clearPin() async {
    await _storage.delete(key: _pinKey);
    // Also disable biometrics if PIN is cleared
    await saveBiometricsEnabled(false);
  }

  // --- Biometrics Management ---

  Future<void> saveBiometricsEnabled(bool enabled) async {
    await _storage.write(key: _biometricsEnabledKey, value: enabled.toString());
  }

  Future<bool> isBiometricsEnabled() async {
    final isEnabled = await _storage.read(key: _biometricsEnabledKey);
    return isEnabled == 'true';
  }

  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } on PlatformException catch (e) {
      print("Error checking biometrics: $e");
      return false;
    }
  }

  Future<bool> authenticate(String localizedReason) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: localizedReason,
        persistAcrossBackgrounding: true,
        biometricOnly: false,
      );
    } on PlatformException catch (e) {
      print("Authentication error: $e");
      return false;
    }
  }
}

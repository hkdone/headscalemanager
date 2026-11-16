import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Interface d'abstraction pour le stockage sécurisé clé/valeur (facilite les tests unitaires).
abstract class SecureKeyValueStore {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
}

class _FlutterSecureKeyValueStore implements SecureKeyValueStore {
  final FlutterSecureStorage _storage;
  const _FlutterSecureKeyValueStore(this._storage);

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

class SecurityService {
  final SecureKeyValueStore _storage;
  final LocalAuthentication _localAuth;

  /// Empêche le re-verrouillage au retour en premier plan lors d'appels OS
  /// légitimes (biométrie, FilePicker, ImagePicker).
  static bool suppressNextResumeLock = false;

  static const _pinKey = 'APP_PIN_HASH';
  static const _pinSaltKey = 'APP_PIN_SALT';
  static const _pinLengthKey = 'APP_PIN_LENGTH';
  static const _failedAttemptsKey = 'APP_PIN_FAILED_ATTEMPTS';
  static const _lockoutUntilKey = 'APP_PIN_LOCKOUT_UNTIL';
  static const _biometricsEnabledKey = 'APP_BIOMETRICS_ENABLED';
  static const _autoLockMinutesKey = 'APP_AUTO_LOCK_MINUTES';

  static const int _pbkdf2Iterations = 10000;
  static const int _pbkdf2KeyLength = 32;
  static const int _saltLengthBytes = 16;

  /// Délai de re-verrouillage par défaut (en minutes) : 5 minutes.
  /// `-1` signifie "au démarrage uniquement".
  static const int defaultAutoLockMinutes = 5;

  SecurityService({
    SecureKeyValueStore? storage,
    LocalAuthentication? localAuth,
  })  : _storage = storage ??
            const _FlutterSecureKeyValueStore(FlutterSecureStorage()),
        _localAuth = localAuth ?? LocalAuthentication();

  Future<String?> _safeRead(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      debugPrint('SecurityService read error ($key): ${e.runtimeType}');
      return null;
    }
  }

  Future<void> _safeWrite(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint(
          'SecurityService write retry ($key): ${e.runtimeType}');
      try {
        await _storage.delete(key: key);
        await _storage.write(key: key, value: value);
      } catch (retryError) {
        debugPrint(
            'SecurityService write failed ($key): ${retryError.runtimeType}');
        rethrow;
      }
    }
  }

  Future<void> _safeDelete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('SecurityService delete error ($key): ${e.runtimeType}');
      rethrow;
    }
  }

  // --- Cryptographic Helpers (PBKDF2-HMAC-SHA256) ---

  Uint8List _generateSalt() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(_saltLengthBytes, (_) => random.nextInt(256)),
    );
  }

  Uint8List _pbkdf2HmacSha256({
    required List<int> password,
    required List<int> salt,
    required int iterations,
    required int keyLength,
  }) {
    final hmac = Hmac(sha256, password);
    const hashLength = 32; // SHA-256 = 32 octets
    final blockCount = (keyLength / hashLength).ceil();
    final derived = <int>[];

    for (var blockIndex = 1; blockIndex <= blockCount; blockIndex++) {
      final blockInput = Uint8List(salt.length + 4)
        ..setRange(0, salt.length, salt)
        ..[salt.length] = (blockIndex >> 24) & 0xff
        ..[salt.length + 1] = (blockIndex >> 16) & 0xff
        ..[salt.length + 2] = (blockIndex >> 8) & 0xff
        ..[salt.length + 3] = blockIndex & 0xff;

      var u = Uint8List.fromList(hmac.convert(blockInput).bytes);
      final t = Uint8List.fromList(u);

      for (var i = 1; i < iterations; i++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (var j = 0; j < hashLength; j++) {
          t[j] ^= u[j];
        }
      }
      derived.addAll(t);
    }

    return Uint8List.fromList(derived.sublist(0, keyLength));
  }

  bool _constantTimeEquals(String a, String b) {
    final bytesA = utf8.encode(a);
    final bytesB = utf8.encode(b);
    var diff = bytesA.length ^ bytesB.length;
    final minLen =
        bytesA.length < bytesB.length ? bytesA.length : bytesB.length;
    for (var i = 0; i < minLen; i++) {
      diff |= bytesA[i] ^ bytesB[i];
    }
    return diff == 0;
  }

  String _formatPbkdf2Hash(Uint8List derivedKey, int iterations) {
    return 'pbkdf2:$iterations:${base64Encode(derivedKey)}';
  }

  // --- PIN Management ---

  Future<void> savePin(String pin) async {
    final salt = _generateSalt();
    final derived = _pbkdf2HmacSha256(
      password: utf8.encode(pin),
      salt: salt,
      iterations: _pbkdf2Iterations,
      keyLength: _pbkdf2KeyLength,
    );
    await _safeWrite(_pinSaltKey, base64Encode(salt));
    await _safeWrite(_pinKey, _formatPbkdf2Hash(derived, _pbkdf2Iterations));
    await _safeWrite(_pinLengthKey, pin.length.toString());
    await _resetFailedAttempts();
  }

  Future<int> getPinLength() async {
    final raw = await _safeRead(_pinLengthKey);
    final parsed = int.tryParse(raw ?? '');
    if (parsed != null && parsed >= 4 && parsed <= 8) {
      return parsed;
    }
    return 4;
  }

  Future<bool> verifyPin(String pin) async {
    final remaining = await getRemainingLockout();
    if (remaining > Duration.zero) {
      return false;
    }

    final storedHash = await _safeRead(_pinKey);
    if (storedHash == null || storedHash.isEmpty) {
      return false;
    }

    final storedSalt = await _safeRead(_pinSaltKey);

    // Migration transparente des anciens PINs SHA-256 non salés
    if (storedSalt == null || !storedHash.startsWith('pbkdf2:')) {
      final legacyDigest = sha256.convert(utf8.encode(pin)).toString();
      if (_constantTimeEquals(legacyDigest, storedHash)) {
        try {
          await savePin(pin);
        } catch (e) {
          debugPrint(
              'SecurityService PIN migration skipped: ${e.runtimeType}');
        }
        return true;
      }
      await _recordFailedAttempt();
      return false;
    }

    final parts = storedHash.split(':');
    if (parts.length != 3) {
      await _recordFailedAttempt();
      return false;
    }

    final iterations = int.tryParse(parts[1]) ?? _pbkdf2Iterations;
    final expectedB64 = parts[2];

    try {
      final saltBytes = base64Decode(storedSalt);
      final derived = _pbkdf2HmacSha256(
        password: utf8.encode(pin),
        salt: saltBytes,
        iterations: iterations,
        keyLength: _pbkdf2KeyLength,
      );
      final actualB64 = base64Encode(derived);
      if (_constantTimeEquals(actualB64, expectedB64)) {
        await _resetFailedAttempts();
        return true;
      }
    } catch (e) {
      debugPrint('SecurityService verify error: ${e.runtimeType}');
    }

    await _recordFailedAttempt();
    return false;
  }

  Future<Duration> getRemainingLockout() async {
    final rawUntil = await _safeRead(_lockoutUntilKey);
    if (rawUntil == null) return Duration.zero;
    final untilMs = int.tryParse(rawUntil);
    if (untilMs == null) return Duration.zero;
    final until = DateTime.fromMillisecondsSinceEpoch(untilMs);
    final diff = until.difference(DateTime.now());
    if (diff <= Duration.zero) {
      return Duration.zero;
    }
    return diff;
  }

  Future<int> getFailedAttempts() async {
    final raw = await _safeRead(_failedAttemptsKey);
    return int.tryParse(raw ?? '') ?? 0;
  }

  Future<void> _recordFailedAttempt() async {
    final attempts = (await getFailedAttempts()) + 1;
    await _safeWrite(_failedAttemptsKey, attempts.toString());

    Duration? lockout;
    if (attempts >= 10) {
      lockout = const Duration(minutes: 5);
    } else if (attempts >= 5) {
      lockout = const Duration(seconds: 30);
    }

    if (lockout != null) {
      final until = DateTime.now().add(lockout).millisecondsSinceEpoch;
      await _safeWrite(_lockoutUntilKey, until.toString());
    }
  }

  Future<void> _resetFailedAttempts() async {
    await _safeDelete(_failedAttemptsKey);
    await _safeDelete(_lockoutUntilKey);
  }

  Future<bool> isPinConfigured() async {
    final pinHash = await _safeRead(_pinKey);
    return pinHash != null && pinHash.isNotEmpty;
  }

  Future<void> clearPin() async {
    await _safeDelete(_pinKey);
    await _safeDelete(_pinSaltKey);
    await _safeDelete(_pinLengthKey);
    await _resetFailedAttempts();
    // Désactiver la biométrie si le PIN est supprimé
    await saveBiometricsEnabled(false);
  }

  // --- Auto-Lock Timeout Settings ---

  Future<void> saveAutoLockMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoLockMinutesKey, minutes);
  }

  Future<int> getAutoLockMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_autoLockMinutesKey) ?? defaultAutoLockMinutes;
  }

  // --- Biometrics Management ---

  Future<void> saveBiometricsEnabled(bool enabled) async {
    await _safeWrite(_biometricsEnabledKey, enabled.toString());
  }

  Future<bool> isBiometricsEnabled() async {
    final isEnabled = await _safeRead(_biometricsEnabledKey);
    return isEnabled == 'true';
  }

  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } on PlatformException catch (e) {
      debugPrint('SecurityService biometrics check error: ${e.code}');
      return false;
    }
  }

  Future<bool> authenticate(String localizedReason) async {
    suppressNextResumeLock = true;
    try {
      return await _localAuth.authenticate(
        localizedReason: localizedReason,
        persistAcrossBackgrounding: true,
        biometricOnly: false,
      );
    } on PlatformException catch (e) {
      debugPrint('SecurityService biometrics auth error: ${e.code}');
      return false;
    } finally {
      Future.delayed(const Duration(seconds: 2), () {
        suppressNextResumeLock = false;
      });
    }
  }
}

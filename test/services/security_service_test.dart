import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/services/security_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InMemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> data = {};

  @override
  Future<String?> read({required String key}) async => data[key];

  @override
  Future<void> write({required String key, required String value}) async {
    data[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    data.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SecurityService PBKDF2, Migration & Anti-Bruteforce', () {
    test('savePin stores salted PBKDF2 hash and unique salt per save', () async {
      final storeA = InMemorySecureStore();
      final storeB = InMemorySecureStore();
      final secA = SecurityService(storage: storeA);
      final secB = SecurityService(storage: storeB);

      await secA.savePin('1234');
      await secB.savePin('1234');

      expect(storeA.data['APP_PIN_HASH'], startsWith('pbkdf2:10000:'));
      expect(storeA.data['APP_PIN_SALT'], isNotNull);
      expect(storeA.data['APP_PIN_SALT'], isNot(storeB.data['APP_PIN_SALT']));
      expect(storeA.data['APP_PIN_HASH'], isNot(storeB.data['APP_PIN_HASH']));

      expect(await secA.verifyPin('1234'), isTrue);
      expect(await secA.verifyPin('9999'), isFalse);
    });

    test('supports 6-digit PIN length persistence', () async {
      final store = InMemorySecureStore();
      final sec = SecurityService(storage: store);

      await sec.savePin('654321');
      expect(await sec.getPinLength(), 6);
      expect(await sec.verifyPin('654321'), isTrue);
      expect(await sec.verifyPin('654320'), isFalse);
    });

    test('migrates legacy unsalted SHA-256 PIN transparently on valid verify',
        () async {
      final store = InMemorySecureStore();
      final legacySha256 = sha256.convert(utf8.encode('4321')).toString();
      store.data['APP_PIN_HASH'] = legacySha256;

      final sec = SecurityService(storage: store);

      // Mauvais PIN d'abord : ne migre pas et échoue
      expect(await sec.verifyPin('0000'), isFalse);
      expect(store.data['APP_PIN_HASH'], legacySha256);

      // Bon PIN : valide et migre automatiquement vers PBKDF2 salé
      expect(await sec.verifyPin('4321'), isTrue);
      expect(store.data['APP_PIN_HASH'], startsWith('pbkdf2:10000:'));
      expect(store.data['APP_PIN_SALT'], isNotNull);
      expect(await sec.getFailedAttempts(), 0);

      // Vérification suivante fonctionne avec le nouveau format PBKDF2
      expect(await sec.verifyPin('4321'), isTrue);
    });

    test('triggers lockout after 5 failed attempts and blocks valid PIN',
        () async {
      final store = InMemorySecureStore();
      final sec = SecurityService(storage: store);
      await sec.savePin('1357');

      for (var i = 0; i < 4; i++) {
        expect(await sec.verifyPin('0000'), isFalse);
        expect(await sec.getRemainingLockout(), Duration.zero);
      }

      // 5e échec -> lockout de 30s
      expect(await sec.verifyPin('0000'), isFalse);
      expect(await sec.getFailedAttempts(), 5);
      final lockout = await sec.getRemainingLockout();
      expect(lockout.inSeconds, greaterThan(20));

      // Même le bon PIN est refusé pendant le lockout
      expect(await sec.verifyPin('1357'), isFalse);
    });

    test('clearPin removes hash, salt, length, lockout and disables biometrics',
        () async {
      final store = InMemorySecureStore();
      final sec = SecurityService(storage: store);

      await sec.savePin('1234');
      await sec.saveBiometricsEnabled(true);
      await sec.verifyPin('0000');

      await sec.clearPin();
      expect(await sec.isPinConfigured(), isFalse);
      expect(store.data['APP_PIN_SALT'], isNull);
      expect(store.data['APP_PIN_LENGTH'], isNull);
      expect(await sec.getFailedAttempts(), 0);
      expect(await sec.isBiometricsEnabled(), isFalse);
    });

    test('auto-lock minutes defaults to 5 and persists changes', () async {
      final sec = SecurityService(storage: InMemorySecureStore());
      expect(await sec.getAutoLockMinutes(), 5);

      await sec.saveAutoLockMinutes(0);
      expect(await sec.getAutoLockMinutes(), 0);

      await sec.saveAutoLockMinutes(-1);
      expect(await sec.getAutoLockMinutes(), -1);
    });
  });
}

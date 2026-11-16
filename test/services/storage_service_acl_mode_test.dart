import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/models/acl_engine_mode.dart';
import 'package:headscalemanager/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('StorageService isolation aclEngineMode par serveur', () {
    test('isole chaque serveur avec repli sur l’ancienne clé globale', () async {
      SharedPreferences.setMockInitialValues({
        'ACL_ENGINE_MODE': 'legacy',
        'ACL_ENGINE_MODE_EXPLICIT': true,
      });

      final storage = StorageService();
      await storage.init();

      // Repli sur l'ancienne clé globale pour un serveur sans préférence propre
      expect(
        await storage.getAclEngineMode(serverId: 'srv-a'),
        AclEngineMode.legacy,
      );
      expect(
        await storage.hasExplicitAclEngineMode(serverId: 'srv-a'),
        isTrue,
      );

      // Enregistrer un mode différent sur srv-b ne doit pas affecter srv-a
      await storage.saveAclEngineMode(
        AclEngineMode.grantsV29,
        serverId: 'srv-b',
      );

      expect(
        await storage.getAclEngineMode(serverId: 'srv-b'),
        AclEngineMode.grantsV29,
      );
      expect(
        await storage.getAclEngineMode(serverId: 'srv-a'),
        AclEngineMode.legacy,
      );
    });
  });
}

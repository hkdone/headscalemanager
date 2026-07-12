import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/services/acl/policy_file_service.dart';

void main() {
  group('PolicyFileService', () {
    test('allowAllTemplate contient acls accept * -> *:*', () {
      final policy = PolicyFileService.allowAllTemplate();
      expect(policy['acls'], isA<List>());
      final acls = policy['acls'] as List;
      expect(acls.length, 1);
      expect(acls.first['action'], 'accept');
      expect(acls.first['src'], ['*']);
      expect(acls.first['dst'], ['*:*']);
      expect(policy['grants'], isEmpty);
    });

    test('parsePolicyContent accepte une policy grants valide', () {
      const raw = '''
      {
        "grants": [
          {"src": ["tag:foo"], "dst": ["tag:bar"], "ip": ["192.168.1.0/24"]}
        ]
      }
      ''';
      final policy = PolicyFileService.parsePolicyContent(raw);
      expect(policy['grants'], hasLength(1));
    });

    test('parsePolicyContent rejette un JSON sans section connue', () {
      expect(
        () => PolicyFileService.parsePolicyContent('{"foo": 1}'),
        throwsFormatException,
      );
    });

    test('parsePolicyContent tolère les commentaires HuJSON', () {
      const raw = '''
      {
        // commentaire
        "acls": []
      }
      ''';
      final policy = PolicyFileService.parsePolicyContent(raw);
      expect(policy['acls'], isEmpty);
    });

    test('backupFileName inclut un horodatage', () {
      final name = PolicyFileService.backupFileName(
        at: DateTime(2026, 7, 11, 16, 30),
      );
      expect(name, 'headscale-policy-20260711-1630.json');
    });
  });
}

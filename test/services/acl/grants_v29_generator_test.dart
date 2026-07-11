import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/models/acl_engine_mode.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/services/acl/acl_policy_orchestrator.dart';
import 'package:headscalemanager/services/acl/grants_v29_generator.dart';

Node _lanNode({
  required String id,
  required String user,
  required String normalizedUser,
}) {
  return Node(
    id: id,
    machineKey: 'mk-$id',
    hostname: 'router-$normalizedUser',
    name: 'router-$normalizedUser',
    user: user,
    userId: 'uid-$id',
    ipAddresses: const ['100.64.0.1'],
    online: true,
    lastSeen: DateTime.utc(2026, 1, 1),
    sharedRoutes: const ['192.168.1.0/24'],
    availableRoutes: const ['192.168.1.0/24'],
    isExitNode: false,
    isLanSharer: true,
    tags: [
      'tag:$normalizedUser-client',
      'tag:$normalizedUser-lan-sharer',
    ],
    baseDomain: 'example.com',
    endpoint: '',
  );
}

void main() {
  group('GrantsV29GeneratorService', () {
    final generator = GrantsV29GeneratorService();
    const lanCidr = '192.168.1.0/24';

    final users = [
      User(id: '1', name: 'jean@synology.me', createdAt: DateTime.utc(2026)),
      User(
          id: '2', name: 'clarisse@synology.me', createdAt: DateTime.utc(2026)),
    ];

    final nodes = [
      _lanNode(id: 'j1', user: 'jean@synology.me', normalizedUser: 'jean'),
      _lanNode(
          id: 'c1', user: 'clarisse@synology.me', normalizedUser: 'clarisse'),
    ];

    test('generates distinct via tags for same LAN CIDR per user', () {
      final policy = generator.generatePolicy(
        users: users,
        nodes: nodes,
        serverVersion: '0.29.0',
      );

      final grants = policy['grants'] as List;
      expect(grants, isNotEmpty);

      final jeanLanGrants = grants.where((g) {
        final map = g as Map;
        final dst = map['dst'] as List?;
        final via = map['via'] as List?;
        return dst != null &&
            dst.contains(lanCidr) &&
            via != null &&
            via.contains('tag:jean-lan-sharer');
      });
      expect(jeanLanGrants, isNotEmpty);

      final clarisseLanGrants = grants.where((g) {
        final map = g as Map;
        final dst = map['dst'] as List?;
        final via = map['via'] as List?;
        return dst != null &&
            dst.contains(lanCidr) &&
            via != null &&
            via.contains('tag:clarisse-lan-sharer');
      });
      expect(clarisseLanGrants, isNotEmpty);

      // Aucun grant LAN ne doit croiser les tags via entre utilisateurs
      for (final g in grants) {
        final map = g as Map;
        final dst = map['dst'] as List?;
        final via = map['via'] as List?;
        if (dst == null || !dst.contains(lanCidr) || via == null) continue;
        final viaTag = via.first as String;
        expect(
          viaTag == 'tag:jean-lan-sharer' || viaTag == 'tag:clarisse-lan-sharer',
          isTrue,
        );
        if (viaTag == 'tag:jean-lan-sharer') {
          expect(via, isNot(contains('tag:clarisse-lan-sharer')));
        }
      }
    });

    test('policy includes grants key and standard infrastructure', () {
      final policy = generator.generatePolicy(
        users: users,
        nodes: nodes,
        serverVersion: '0.29.0',
      );

      expect(policy['grants'], isA<List>());
      expect(policy['groups'], contains('group:jean'));
      expect(policy['groups'], contains('group:clarisse'));
      expect(policy['tagOwners'], isNotEmpty);
    });
  });

  group('AclPolicyOrchestrator grantsV29', () {
    test('uses grants engine when server is 0.29+', () {
      final orchestrator = AclPolicyOrchestrator();
      final users = [
        User(id: '1', name: 'jean@synology.me', createdAt: DateTime.utc(2026)),
      ];
      final nodes = [
        _lanNode(id: 'j1', user: 'jean@synology.me', normalizedUser: 'jean'),
      ];

      final policy = orchestrator.generatePolicy(
        engineMode: AclEngineMode.grantsV29,
        users: users,
        nodes: nodes,
        serverVersion: '0.29.0',
      );

      expect(policy['grants'], isNotEmpty);
    });

    test('falls back to standard when server is below 0.29', () {
      final orchestrator = AclPolicyOrchestrator();
      final users = [
        User(id: '1', name: 'jean@synology.me', createdAt: DateTime.utc(2026)),
      ];
      final nodes = [
        Node(
          id: 'n1',
          machineKey: 'mk-n1',
          hostname: 'host-n1',
          name: 'node-n1',
          user: 'jean@synology.me',
          userId: 'uid-n1',
          ipAddresses: const ['100.64.0.1'],
          online: true,
          lastSeen: DateTime.utc(2026, 1, 1),
          sharedRoutes: const [],
          availableRoutes: const [],
          isExitNode: false,
          isLanSharer: false,
          tags: const ['tag:jean-client'],
          baseDomain: 'example.com',
          endpoint: '',
        ),
      ];

      final policy = orchestrator.generatePolicy(
        engineMode: AclEngineMode.grantsV29,
        users: users,
        nodes: nodes,
        serverVersion: '0.28.0',
      );

      expect(policy['acls'], isNotEmpty);
      expect(policy.containsKey('grants'), isFalse);
    });
  });
}

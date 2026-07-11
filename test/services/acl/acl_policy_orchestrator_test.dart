import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/models/acl_engine_mode.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/services/acl/acl_policy_orchestrator.dart';
import 'package:headscalemanager/services/acl/taildrive_builder.dart';

Node _node({
  required String id,
  required String user,
  required List<String> tags,
  List<String> sharedRoutes = const [],
}) {
  return Node(
    id: id,
    machineKey: 'mk-$id',
    hostname: 'host-$id',
    name: 'node-$id',
    user: user,
    userId: 'uid-$id',
    ipAddresses: const ['100.64.0.1'],
    online: true,
    lastSeen: DateTime.utc(2026, 1, 1),
    sharedRoutes: sharedRoutes,
    availableRoutes: sharedRoutes,
    isExitNode: false,
    isLanSharer: false,
    tags: tags,
    baseDomain: 'example.com',
    endpoint: '',
  );
}

void main() {
  group('AclPolicyOrchestrator', () {
    final orchestrator = AclPolicyOrchestrator();
    final users = [User(id: '1', name: 'jean@synology.me', createdAt: DateTime.utc(2026))];
    final nodes = [
      _node(
        id: 'n1',
        user: 'jean@synology.me',
        tags: ['tag:jean-client'],
      ),
    ];

    test('standard engine produces tag-based ACL rules', () {
      final policy = orchestrator.generatePolicy(
        engineMode: AclEngineMode.standard,
        users: users,
        nodes: nodes,
      );

      expect(policy['groups'], contains('group:jean'));
      expect(policy['acls'], isNotEmpty);
      final firstAcl = (policy['acls'] as List).first as Map;
      expect(firstAcl['src'], contains('tag:jean-client'));
    });

    test('legacy engine produces ACL rules for tagged nodes', () {
      final policy = orchestrator.generatePolicy(
        engineMode: AclEngineMode.legacy,
        users: users,
        nodes: [
          _node(
            id: 'n2',
            user: 'jean@synology.me',
            tags: ['tag:jean-client;exit-node'],
          ),
        ],
      );

      expect(policy['acls'], isNotEmpty);
    });
  });

  group('TaildriveBuilder', () {
    test('returns null when server version is below 0.29', () {
      final result = TaildriveBuilder.build(
        shares: const [],
        nodes: const [],
        serverVersion: '0.28.0',
      );
      expect(result, isNull);
    });

    test('returns null when shares list is empty on 0.29', () {
      final result = TaildriveBuilder.build(
        shares: const [],
        nodes: const [],
        serverVersion: '0.29.0',
      );
      expect(result, isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/services/acl/policy_orphan_cleaner.dart';

User _makeUser(String name) => User(
      id: 'u-$name',
      name: name,
      createdAt: DateTime(2026, 11, 16),
      email: '$name@example.com',
    );

Node _makeNode(String name, String user, List<String> tags) => Node(
      id: 'n-$name',
      machineKey: 'mk-$name',
      hostname: name,
      name: name,
      user: user,
      userId: 'u-$user',
      ipAddresses: ['100.64.0.10'],
      online: true,
      lastSeen: DateTime(2026, 11, 16),
      sharedRoutes: const [],
      availableRoutes: const [],
      isExitNode: false,
      isLanSharer: false,
      tags: tags,
      baseDomain: 'example.com',
      endpoint: '',
    );

void main() {
  group('PolicyOrphanCleaner', () {
    final activeUsers = [_makeUser('alice')];
    final activeNodes = [
      _makeNode('alice-pc', 'alice', ['tag:alice-client']),
    ];

    test('détecte et purge un utilisateur supprimé dans groups, tagOwners, autoApprovers, acls et grants', () {
      final policy = {
        'groups': {
          'group:alice': ['alice@example.com'],
          'group:bob': ['bob@example.com'],
          'group:admins': ['alice@example.com'], // Groupe custom avec membre actif
        },
        'tagOwners': {
          'tag:alice-client': ['group:alice'],
          'tag:bob-client': ['group:bob'],
          'tag:bob-exit-node': ['group:bob'],
        },
        'autoApprovers': {
          'routes': {
            '0.0.0.0/0': ['tag:bob-exit-node'],
            '192.168.1.0/24': ['tag:alice-lan-sharer'],
          }
        },
        'acls': [
          {
            'action': 'accept',
            'src': ['tag:bob-client'],
            'dst': ['tag:alice-client:*'],
          },
          {
            'action': 'accept',
            'src': ['tag:alice-client'],
            'dst': ['tag:alice-client:*'],
          },
        ],
        'grants': [
          {
            'src': ['group:bob'],
            'dst': ['tag:bob-client'],
            'ip': ['*'],
          },
          {
            'src': ['tag:alice-client'],
            'dst': ['tag:alice-client'],
            'ip': ['*'],
          },
        ],
      };

      final info = PolicyOrphanCleaner.inspectOrphans(
        policy,
        users: activeUsers,
        nodes: activeNodes,
      );
      expect(info.orphanGroups, {'group:bob'});
      expect(info.orphanTags, {'tag:bob-client', 'tag:bob-exit-node'});
      expect(info.hasOrphanReferences, isTrue);

      final cleaned = PolicyOrphanCleaner.cleanOrphans(
        policy,
        users: activeUsers,
        nodes: activeNodes,
      );

      final cleanedGroups = cleaned['groups'] as Map<String, dynamic>;
      expect(cleanedGroups.containsKey('group:alice'), isTrue);
      expect(cleanedGroups.containsKey('group:admins'), isTrue);
      expect(cleanedGroups.containsKey('group:bob'), isFalse);

      final cleanedTagOwners = cleaned['tagOwners'] as Map<String, dynamic>;
      expect(cleanedTagOwners.containsKey('tag:bob-client'), isFalse);
      expect(cleanedTagOwners.containsKey('tag:bob-exit-node'), isFalse);
      expect(cleanedTagOwners.containsKey('tag:alice-client'), isTrue);

      final routes =
          (cleaned['autoApprovers'] as Map)['routes'] as Map<String, dynamic>;
      expect(routes.containsKey('0.0.0.0/0'), isFalse);

      expect((cleaned['acls'] as List).length, 1);
      expect((cleaned['grants'] as List).length, 1);
    });
  });
}

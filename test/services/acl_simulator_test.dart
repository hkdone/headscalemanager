import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/services/acl/grants_v29_generator.dart';
import 'package:headscalemanager/services/acl_parser_service.dart';
import 'package:headscalemanager/services/standard_acl_generator_service.dart';
import 'package:headscalemanager/widgets/acl/ssh_rules_list_view.dart';

void main() {
  Node makeNode({
    required String id,
    required String name,
    required String user,
    required List<String> ips,
    List<String> tags = const [],
    List<String> sharedRoutes = const [],
  }) {
    return Node(
      id: id,
      machineKey: 'mk-$id',
      name: name,
      hostname: name,
      user: user,
      userId: 'uid-$user',
      ipAddresses: ips,
      tags: tags,
      sharedRoutes: sharedRoutes,
      availableRoutes: sharedRoutes,
      isExitNode: sharedRoutes.contains('0.0.0.0/0'),
      isLanSharer: sharedRoutes.any((r) => r != '0.0.0.0/0' && r != '::/0'),
      lastSeen: DateTime(2026, 11, 16),
      baseDomain: 'headscale.local',
      endpoint: '',
      online: true,
    );
  }

  final users = [
    User(id: '1', name: 'alice', createdAt: DateTime(2025)),
    User(id: '2', name: 'bob', createdAt: DateTime(2025)),
  ];

  final laptop = makeNode(
    id: '10',
    name: 'alice-laptop',
    user: 'alice',
    ips: ['100.64.0.10'],
    tags: ['tag:alice-client'],
  );
  final nas = makeNode(
    id: '11',
    name: 'bob-nas',
    user: 'bob',
    ips: ['100.64.0.20'],
    tags: ['tag:bob-client', 'tag:bob-lan-sharer', 'tag:bob-exit-node'],
    sharedRoutes: ['192.168.10.0/24', '0.0.0.0/0'],
  );

  group('AclParserService.simulateConnection', () {
    test('evaluates grants with port/protocol, via router, and denies unmatched ports', () {
      final policy = {
        'grants': [
          {
            'src': ['tag:alice-client'],
            'dst': ['192.168.10.0/24'],
            'via': ['tag:bob-lan-sharer'],
            'ip': ['tcp:443', 'tcp:8000-8080'],
          },
          {
            'src': ['tag:alice-client'],
            'dst': ['autogroup:internet'],
            'via': ['tag:bob-exit-node'],
            'ip': ['*'],
          },
        ],
      };

      final parser = AclParserService(
        aclPolicy: policy,
        allNodes: [laptop, nas],
        allUsers: users,
      );

      final lanAllowed = parser.simulateConnection(
        sourceNode: laptop,
        destination: '192.168.10.50',
        port: '443',
        protocol: 'tcp',
      );
      expect(lanAllowed.allowed, isTrue);
      expect(lanAllowed.matchedRuleType, 'grant');
      expect(lanAllowed.viaTag, 'tag:bob-lan-sharer');
      expect(lanAllowed.viaNode?.id, '11');

      final rangeAllowed = parser.simulateConnection(
        sourceNode: laptop,
        destination: '192.168.10.50',
        port: '8080',
        protocol: 'tcp',
      );
      expect(rangeAllowed.allowed, isTrue);

      final lanBlockedPort = parser.simulateConnection(
        sourceNode: laptop,
        destination: '192.168.10.50',
        port: '22',
        protocol: 'tcp',
      );
      expect(lanBlockedPort.allowed, isFalse);

      final internetAllowed = parser.simulateConnection(
        sourceNode: laptop,
        destination: 'autogroup:internet',
        protocol: 'tcp',
      );
      expect(internetAllowed.allowed, isTrue);
      expect(internetAllowed.viaNode?.id, '11');
    });

    test('evaluates classic acls with hosts alias and proto filter', () {
      final policy = {
        'groups': {
          'group:alice': ['alice'],
        },
        'hosts': {
          'nas-lan': '192.168.10.42',
        },
        'acls': [
          {
            'action': 'accept',
            'proto': 'tcp',
            'src': ['group:alice'],
            'dst': ['nas-lan:22,443'],
          },
        ],
      };

      final parser = AclParserService(
        aclPolicy: policy,
        allNodes: [laptop, nas],
        allUsers: users,
      );

      final allowed = parser.simulateConnection(
        sourceNode: laptop,
        destination: '192.168.10.42',
        port: '22',
        protocol: 'tcp',
      );
      expect(allowed.allowed, isTrue);
      expect(allowed.matchedRuleType, 'acl');
      expect(allowed.viaNode?.id, '11');

      final wrongProto = parser.simulateConnection(
        sourceNode: laptop,
        destination: '192.168.10.42',
        port: '22',
        protocol: 'udp',
      );
      expect(wrongProto.allowed, isFalse);
    });
  });

  group('Policy tests validation & pruning', () {
    test('detects dead node IP and tag references and prunes safely', () {
      final policy = {
        'tagOwners': {
          'tag:alice-client': ['group:alice'],
        },
        'tests': [
          {
            'src': '100.64.0.10',
            'accept': ['100.64.0.99:443', '192.168.10.50:443'],
            'deny': ['tag:ghost-tag:22', '100.64.0.20:*'],
          },
          {
            'src': '100.64.0.250',
            'accept': ['100.64.0.10:443'],
          },
        ],
      };

      final validation = AclParserService.validatePolicyTests(
        policy,
        allNodes: [laptop, nas],
        allUsers: users,
      );
      expect(validation.isValid, isFalse);
      expect(validation.issues.length, 4);

      final cleaned = AclParserService.pruneObsoletePolicyTests(
        policy,
        allNodes: [laptop, nas],
        allUsers: users,
      );
      final tests = cleaned['tests'] as List;
      expect(tests.length, 1);
      expect((tests.first as Map)['accept'], ['192.168.10.50:443']);
      expect((tests.first as Map).containsKey('deny'), isFalse);
    });
  });

  group('OIDC multi-identifier ACL generation', () {
    test('keeps rules for OIDC user whose node tag uses email or has no tags', () {
      final oidcEmailUser = User(
        id: 'u-oidc-1',
        name: 'oidc_sub_123',
        email: 'marine.leclerc@example.com',
        displayName: 'Marine Leclerc',
        createdAt: DateTime(2026),
      );
      final oidcUntaggedUser = User(
        id: 'u-oidc-2',
        name: 'paul.oidc',
        email: 'paul@example.com',
        createdAt: DateTime(2026),
      );

      final oidcTaggedNode = makeNode(
        id: '201',
        name: 'marine-phone',
        user: 'tagged-devices',
        ips: ['100.64.0.201'],
        tags: ['tag:marine-leclerc-client'],
      );
      final oidcUntaggedNode = makeNode(
        id: '202',
        name: 'paul-laptop',
        user: 'paul@example.com',
        ips: ['100.64.0.202'],
        tags: const [],
      );

      final grantsPolicy = GrantsV29GeneratorService().generatePolicy(
        users: [oidcEmailUser, oidcUntaggedUser],
        nodes: [oidcTaggedNode, oidcUntaggedNode],
        serverVersion: '0.29.7',
      );
      final grants = grantsPolicy['grants'] as List;
      expect(
        grants.any((g) =>
            ((g as Map)['src'] as List).contains('tag:marine-leclerc-client')),
        isTrue,
      );
      expect(
        grants.any(
            (g) => ((g as Map)['src'] as List).contains('group:paul-oidc')),
        isTrue,
      );

      final stdPolicy = StandardAclGeneratorService().generatePolicy(
        users: [oidcEmailUser, oidcUntaggedUser],
        nodes: [oidcTaggedNode, oidcUntaggedNode],
        serverVersion: '0.29.7',
      );
      final acls = stdPolicy['acls'] as List;
      expect(
        acls.any((r) =>
            ((r as Map)['src'] as List).contains('tag:marine-leclerc-client')),
        isTrue,
      );
      expect(
        acls.any(
            (r) => ((r as Map)['src'] as List).contains('group:paul-oidc')),
        isTrue,
      );
    });
  });

  group('SshRuleValidator', () {
    test('rejects invalid SSH destinations and accepts autogroup:self / tags', () {
      expect(
        SshRuleValidator.validate(
          src: const ['group:alice'],
          dst: const ['autogroup:self'],
          users: const ['autogroup:nonroot'],
          isFr: true,
        ),
        isNull,
      );

      expect(
        SshRuleValidator.validate(
          src: const ['group:alice'],
          dst: const ['tag:bob-client'],
          users: const ['root'],
          isFr: true,
        ),
        isNull,
      );

      expect(
        SshRuleValidator.validate(
          src: const ['group:alice'],
          dst: const ['group:bob'],
          users: const ['autogroup:nonroot'],
          isFr: true,
        ),
        isNotNull,
      );

      expect(
        SshRuleValidator.validate(
          src: const ['autogroup:member'],
          dst: const ['*'],
          users: const ['autogroup:nonroot'],
          isFr: false,
        ),
        isNotNull,
      );
    });
  });
}

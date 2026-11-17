import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/models/acl_engine_mode.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/services/acl/migration_assistant_service.dart';

User _user(String id, String name, {String? email}) => User(
      id: id,
      name: name,
      email: email,
      createdAt: DateTime(2026, 11, 17),
    );

Node _node({
  required String id,
  required String name,
  required String user,
  String? userId,
  required List<String> ips,
  List<String> tags = const [],
  List<String> sharedRoutes = const [],
}) =>
    Node(
      id: id,
      machineKey: 'mk-$id',
      hostname: name,
      name: name,
      user: user,
      userId: userId ?? 'u-$user',
      ipAddresses: ips,
      online: true,
      lastSeen: DateTime(2026, 11, 17),
      sharedRoutes: sharedRoutes,
      availableRoutes: sharedRoutes,
      isExitNode:
          sharedRoutes.contains('0.0.0.0/0') || sharedRoutes.contains('::/0'),
      isLanSharer:
          sharedRoutes.any((r) => r != '0.0.0.0/0' && r != '::/0'),
      tags: tags,
      baseDomain: 'example.com',
      endpoint: '',
    );

void main() {
  group('AclMigrationAssistantService', () {
    test('buildTailscaleReauthCommand inclut --advertise-tags= et routes existantes', () {
      final routerNode = _node(
        id: '1',
        name: 'nas',
        user: 'tagged-devices',
        ips: ['100.64.0.10'],
        tags: ['tag:jean-client', 'tag:jean-exit-node', 'tag:jean-lan-sharer'],
        sharedRoutes: ['0.0.0.0/0', '192.168.1.0/24', '10.0.0.0/8'],
      );

      final cmd = AclMigrationAssistantService.buildTailscaleReauthCommand(
        node: routerNode,
        serverUrl: 'https://hs.example.com/',
      );

      expect(
        cmd,
        'tailscale up --login-server=https://hs.example.com --advertise-tags= --force-reauth --advertise-exit-node --advertise-routes=192.168.1.0/24,10.0.0.0/8',
      );
    });

    test('Parcours A : prépare le filet d\'accueil hybride et valide la bascule sans tag', () {
      final jean = _user('u1', 'jean@synology.me');
      final ely = _user('u2', 'ely@synology.me', email: 'jean.virassa@gmail.com');

      final jeanRouter = _node(
        id: 'n1',
        name: 'nas-jean',
        user: 'tagged-devices',
        userId: 'u1',
        ips: ['100.64.0.15'],
        tags: ['tag:jean-client', 'tag:jean-exit-node'],
        sharedRoutes: ['0.0.0.0/0'],
      );
      final elyTagged = _node(
        id: 'n2',
        name: 'dkdone',
        user: 'tagged-devices',
        userId: 'u2',
        ips: ['100.64.0.20'],
        tags: ['tag:ely-client'],
      );
      final elyLaptop = _node(
        id: 'n3',
        name: 'laptop-ely',
        user: 'tagged-devices',
        userId: 'u2',
        ips: ['100.64.0.21'],
        tags: ['tag:ely-client'],
      );

      final serverPolicyBefore = {
        'groups': {
          'group:jean': ['jean@synology.me'],
          'group:ely': ['jean.virassa@gmail.com', 'ely@synology.me'],
        },
        'grants': [
          {
            'src': ['tag:ely-client'],
            'dst': ['tag:ely-client'],
            'ip': ['*'],
          }
        ],
      };

      expect(
        AclMigrationAssistantService.isHybridNetReadyForUser(
          serverPolicy: serverPolicyBefore,
          targetUser: ely,
        ),
        isFalse,
      );

      final prepared = AclMigrationAssistantService.buildPreparedWelcomePolicy(
        engineMode: AclEngineMode.grantsV29,
        users: [jean, ely],
        nodes: [jeanRouter, elyTagged, elyLaptop],
        serverPolicy: serverPolicyBefore,
        targetUser: ely,
        serverVersion: '0.29.2',
      );

      expect(
        AclMigrationAssistantService.isHybridNetReadyForUser(
          serverPolicy: prepared,
          targetUser: ely,
        ),
        isTrue,
      );

      // Simulation de la reconnexion de dkdone sans tag sous ely@synology.me
      final dkdoneUntagged = _node(
        id: 'n2-new',
        name: 'dkdone',
        user: 'ely@synology.me',
        userId: 'u2',
        ips: ['100.64.0.44'],
        tags: const [],
      );
      final latestNodes = [jeanRouter, dkdoneUntagged, elyLaptop];
      final hybridPolicy = AclMigrationAssistantService.buildPreparedWelcomePolicy(
        engineMode: AclEngineMode.grantsV29,
        users: [jean, ely],
        nodes: latestNodes,
        serverPolicy: prepared,
        targetUser: ely,
        serverVersion: '0.29.2',
      );

      final report = AclMigrationAssistantService.verifyTaglessTransition(
        originalTaggedNode: elyTagged,
        targetUser: ely,
        latestNodes: latestNodes,
        latestUsers: [jean, ely],
        serverPolicy: hybridPolicy,
        isFr: true,
      );

      expect(report.found, isTrue);
      expect(report.isUntagged, isTrue);
      expect(report.belongsToTargetUser, isTrue);
      expect(report.verifiedPeerCount, 1);
      expect(report.isFullyValidated, isTrue);
    });

    test('détecte les routes manquantes à ré-approuver après reconnexion sans tag', () {
      final paul = _user('u3', 'paul');
      final origRouter = _node(
        id: 'n10',
        name: 'gw-paul',
        user: 'tagged-devices',
        userId: 'u3',
        ips: ['100.64.0.60'],
        tags: ['tag:paul-client', 'tag:paul-lan-sharer'],
        sharedRoutes: ['192.168.10.0/24'],
      );
      final reauthRouter = _node(
        id: 'n10-new',
        name: 'gw-paul',
        user: 'paul',
        userId: 'u3',
        ips: ['100.64.0.60'],
        tags: const [],
        sharedRoutes: const [],
      );

      final policy = AclMigrationAssistantService.buildPreparedWelcomePolicy(
        engineMode: AclEngineMode.grantsV29,
        users: [paul],
        nodes: [reauthRouter],
        serverPolicy: null,
        targetUser: paul,
        serverVersion: '0.29.2',
      );

      final report = AclMigrationAssistantService.verifyTaglessTransition(
        originalTaggedNode: origRouter,
        targetUser: paul,
        latestNodes: [reauthRouter],
        latestUsers: [paul],
        serverPolicy: policy,
        isFr: true,
      );

      expect(report.missingRoutes, ['192.168.10.0/24']);
      expect(report.isFullyValidated, isFalse);
    });
  });
}

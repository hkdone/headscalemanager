import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/taildrive_share.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/services/acl/grants_v29_generator.dart';
import 'package:headscalemanager/services/acl/grant_composer_service.dart';
import 'package:headscalemanager/services/acl/policy_orphan_cleaner.dart';
import 'package:headscalemanager/services/acl/policy_preserver.dart';
import 'package:headscalemanager/services/acl/taildrive_builder.dart';
import 'package:headscalemanager/services/acl_parser_service.dart';
import 'package:headscalemanager/services/standard_acl_generator_service.dart';

User _user({
  required String id,
  required String name,
  String? email,
  String? displayName,
}) {
  return User(
    id: id,
    name: name,
    email: email,
    displayName: displayName,
    createdAt: DateTime(2026, 11, 17),
  );
}

Node _node({
  required String id,
  required String name,
  required String user,
  String? userId,
  required List<String> ips,
  List<String> tags = const [],
  List<String> sharedRoutes = const [],
}) {
  return Node(
    id: id,
    machineKey: 'mk-$id',
    hostname: name,
    name: name,
    user: user,
    userId: userId ?? 'uid-$user',
    ipAddresses: ips,
    online: true,
    lastSeen: DateTime(2026, 11, 17),
    sharedRoutes: sharedRoutes,
    availableRoutes: sharedRoutes,
    isExitNode: sharedRoutes.contains('0.0.0.0/0') || sharedRoutes.contains('::/0'),
    isLanSharer:
        sharedRoutes.any((r) => r != '0.0.0.0/0' && r != '::/0'),
    tags: tags,
    baseDomain: 'example.com',
    endpoint: '',
  );
}

void main() {
  group('Sous-Plan 09-A — Cœur Hybride Zéro-Coupure', () {
    test('non-régression stricte pour un parc 100 % tagué', () {
      final jean = _user(id: 'u1', name: 'jean', email: 'jean@example.com');
      final nas = _node(
        id: 'n1',
        name: 'nas-jean',
        user: 'tagged-devices',
        userId: 'u1',
        ips: ['100.64.0.10'],
        tags: ['tag:jean-client', 'tag:jean-exit-node'],
        sharedRoutes: ['0.0.0.0/0'],
      );
      final pc = _node(
        id: 'n2',
        name: 'pc-jean',
        user: 'tagged-devices',
        userId: 'u1',
        ips: ['100.64.0.11'],
        tags: ['tag:jean-client'],
      );

      final grantsPolicy = GrantsV29GeneratorService().generatePolicy(
        users: [jean],
        nodes: [nas, pc],
        serverVersion: '0.29.7',
      );

      expect(grantsPolicy['hosts'], isEmpty);
      final grants = grantsPolicy['grants'] as List<dynamic>;
      final intraFleet = grants.firstWhere(
        (g) => (g['dst'] as List).contains('tag:jean-client'),
      ) as Map<String, dynamic>;
      expect(intraFleet['src'], ['tag:jean-client', 'tag:jean-exit-node']);
      expect(intraFleet['dst'], ['tag:jean-client', 'tag:jean-exit-node']);
      expect(
        grants.any((g) =>
            (g['src'] as List).contains('group:jean') &&
            (g['dst'] as List).contains('tag:jean-client')),
        isTrue,
      );

      final stdPolicy = StandardAclGeneratorService().generatePolicy(
        users: [jean],
        nodes: [nas, pc],
        serverVersion: '0.28.0',
      );
      expect(stdPolicy['hosts'], isEmpty);
      final acls = stdPolicy['acls'] as List<dynamic>;
      final mainAcl = acls.first as Map<String, dynamic>;
      expect(mainAcl['src'], ['tag:jean-client', 'tag:jean-exit-node']);
    });

    test('parc mixte (NAS tagué + mobile OIDC sans tag) unit tag et group dans les deux sens', () {
      final jean = _user(
        id: 'u1',
        name: 'jean',
        email: 'jean.dupont@gmail.com',
        displayName: 'Jean Dupont',
      );
      final taggedNas = _node(
        id: 'n1',
        name: 'nas-maison',
        user: 'tagged-devices',
        userId: 'u1',
        ips: ['100.64.0.10'],
        tags: ['tag:jean-client', 'tag:jean-exit-node', 'tag:jean-lan-sharer'],
        sharedRoutes: ['0.0.0.0/0', '192.168.1.0/24'],
      );
      final untaggedOidcMobile = _node(
        id: 'n2',
        name: 'Pixel_9',
        user: 'jean.dupont@gmail.com',
        userId: 'u1',
        ips: ['100.64.0.25/32'],
        tags: const [],
      );

      final grantsPolicy = GrantsV29GeneratorService().generatePolicy(
        users: [jean],
        nodes: [taggedNas, untaggedOidcMobile],
        serverVersion: '0.29.7',
      );

      final grants = grantsPolicy['grants'] as List<dynamic>;
      final intraFleet = grants.firstWhere(
        (g) => (g['dst'] as List).contains('group:jean'),
      ) as Map<String, dynamic>;
      expect(
        intraFleet['src'],
        containsAll(['tag:jean-client', 'tag:jean-exit-node', 'tag:jean-lan-sharer', 'group:jean']),
      );
      expect(
        intraFleet['dst'],
        containsAll(['tag:jean-client', 'tag:jean-exit-node', 'tag:jean-lan-sharer', 'group:jean']),
      );

      final exitGrant = grants.firstWhere(
        (g) => (g['dst'] as List).contains('autogroup:internet'),
      ) as Map<String, dynamic>;
      expect((exitGrant['src'] as List), contains('group:jean'));
      expect(exitGrant['via'], ['tag:jean-exit-node']);

      final lanGrant = grants.firstWhere(
        (g) => (g['dst'] as List).contains('192.168.1.0/24'),
      ) as Map<String, dynamic>;
      expect((lanGrant['src'] as List), contains('group:jean'));
      expect(lanGrant['via'], ['tag:jean-lan-sharer']);

      final hosts = grantsPolicy['hosts'] as Map<String, dynamic>;
      expect(hosts['host-jean-pixel-9'], '100.64.0.25');

      // Simulateur ACL : flux bidirectionnel ALLOW entre le NAS tagué et le mobile sans tag
      final parser = AclParserService(
        aclPolicy: grantsPolicy,
        allNodes: [taggedNas, untaggedOidcMobile],
        allUsers: [jean],
      );
      final nasToMobile = parser.simulateConnection(
        sourceNode: taggedNas,
        destination: '100.64.0.25',
      );
      final mobileToNas = parser.simulateConnection(
        sourceNode: untaggedOidcMobile,
        destination: '100.64.0.10',
      );
      final mobileToExit = parser.simulateConnection(
        sourceNode: untaggedOidcMobile,
        destination: 'autogroup:internet',
      );
      final mobileByHostAlias = parser.simulateConnection(
        sourceNode: taggedNas,
        destination: 'host-jean-pixel-9',
      );

      expect(nasToMobile.allowed, isTrue);
      expect(mobileToNas.allowed, isTrue);
      expect(mobileToExit.allowed, isTrue);
      expect(mobileByHostAlias.allowed, isTrue);

      // Mode Standard génère aussi l'union hybride
      final stdPolicy = StandardAclGeneratorService().generatePolicy(
        users: [jean],
        nodes: [taggedNas, untaggedOidcMobile],
        serverVersion: '0.28.0',
      );
      final stdAcls = stdPolicy['acls'] as List<dynamic>;
      final mainStd = stdAcls.first as Map<String, dynamic>;
      expect((mainStd['src'] as List), containsAll(['group:jean', 'tag:jean-client']));
      expect((mainStd['dst'] as List), containsAll(['group:jean:*', 'tag:jean-client:*', 'autogroup:internet:*']));
    });

    test('parc 100 % sans tags avec routeur sans tag génère autoApprovers, hosts uniques et grants sans via', () {
      final paul = _user(id: 'u2', name: 'paul');
      final router = _node(
        id: 'n10',
        name: 'Phone',
        user: 'paul',
        userId: 'u2',
        ips: ['100.64.0.50'],
        tags: const [],
        sharedRoutes: ['0.0.0.0/0', '192.168.50.0/24'],
      );
      final sameNameClient = _node(
        id: 'n11',
        name: 'Phone',
        user: 'paul',
        userId: 'u2',
        ips: ['100.64.0.51'],
        tags: const [],
      );

      final policy = GrantsV29GeneratorService().generatePolicy(
        users: [paul],
        nodes: [router, sameNameClient],
        serverVersion: '0.29.7',
      );

      expect(policy['groups'], {'group:paul': ['paul@']});

      final autoApprovers =
          (policy['autoApprovers'] as Map)['routes'] as Map<String, dynamic>;
      expect(autoApprovers['0.0.0.0/0'], ['group:paul']);
      expect(autoApprovers['192.168.50.0/24'], ['group:paul']);

      final hosts = policy['hosts'] as Map<String, dynamic>;
      expect(hosts['host-paul-phone'], '100.64.0.50');
      expect(hosts['host-paul-phone-2'], '100.64.0.51');

      final grants = policy['grants'] as List<dynamic>;
      final internetGrant = grants.firstWhere(
        (g) => (g['dst'] as List).contains('autogroup:internet'),
      ) as Map<String, dynamic>;
      expect(internetGrant['src'], ['group:paul']);
      expect(internetGrant.containsKey('via'), isFalse);

      final lanGrant = grants.firstWhere(
        (g) => (g['dst'] as List).contains('192.168.50.0/24'),
      ) as Map<String, dynamic>;
      expect(lanGrant['src'], ['group:paul']);
      expect(lanGrant.containsKey('via'), isFalse);
    });

    test('mode quarantaine (includeUntaggedNodes: false) exclut les nœuds sans tag', () {
      final jean = _user(id: 'u1', name: 'jean');
      final taggedNas = _node(
        id: 'n1',
        name: 'nas',
        user: 'tagged-devices',
        userId: 'u1',
        ips: ['100.64.0.10'],
        tags: ['tag:jean-client'],
      );
      final untaggedGuest = _node(
        id: 'n2',
        name: 'unknown',
        user: 'jean',
        userId: 'u1',
        ips: ['100.64.0.99'],
        tags: const [],
        sharedRoutes: ['192.168.99.0/24'],
      );

      final policy = GrantsV29GeneratorService().generatePolicy(
        users: [jean],
        nodes: [taggedNas, untaggedGuest],
        serverVersion: '0.29.7',
        includeUntaggedNodes: false,
      );

      expect(policy['hosts'], isEmpty);
      final autoApprovers =
          (policy['autoApprovers'] as Map)['routes'] as Map<String, dynamic>;
      expect(autoApprovers, isEmpty);
      final grants = policy['grants'] as List<dynamic>;
      expect(
        grants.every((g) => !(g['dst'] as List).contains('group:jean')),
        isTrue,
      );
    });

    test('PolicyPreserver._mergeHosts rafraîchit host-* et sanctuarise hosts manuels ; PolicyOrphanCleaner purge host-* obsolètes', () {
      final alice = _user(id: 'u1', name: 'alice');
      final untaggedPc = _node(
        id: 'n1',
        name: 'laptop',
        user: 'alice',
        userId: 'u1',
        ips: ['100.64.0.42'],
      );

      final generated = GrantsV29GeneratorService().generatePolicy(
        users: [alice],
        nodes: [untaggedPc],
        serverVersion: '0.29.7',
      );

      final server = {
        'hosts': {
          'host-alice-laptop': '100.64.0.10', // Ancienne IP avant backfill
          'host-alice-deleted': '100.64.0.99', // Nœud supprimé
          'nas-manuel': '192.168.1.50', // Entrée manuelle admin
        },
        'acls': [
          {
            'action': 'accept',
            'src': ['host-alice-deleted'],
            'dst': ['*:*'],
          },
          {
            'action': 'accept',
            'src': ['nas-manuel'],
            'dst': ['host-alice-laptop:443'],
          },
        ],
      };

      final merged = PolicyPreserver.merge(
        generated,
        server,
        preserveCustomRules: true,
      );
      final mergedHosts = merged['hosts'] as Map<String, dynamic>;
      expect(mergedHosts['host-alice-laptop'], '100.64.0.42');
      expect(mergedHosts['nas-manuel'], '192.168.1.50');
      expect(mergedHosts.containsKey('host-alice-deleted'), isFalse);

      final cleaned = PolicyOrphanCleaner.cleanOrphans(
        server,
        users: [alice],
        nodes: [untaggedPc],
      );
      final cleanedHosts = cleaned['hosts'] as Map<String, dynamic>;
      expect(cleanedHosts.containsKey('host-alice-deleted'), isFalse);
      expect(cleanedHosts['nas-manuel'], '192.168.1.50');
      expect((cleaned['acls'] as List).length, 1);
    });

    test('AclParserService résout autogroup:member uniquement sur nœuds humains sans tag et Taildrive résout OIDC via nodeBelongsToUser', () {
      final oidcUser = _user(
        id: 'u1',
        name: 'oidc_sub_42',
        email: 'claire.martin@example.com',
      );
      final untaggedMobile = _node(
        id: 'n1',
        name: 'iphone',
        user: 'claire.martin@example.com',
        userId: 'u1',
        ips: ['100.64.0.30'],
        tags: const [],
      );
      final taggedServer = _node(
        id: 'n2',
        name: 'srv',
        user: 'tagged-devices',
        userId: 'u1',
        ips: ['100.64.0.31'],
        tags: ['tag:oidc-sub-42-client'],
      );

      final tdConfig = TaildriveBuilder.build(
        shares: [
          TaildriveShare(
            sourceNodeId: 'n1',
            shareName: 'photos',
            localPath: '/data/photos',
            recipient: 'claire.martin@example.com',
            accessMode: TaildriveAccessMode.rw,
          ),
        ],
        nodes: [untaggedMobile, taggedServer],
        users: [oidcUser],
        serverVersion: '0.29.7',
      );
      expect(tdConfig, isNotNull);
      final tdGrant = (tdConfig!['grants'] as List).first as Map<String, dynamic>;
      expect(tdGrant['dst'], ['group:oidc-sub-42']);

      final parser = AclParserService(
        aclPolicy: {
          'groups': {
            'group:oidc-sub-42': ['claire.martin@example.com'],
          },
          'acls': [
            {
              'action': 'accept',
              'src': ['autogroup:member'],
              'dst': ['tag:oidc-sub-42-client:443'],
            }
          ],
        },
        allNodes: [untaggedMobile, taggedServer],
        allUsers: [oidcUser],
      );

      final memberAllowed = parser.simulateConnection(
        sourceNode: untaggedMobile,
        destination: '100.64.0.31',
        port: '443',
      );
      final taggedDenied = parser.simulateConnection(
        sourceNode: taggedServer,
        destination: '100.64.0.31',
        port: '443',
      );

      expect(memberAllowed.allowed, isTrue);
      expect(taggedDenied.allowed, isFalse);
    });

    test(
        'hybridation automatique des grants inter-utilisateurs existants (scénario dkdone sans tag sous ely vers exit node/LAN/AdGuard de jean)',
        () {
      final jean = _user(id: 'u1', name: 'jean@synology.me');
      final ely = _user(
        id: 'u4',
        name: 'ely@synology.me',
        email: 'jean.virassa@gmail.com',
      );
      final jeanRouter = _node(
        id: 'n1',
        name: 'nas-jean',
        user: 'tagged-devices',
        userId: 'u1',
        ips: ['100.64.0.15'],
        tags: ['tag:jean-client', 'tag:jean-exit-node', 'tag:jean-lan-sharer'],
        sharedRoutes: ['0.0.0.0/0', '192.168.1.0/24'],
      );
      final dkdoneUntagged = _node(
        id: 'n2',
        name: 'dkdone',
        user: 'ely@synology.me',
        userId: 'u4',
        ips: ['100.64.0.44'],
        tags: const [],
      );

      final allUsers = [jean, ely];
      final allNodes = [jeanRouter, dkdoneUntagged];

      final generated = GrantsV29GeneratorService().generatePolicy(
        users: allUsers,
        nodes: allNodes,
        serverVersion: '0.29.2',
      );

      // Politique serveur préalable : les 4 grants d'ely ne citaient que tag:ely-client
      final serverPolicy = {
        'grants': [
          {
            'src': ['tag:ely-client'],
            'dst': ['tag:jean-client'],
            'ip': ['*'],
          },
          {
            'src': ['tag:ely-client'],
            'dst': ['192.168.1.0/24'],
            'ip': ['*'],
            'via': ['tag:jean-lan-sharer'],
          },
          {
            'src': ['tag:ely-client'],
            'dst': ['autogroup:internet'],
            'ip': ['*'],
            'via': ['tag:jean-exit-node'],
          },
          {
            'src': ['tag:ely-client'],
            'dst': ['100.64.0.15'],
            'ip': ['*'],
            'via': ['tag:jean-lan-sharer'],
          },
        ],
      };

      final merged = PolicyPreserver.merge(
        generated,
        serverPolicy,
        preserveCustomRules: true,
        users: allUsers,
        nodes: allNodes,
        includeUntaggedNodes: true,
      );

      final mergedGrants = merged['grants'] as List<dynamic>;
      final crossExit = mergedGrants.firstWhere(
        (g) =>
            (g['dst'] as List).contains('autogroup:internet') &&
            (g['via'] as List?)?.contains('tag:jean-exit-node') == true &&
            (g['src'] as List).contains('tag:ely-client'),
      ) as Map<String, dynamic>;
      expect(crossExit['src'], containsAll(['tag:ely-client', 'group:ely']));

      // Simulateur : dkdone (sans tag) accède sans aucune édition manuelle JSON !
      final parser = AclParserService(
        aclPolicy: merged,
        allNodes: allNodes,
        allUsers: allUsers,
      );
      final exitResult = parser.simulateConnection(
        sourceNode: dkdoneUntagged,
        destination: 'autogroup:internet',
      );
      final lanResult = parser.simulateConnection(
        sourceNode: dkdoneUntagged,
        destination: '192.168.1.50',
        port: '443',
      );
      final adguardResult = parser.simulateConnection(
        sourceNode: dkdoneUntagged,
        destination: '100.64.0.15',
        port: '53',
        protocol: 'udp',
      );

      expect(exitResult.allowed, isTrue);
      expect(exitResult.viaTag, 'tag:jean-exit-node');
      expect(lanResult.allowed, isTrue);
      expect(lanResult.viaTag, 'tag:jean-lan-sharer');
      expect(adguardResult.allowed, isTrue);

      // GrantComposer propose désormais group:ely et host-ely-dkdone
      final sources = GrantComposerService.sourceTagOptions(
        users: allUsers,
        nodes: allNodes,
      ).map((o) => o.value).toList();
      expect(sources, containsAll(['group:ely', 'host-ely-dkdone']));
    });
  });
}

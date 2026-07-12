import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/models/acl_engine_mode.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/services/acl/grant_composer_service.dart';
import 'package:headscalemanager/utils/grants_v29_gate.dart';

Node _node({
  required String id,
  required String user,
  required List<String> tags,
  List<String> routes = const [],
  bool exit = false,
}) {
  return Node(
    id: id,
    machineKey: 'mk-$id',
    hostname: 'h-$id',
    name: 'n-$id',
    user: user,
    userId: 'u-$id',
    ipAddresses: const ['100.64.0.1'],
    online: true,
    lastSeen: DateTime.utc(2026, 1, 1),
    sharedRoutes: routes,
    availableRoutes: routes,
    isExitNode: exit,
    isLanSharer: routes.isNotEmpty && !exit,
    tags: tags,
    baseDomain: 'test.local',
    endpoint: '',
  );
}

void main() {
  group('GrantsV29Gate', () {
    test('available only for grantsV29 on 0.29+', () {
      expect(
        GrantsV29Gate.isAvailable(
          engineMode: AclEngineMode.grantsV29,
          serverVersion: '0.29.0',
        ),
        isTrue,
      );
      expect(
        GrantsV29Gate.isAvailable(
          engineMode: AclEngineMode.standard,
          serverVersion: '0.29.0',
        ),
        isFalse,
      );
      expect(
        GrantsV29Gate.isAvailable(
          engineMode: AclEngineMode.grantsV29,
          serverVersion: '0.28.0',
        ),
        isFalse,
      );
    });
  });

  group('GrantComposerService', () {
    final users = [
      User(id: '1', name: 'jean@test', createdAt: DateTime.utc(2026)),
    ];
    final nodes = [
      _node(
        id: '1',
        user: 'jean@test',
        tags: ['tag:jean-client', 'tag:jean-lan-sharer'],
        routes: const ['192.168.1.0/24'],
      ),
    ];

    test('builds LAN grant with via', () {
      final grant = GrantComposerService.buildNetworkGrant(
        src: ['tag:jean-client'],
        dst: ['192.168.1.0/24'],
        via: ['tag:jean-lan-sharer'],
      );
      expect(grant['via'], ['tag:jean-lan-sharer']);
      expect(grant['ip'], ['*']);
    });

    test('appendNetworkGrant avoids duplicates', () {
      final policy = {'grants': <dynamic>[]};
      final grant = GrantComposerService.buildNetworkGrant(
        src: ['tag:jean-client'],
        dst: ['192.168.1.0/24'],
        via: ['tag:jean-lan-sharer'],
      );
      final p1 = GrantComposerService.appendNetworkGrant(policy, grant);
      final p2 = GrantComposerService.appendNetworkGrant(p1, grant);
      expect((p2['grants'] as List).length, 1);
    });

    test('routerOptions finds lan sharer', () {
      final routers = GrantComposerService.routerOptions(
        nodes: nodes,
        forExit: false,
      );
      expect(routers, isNotEmpty);
      expect(routers.first.viaTag, 'tag:jean-lan-sharer');
    });

    test('sourceTagOptions requires tagged client node', () {
      final options = GrantComposerService.sourceTagOptions(
        users: users,
        nodes: nodes,
      );
      expect(options.map((o) => o.value), contains('tag:jean-client'));
    });
  });
}

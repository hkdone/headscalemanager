import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/models/acl_engine_mode.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/services/route_conflict_service.dart';

Node _makeNode({
  required String id,
  required String name,
  required String user,
  List<String> sharedRoutes = const [],
}) {
  return Node(
    id: id,
    machineKey: 'mk-$id',
    hostname: name,
    name: name,
    user: user,
    userId: 'uid-$user',
    ipAddresses: ['100.64.0.$id'],
    online: true,
    lastSeen: DateTime(2026, 11, 16),
    sharedRoutes: sharedRoutes,
    availableRoutes: sharedRoutes,
    isExitNode: false,
    isLanSharer: sharedRoutes.isNotEmpty,
    tags: const [],
    baseDomain: 'headscale.local',
    endpoint: '',
  );
}

void main() {
  group('RouteConflictService', () {
    final aliceRouter = _makeNode(
      id: '1',
      name: 'alice-lan',
      user: 'alice',
      sharedRoutes: ['192.168.1.0/24'],
    );
    final bobRouter = _makeNode(
      id: '2',
      name: 'bob-lan',
      user: 'bob',
      sharedRoutes: [],
    );
    final aliceHaRouter = _makeNode(
      id: '3',
      name: 'alice-lan-2',
      user: 'alice',
      sharedRoutes: [],
    );

    test('bloque un CIDR dupliqué en mode standard ou Headscale < 0.29', () {
      final standardRes = RouteConflictService.validateRouteApproval(
        '192.168.1.0/24',
        bobRouter.id,
        [aliceRouter, bobRouter],
        engineMode: AclEngineMode.standard,
        serverVersion: '0.29.7',
      );
      expect(standardRes.isConflict, isTrue);

      final oldServerRes = RouteConflictService.validateRouteApproval(
        '192.168.1.0/24',
        bobRouter.id,
        [aliceRouter, bobRouter],
        engineMode: AclEngineMode.grantsV29,
        serverVersion: '0.28.0',
      );
      expect(oldServerRes.isConflict, isTrue);
    });

    test('autorise avec warningSharedVia entre utilisateurs en Grants V29 >= 0.29', () {
      final res = RouteConflictService.validateRouteApproval(
        '192.168.1.0/24',
        bobRouter.id,
        [aliceRouter, bobRouter],
        engineMode: AclEngineMode.grantsV29,
        serverVersion: '0.29.7',
      );
      expect(res.type, RouteValidationType.warningSharedVia);
      expect(res.isConflict, isFalse);
      expect(res.isApproved, isTrue);
      expect(res.hasWarning, isTrue);
    });

    test('autorise avec warningHaFailover pour le même utilisateur en Grants V29', () {
      final res = RouteConflictService.validateRouteApproval(
        '192.168.1.0/24',
        aliceHaRouter.id,
        [aliceRouter, aliceHaRouter],
        engineMode: AclEngineMode.grantsV29,
        serverVersion: '0.29.7',
      );
      expect(res.type, RouteValidationType.warningHaFailover);
      expect(res.isConflict, isFalse);
      expect(res.hasWarning, isTrue);
    });

    test('findCrossUserDuplicateCidrs détecte les CIDR partagés inter-utilisateurs', () {
      final bobApproved = _makeNode(
        id: '2',
        name: 'bob-lan',
        user: 'bob',
        sharedRoutes: ['192.168.1.0/24', '0.0.0.0/0'],
      );
      final aliceApproved = _makeNode(
        id: '1',
        name: 'alice-lan',
        user: 'alice',
        sharedRoutes: ['192.168.1.0/24', '0.0.0.0/0'],
      );
      final duplicates = RouteConflictService.findCrossUserDuplicateCidrs(
        [aliceApproved, bobApproved],
      );
      expect(duplicates.keys, ['192.168.1.0/24']);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/models/acl_engine_mode.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/taildrive_share.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/models/version_info.dart';
import 'package:headscalemanager/services/acl/alignment_diagnostic_service.dart';
import 'package:headscalemanager/services/acl/hujson_comment_service.dart';

Node _makeNode({
  required String id,
  required String name,
  required String user,
  required String userId,
  List<String> tags = const [],
}) {
  return Node(
    id: id,
    machineKey: 'mk-$id',
    hostname: name,
    name: name,
    user: user,
    userId: userId,
    ipAddresses: ['100.64.0.$id'],
    online: true,
    lastSeen: DateTime(2026, 11, 17),
    sharedRoutes: const [],
    availableRoutes: const [],
    isExitNode: false,
    isLanSharer: false,
    tags: tags,
    baseDomain: 'example.ts.net',
    endpoint: '',
  );
}

void main() {
  group('VersionInfo gouvernance N-2', () {
    test('signale <= 0.27 comme obsolète et >= 0.28 comme supporté', () {
      expect(VersionInfo.isServerDeprecated('0.25.1'), isTrue);
      expect(VersionInfo.isServerDeprecated('v0.26.0'), isTrue);
      expect(VersionInfo.isServerDeprecated('0.27.9'), isTrue);
      expect(VersionInfo.isServerDeprecated('0.28.0'), isFalse);
      expect(VersionInfo.isServerDeprecated('v0.29.1'), isFalse);
      expect(VersionInfo.isServerDeprecated('unknown'), isFalse);
      expect(VersionInfo.isServerDeprecated(null), isFalse);

      expect(VersionInfo.isPreV26('0.25.0'), isTrue);
      expect(VersionInfo.isPreV26('0.26.0'), isFalse);
    });
  });

  group('AlignmentDiagnosticService', () {
    test('retourne isClean=true sur une configuration saine', () {
      final users = [
        User(id: '1', name: 'alice', createdAt: DateTime(2026, 1, 1)),
      ];
      final nodes = [
        _makeNode(
          id: '10',
          name: 'alice-laptop',
          user: 'alice',
          userId: '1',
          tags: const ['tag:alice-client'],
        ),
      ];
      final policy = {
        'groups': {
          'group:alice': ['alice@'],
        },
        'tagOwners': {
          'tag:alice-client': ['group:alice'],
        },
        'grants': [
          {
            'src': ['tag:alice-client'],
            'dst': ['tag:alice-client'],
            'ip': ['*'],
          }
        ],
      };

      final report = AlignmentDiagnosticService.inspect(
        users: users,
        nodes: nodes,
        serverPolicy: policy,
        serverVersion: '0.29.1',
      );

      expect(report.isClean, isTrue);
      expect(report.hasPolicyFix, isFalse);
      expect(report.hasNodeFixes, isFalse);
    });

    test('détecte et unifie un double profil Local + Mobile OIDC', () {
      final users = [
        User(id: '1', name: 'jean@synology.me', createdAt: DateTime(2026, 1, 1)),
        User(
          id: '2',
          name: 'jean',
          email: 'jean.dupont@gmail.com',
          createdAt: DateTime(2026, 5, 1),
        ),
      ];
      final nodes = [
        _makeNode(
          id: '1',
          name: 'nas-jean',
          user: 'tagged-devices',
          userId: '1',
          tags: const ['tag:jean-client'],
        ),
        _makeNode(
          id: '2',
          name: 'pixel-jean',
          user: 'jean.dupont@gmail.com',
          userId: '2',
          tags: const [],
        ),
      ];
      final policy = {
        'groups': {
          'group:jean': ['jean@synology.me'],
        },
        'tagOwners': {
          'tag:jean-client': ['group:jean'],
        },
        'grants': [
          {
            'src': ['tag:jean-client'],
            'dst': ['tag:jean-client'],
            'ip': ['*'],
          }
        ],
      };

      final report = AlignmentDiagnosticService.inspect(
        users: users,
        nodes: nodes,
        serverPolicy: policy,
        serverVersion: '0.29.0',
      );

      expect(report.isClean, isFalse);
      expect(
        report.issues.any(
          (i) => i.type == AlignmentIssueType.doubleProfileLocalOidc,
        ),
        isTrue,
      );
      expect(report.hasPolicyFix, isTrue);

      final fixedGroups = report.alignedPolicy!['groups'] as Map;
      final groupMembers = List<String>.from(fixedGroups['group:jean'] as List);
      expect(groupMembers, contains('jean@synology.me'));
      expect(groupMembers, contains('jean.dupont@gmail.com'));
      expect(groupMembers, contains('jean@'));
    });

    test('corrige les groupes mal formés et les vieux exitNodes pré-0.26', () {
      final users = [
        User(id: '1', name: 'bob', createdAt: DateTime(2026, 1, 1)),
      ];
      final nodes = [
        _makeNode(
          id: '1',
          name: 'Bob_PC',
          user: 'bob',
          userId: '1',
          tags: const ['tag:bob.old-client;exit-node'],
        ),
      ];
      final policy = {
        'groups': {
          'group:bob': ['bob', 'bob@headscale.local'],
        },
        'tagOwners': {
          'tag:bob.old-client;exit-node': ['bob'],
        },
        'autoApprovers': {
          'exitNodes': ['tag:bob-exit-node'],
          'routes': <String, dynamic>{},
        },
      };

      final report = AlignmentDiagnosticService.inspect(
        users: users,
        nodes: nodes,
        serverPolicy: policy,
        serverVersion: '0.29.0',
      );

      final types = report.issues.map((i) => i.type).toSet();
      expect(types, contains(AlignmentIssueType.malformedGroupMembers));
      expect(types, contains(AlignmentIssueType.invalidOrMissingTagOwners));
      expect(types, contains(AlignmentIssueType.legacyAutoApproversExitNodes));
      expect(types, contains(AlignmentIssueType.legacyOrDottedTags));
      expect(types, contains(AlignmentIssueType.invalidDnsNodeNames));

      expect(report.hasPolicyFix, isTrue);
      expect(report.hasNodeFixes, isTrue);

      final aligned = report.alignedPolicy!;
      expect(aligned['groups']['group:bob'], equals(['bob@']));
      expect(aligned['tagOwners']['tag:bob.old-client;exit-node'], equals(['group:bob']));
      // Vérifie que les nouveaux tags standardisés sont aussi déclarés dans tagOwners avant setTags
      expect(aligned['tagOwners']['tag:bob-old-client'], contains('group:bob'));
      expect(aligned['tagOwners']['tag:bob-old-exit-node'], contains('group:bob'));
      expect((aligned['autoApprovers'] as Map).containsKey('exitNodes'), isFalse);
      expect(aligned['autoApprovers']['routes']['0.0.0.0/0'], contains('tag:bob-exit-node'));
      expect(aligned['autoApprovers']['routes']['::/0'], contains('tag:bob-exit-node'));

      final tagAction =
          report.allNodeActions.firstWhere((a) => a.newTags != null);
      expect(
        tagAction.newTags,
        equals(['tag:bob-old-client', 'tag:bob-old-exit-node']),
      );

      final renameAction =
          report.allNodeActions.firstWhere((a) => a.newNodeName != null);
      expect(renameAction.newNodeName, equals('bob-pc'));
    });

    test('répercute en cascade groupes (. → -), @ et tags dans grants, acls, ssh, tests, Taildrive et règles locales', () {
      final users = [
        User(
          id: '1',
          name: 'clarisse.leclerc@gmail.com',
          email: 'clarisse.leclerc@gmail.com',
          createdAt: DateTime(2026, 1, 1),
        ),
        User(id: '2', name: 'bob', createdAt: DateTime(2026, 1, 1)),
      ];
      final nodes = [
        _makeNode(
          id: '1',
          name: 'adguard-nas',
          user: 'clarisse.leclerc@gmail.com',
          userId: '1',
          tags: const ['tag:clarisse.leclerc-client'],
        ),
        _makeNode(
          id: '2',
          name: 'phone-bob',
          user: 'bob',
          userId: '2',
          tags: const ['tag:bob-client;exit-node'],
        ),
      ];

      final adguardGrant = {
        'src': ['bob'],
        'dst': ['tag:clarisse.leclerc-client', 'group:clarisse.leclerc'],
        'ip': ['udp:53', 'tcp:53'],
      };
      final oldSig = HuJsonCommentService.ruleSignature(adguardGrant, isGrant: true);

      final policy = {
        'groups': {
          'group:clarisse.leclerc': ['clarisse.leclerc@gmail.com'],
          'group:bob': ['bob'],
        },
        'tagOwners': {
          'tag:clarisse.leclerc-client': ['group:clarisse.leclerc'],
          'tag:bob-client;exit-node': ['group:bob'],
        },
        'autoApprovers': {
          'routes': {
            '0.0.0.0/0': ['tag:bob-client;exit-node'],
          },
        },
        'grants': [
          adguardGrant,
          {
            'src': ['group:clarisse.leclerc'],
            'dst': ['autogroup:internet'],
            'via': ['tag:bob-client;exit-node'],
            'ip': ['*'],
          },
          {
            'src': ['group:inexistant'],
            'dst': ['tag:fantome-client'],
            'ip': ['*'],
          },
        ],
        'acls': [
          {
            'action': 'accept',
            'src': ['group:clarisse.leclerc', 'bob'],
            'dst': ['tag:clarisse.leclerc-client:53,80'],
          },
        ],
        'ssh': [
          {
            'action': 'accept',
            'src': ['group:clarisse.leclerc'],
            'dst': ['tag:clarisse.leclerc-client'],
            'users': ['root'],
          },
        ],
        'nodeAttrs': [
          {
            'target': ['tag:clarisse.leclerc-client'],
            'attr': ['drive:share'],
          },
        ],
        'tests': [
          {
            'src': 'bob',
            'accept': ['tag:clarisse.leclerc-client:53'],
          },
        ],
      };

      final tempRules = [
        {
          'src': 'group:clarisse.leclerc',
          'dst': 'tag:clarisse.leclerc-client',
          'port': '53',
          'proto': 'udp',
        },
      ];
      final taildriveShares = [
        TaildriveShare(
          id: 'td-1',
          sourceNodeId: '1',
          shareName: 'photos',
          localPath: '/data/photos',
          recipient: 'group:clarisse.leclerc',
          accessMode: TaildriveAccessMode.ro,
        ),
      ];

      final report = AlignmentDiagnosticService.inspect(
        users: users,
        nodes: nodes,
        serverPolicy: policy,
        serverVersion: '0.29.2',
        temporaryRules: tempRules,
        taildriveShares: taildriveShares,
      );

      expect(report.hasPolicyFix, isTrue);
      expect(report.hasLocalConfigFixes, isTrue);
      final types = report.issues.map((i) => i.type).toSet();
      expect(types, contains(AlignmentIssueType.cascadeRuleReferencesUpdated));
      expect(types, contains(AlignmentIssueType.brokenRuleReferences));

      final aligned = report.alignedPolicy!;
      expect((aligned['groups'] as Map).containsKey('group:clarisse-leclerc'), isTrue);
      expect((aligned['groups'] as Map).containsKey('group:clarisse.leclerc'), isFalse);

      // grants[0] (AdGuard DNS) réécrit avec conservation de la migration de commentaire
      final g0 = (aligned['grants'] as List)[0] as Map;
      expect(g0['src'], equals(['bob@']));
      expect(g0['dst'], equals(['tag:clarisse-leclerc-client', 'group:clarisse-leclerc']));
      final newSig = HuJsonCommentService.ruleSignature(
        Map<String, dynamic>.from(g0),
        isGrant: true,
      );
      expect(report.migratedRuleCommentKeys[oldSig], equals(newSig));

      // grants[1] (via exit-node)
      final g1 = (aligned['grants'] as List)[1] as Map;
      expect(g1['src'], equals(['group:clarisse-leclerc']));
      expect(g1['via'], equals(['tag:bob-exit-node']));

      // acls[0] avec conservation du suffixe de ports :53,80
      final a0 = (aligned['acls'] as List)[0] as Map;
      expect(a0['src'], equals(['group:clarisse-leclerc', 'bob@']));
      expect(a0['dst'], equals(['tag:clarisse-leclerc-client:53,80']));

      // ssh, nodeAttrs, autoApprovers et tests
      expect((aligned['ssh'] as List)[0]['src'], equals(['group:clarisse-leclerc']));
      expect((aligned['ssh'] as List)[0]['dst'], equals(['tag:clarisse-leclerc-client']));
      expect((aligned['nodeAttrs'] as List)[0]['target'], equals(['tag:clarisse-leclerc-client']));
      expect(aligned['autoApprovers']['routes']['0.0.0.0/0'], equals(['tag:bob-exit-node']));
      expect((aligned['tests'] as List)[0]['src'], equals('bob@'));
      expect((aligned['tests'] as List)[0]['accept'], equals(['tag:clarisse-leclerc-client:53']));

      // Règles locales & Taildrive
      expect(report.alignedTemporaryRules!.first['src'], equals('group:clarisse-leclerc'));
      expect(report.alignedTemporaryRules!.first['dst'], equals('tag:clarisse-leclerc-client'));
      expect(report.alignedTaildriveShares!.first.recipient, equals('group:clarisse-leclerc'));
    });

    test('respecte le mode Legacy (ne split pas les tags ;) et les versions serveur (< 0.26, < 0.29, no-tag)', () {
      final users = [
        User(id: '1', name: 'bob', createdAt: DateTime(2026, 1, 1)),
      ];
      final nodesLegacy = [
        _makeNode(
          id: '1',
          name: 'bob-router',
          user: 'bob',
          userId: '1',
          tags: const ['tag:bob-client;exit-node'],
        ),
      ];
      final policyLegacy = {
        'groups': {
          'group:bob': ['bob@'],
        },
        'tagOwners': {
          'tag:bob-client;exit-node': ['group:bob'],
        },
        'acls': [
          {
            'action': 'accept',
            'src': ['tag:bob-client;exit-node'],
            'dst': ['autogroup:internet:*'],
          },
        ],
      };

      // 1. En mode Legacy sur 0.28, ne doit PAS demander à découper ;exit-node
      final legacyReport = AlignmentDiagnosticService.inspect(
        users: users,
        nodes: nodesLegacy,
        serverPolicy: policyLegacy,
        serverVersion: '0.28.0',
        engineMode: AclEngineMode.legacy,
      );
      expect(legacyReport.hasNodeFixes, isFalse);
      expect(legacyReport.hasPolicyFix, isFalse);

      // 2. Serveur < 0.29 avec bloc grants -> signale l'incompatibilité
      final grantsOn28 = AlignmentDiagnosticService.inspect(
        users: users,
        nodes: [
          _makeNode(id: '2', name: 'bob-phone', user: 'bob', userId: '1'),
        ],
        serverPolicy: {
          'groups': {'group:bob': ['bob@']},
          'grants': [
            {'src': ['group:bob'], 'dst': ['group:bob'], 'ip': ['*']},
          ],
        },
        serverVersion: '0.28.0',
        engineMode: AclEngineMode.standard,
      );
      expect(
        grantsOn28.issues.any(
          (i) => i.type == AlignmentIssueType.incompatibleEngineOrVersion,
        ),
        isTrue,
      );

      // 3. Flotte 100% sans tag sur 0.29 -> aucune erreur ni exigence de tag
      final noTagClean = AlignmentDiagnosticService.inspect(
        users: users,
        nodes: [
          _makeNode(id: '3', name: 'bob-phone', user: 'bob', userId: '1'),
        ],
        serverPolicy: {
          'groups': {'group:bob': ['bob@']},
          'grants': [
            {'src': ['group:bob'], 'dst': ['group:bob'], 'ip': ['*']},
          ],
        },
        serverVersion: '0.29.2',
        engineMode: AclEngineMode.grantsV29,
      );
      expect(noTagClean.isClean, isTrue);

      // 4. Serveur pré-0.26 : ne supprime pas autoApprovers.exitNodes automatiquement
      final pre26Report = AlignmentDiagnosticService.inspect(
        users: users,
        nodes: [
          _makeNode(id: '4', name: 'bob-pc', user: 'bob', userId: '1'),
        ],
        serverPolicy: {
          'groups': {'group:bob': ['bob']},
          'autoApprovers': {
            'exitNodes': ['tag:bob-exit-node'],
          },
        },
        serverVersion: '0.25.1',
        engineMode: AclEngineMode.standard,
      );
      expect(pre26Report.hasPolicyFix, isFalse);
    });
  });
}

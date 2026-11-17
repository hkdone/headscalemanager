import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/services/acl/policy_preserver.dart';

void main() {
  group('PolicyPreserver.merge', () {
    test('préserve ssh, tests, ipsets, derpMap, randomizeClientPort et clés futures', () {
      final generated = {
        'groups': {'group:jean': ['jean@']},
        'tagOwners': {'tag:jean-client': ['group:jean']},
        'acls': [
          {'action': 'accept', 'src': ['tag:jean-client'], 'dst': ['*:*']}
        ],
      };

      final server = {
        'groups': {'group:old': ['old@']},
        'acls': [],
        'ssh': [
          {
            'action': 'accept',
            'src': ['group:jean'],
            'dst': ['tag:jean-client'],
            'users': ['root']
          }
        ],
        'tests': [
          {
            'src': 'tag:jean-client',
            'accept': ['100.64.0.1:22']
          }
        ],
        'ipsets': {'ipset:office': ['192.168.10.0/24']},
        'derpMap': {'OmitDefaultRegions': false},
        'randomizeClientPort': true,
        'futureSection': {'enabled': true},
      };

      final merged = PolicyPreserver.merge(generated, server);

      // Clés gérées viennent du générateur
      expect(merged['groups'], generated['groups']);
      expect(merged['acls'], generated['acls']);

      // Clés non gérées sont préservées du serveur
      expect(merged['ssh'], server['ssh']);
      expect(merged['tests'], server['tests']);
      expect(merged['ipsets'], server['ipsets']);
      expect(merged['derpMap'], server['derpMap']);
      expect(merged['randomizeClientPort'], true);
      expect(merged['futureSection'], {'enabled': true});
    });

    test('fusionne hosts sans écraser les entrées manuelles du serveur', () {
      final generated = {
        'hosts': {'nas-auto': '100.64.0.5', 'custom': '100.64.0.99'},
        'acls': [],
      };
      final server = {
        'hosts': {'custom': '100.64.0.10', 'manual-only': '192.168.1.50'},
      };

      final merged = PolicyPreserver.merge(generated, server);
      final hosts = merged['hosts'] as Map<String, dynamic>;
      expect(hosts['nas-auto'], '100.64.0.5');
      expect(hosts['manual-only'], '192.168.1.50');
      expect(hosts['custom'], '100.64.0.10');
    });

    test('fusionne nodeAttrs : conserve non-Taildrive et remplace Taildrive', () {
      final generated = {
        'nodeAttrs': [
          {
            'target': ['tag:jean-client'],
            'attr': ['drive:share']
          }
        ],
        'acls': [],
      };
      final server = {
        'nodeAttrs': [
          {
            'target': ['tag:old-taildrive'],
            'attr': ['drive:access']
          },
          {
            'target': ['*'],
            'attr': ['funnel']
          }
        ],
      };

      final merged = PolicyPreserver.merge(generated, server);
      final nodeAttrs = merged['nodeAttrs'] as List<dynamic>;
      expect(nodeAttrs.length, 2);
      expect(nodeAttrs.any((e) => (e['attr'] as List).contains('funnel')), isTrue);
      expect(
        nodeAttrs.any((e) =>
            (e['target'] as List).contains('tag:old-taildrive')),
        isFalse,
      );
      expect(
        nodeAttrs.any((e) =>
            (e['target'] as List).contains('tag:jean-client') &&
            (e['attr'] as List).contains('drive:share')),
        isTrue,
      );
    });

    test('supprime les grants serveur obsolètes si absent de generatedPolicy', () {
      final generated = {'acls': []};
      final server = {
        'grants': [
          {'src': ['*'], 'dst': ['*'], 'ip': ['*']}
        ]
      };

      final merged = PolicyPreserver.merge(generated, server);
      expect(merged.containsKey('grants'), isFalse);
    });

    test(
        'preserveCustomRules conserve les grants/acls OIDC inter-utilisateurs mais filtre tags orphelins et règles subsumées',
        () {
      final generated = {
        'groups': {
          'group:oidc1': ['oidc1@example.com'],
          'group:oidc2': ['oidc2@example.com'],
        },
        'tagOwners': {
          'tag:oidc1-client': ['group:oidc1'],
          'tag:oidc1-exit-node': ['group:oidc1'],
          'tag:oidc2-client': ['group:oidc2'],
          'tag:oidc2-exit-node': ['group:oidc2'],
        },
        'acls': [],
        'grants': [
          {
            'src': ['tag:oidc1-client', 'tag:oidc1-exit-node'],
            'dst': ['tag:oidc1-client', 'tag:oidc1-exit-node'],
            'ip': ['*'],
          },
        ],
      };

      final server = {
        'acls': [
          // Règle spécifique IP (AdGuard DNS inter-utilisateurs) -> à conserver
          {
            'action': 'accept',
            'src': ['100.64.0.10'],
            'dst': ['100.64.0.2:53'],
          },
          // Référence un tag orphelin supprimé -> à ne pas conserver
          {
            'action': 'accept',
            'src': ['tag:deleted-client'],
            'dst': ['100.64.0.2:53'],
          },
        ],
        'grants': [
          // Ancienne règle auto-générée subsumée par le nouveau tag exit-node -> ne pas dupliquer
          {
            'src': ['tag:oidc1-client'],
            'dst': ['tag:oidc1-client'],
            'ip': ['*'],
          },
          // Règle personnalisée Exit Node inter-utilisateur OIDC -> à conserver
          {
            'src': ['tag:oidc1-client'],
            'dst': ['autogroup:internet'],
            'via': ['tag:oidc2-exit-node'],
            'ip': ['*'],
          },
          // Ancien partage Taildrive supprimé -> ne pas ressusciter
          {
            'src': ['group:oidc2'],
            'dst': ['tag:oidc1-client'],
            'app': {
              'tailscale.com/cap/taildrive': [
                {'share': 'docs', 'access': 'ro'}
              ]
            },
          },
        ],
      };

      final merged = PolicyPreserver.merge(
        generated,
        server,
        preserveCustomRules: true,
      );

      final grants = merged['grants'] as List<dynamic>;
      expect(grants.length, 2);
      expect(
        grants.any((g) =>
            (g['dst'] as List).contains('autogroup:internet') &&
            (g['via'] as List).contains('tag:oidc2-exit-node')),
        isTrue,
      );
      expect(
        grants.any((g) => g['app'] != null),
        isFalse,
      );

      final acls = merged['acls'] as List<dynamic>;
      expect(acls.length, 1);
      expect((acls.first as Map)['dst'], ['100.64.0.2:53']);
    });

    test('excludedServerAcls empêche une règle temporaire supprimée de revenir',
        () {
      final deletedTempRule = {
        'src': '100.64.0.10',
        'dst': '100.64.0.20',
        'port': '8080',
        'proto': 'tcp',
      };
      final excludedAcls =
          PolicyPreserver.compileTemporaryRulesToAcls([deletedTempRule]);

      final generated = {
        'acls': [],
      };
      final server = {
        'acls': [
          ...excludedAcls,
          {
            'action': 'accept',
            'src': ['100.64.0.10'],
            'dst': ['100.64.0.30:53'],
          },
        ],
      };

      final merged = PolicyPreserver.merge(
        generated,
        server,
        preserveCustomRules: true,
        excludedServerAcls: excludedAcls,
      );

      final acls = merged['acls'] as List<dynamic>;
      expect(acls.length, 1);
      expect((acls.first as Map)['dst'], ['100.64.0.30:53']);
    });
  });
}

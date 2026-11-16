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
  });
}

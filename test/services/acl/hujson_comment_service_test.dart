import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/models/acl_puzzle_model.dart';
import 'package:headscalemanager/services/acl/hujson_comment_service.dart';
import 'package:headscalemanager/services/acl_puzzle_service.dart';

void main() {
  group('HuJsonCommentService', () {
    test('extrait les commentaires de tête et les commentaires juste avant chaque règle', () {
      const hujson = '''
// En-tête global test
{
  "groups": {
    "group:jean": ["jean@example.com"]
  },
  "grants": [
    // Accès NAS Jean
    {
      "src": ["tag:jean-client"],
      "dst": ["tag:nas-jean"],
      "ip": ["*"]
    },
    /* Règle Internet // avec slash */
    {
      "src": ["tag:jean-client"],
      "dst": ["autogroup:internet"],
      "via": ["tag:jean-exit-node"],
      "ip": ["*"]
    }
  ],
  "acls": [
    // Exception SSH HTTP
    {
      "action": "accept",
      "src": ["tag:admin-client"],
      "dst": ["tag:srv-client:*"]
    }
  ]
}
''';

      expect(
        HuJsonCommentService.extractLeadingComments(hujson),
        '// En-tête global test',
      );

      final comments = HuJsonCommentService.extractRuleComments(hujson);
      expect(
        comments['src:tag:jean-client|via:|dst:tag:nas-jean'],
        'Accès NAS Jean',
      );
      expect(
        comments[
            'src:tag:jean-client|via:tag:jean-exit-node|dst:autogroup:internet'],
        'Règle Internet // avec slash',
      );
      expect(
        comments['src:tag:admin-client|via:|dst:tag:srv-client'],
        'Exception SSH HTTP',
      );
    });

    test('formatPolicyWithComments place chaque commentaire juste avant { et reste 100% valide HuJSON', () {
      final policy = {
        'groups': {
          'group:jean': ['jean@example.com'],
        },
        'grants': [
          {
            'src': ['tag:jean-client'],
            'dst': ['tag:nas-jean'],
            'ip': ['*'],
          },
        ],
        'acls': [
          {
            'action': 'accept',
            'src': ['tag:jean-client'],
            'dst': ['tag:srv:*'],
          },
        ],
      };

      final formatted = HuJsonCommentService.formatPolicyWithComments(
        policy,
        leadingComments: '// test',
        ruleComments: {
          'src:tag:jean-client|via:|dst:tag:nas-jean': 'Accès NAS Jean',
          'src:tag:jean-client|via:|dst:tag:srv': 'Exception Serveur',
        },
      );

      expect(formatted.startsWith('// test\n{'), isTrue);
      expect(
        formatted.contains('    // Accès NAS Jean\n    {\n      "src":'),
        isTrue,
      );
      expect(
        formatted.contains('    // Exception Serveur\n    {\n      "action":'),
        isTrue,
      );

      // Aller-retour complet
      final reExtracted = HuJsonCommentService.extractRuleComments(formatted);
      expect(
        reExtracted['src:tag:jean-client|via:|dst:tag:nas-jean'],
        'Accès NAS Jean',
      );
      expect(
        reExtracted['src:tag:jean-client|via:|dst:tag:srv'],
        'Exception Serveur',
      );

      // Produit exactement JsonEncoder.withIndent('  ') si aucun commentaire
      final plain = HuJsonCommentService.formatPolicyWithComments(policy);
      expect(plain, const JsonEncoder.withIndent('  ').convert(policy));
    });

    test('AclPuzzleService hydrate le nommage depuis les commentaires HuJSON', () {
      const raw = '''
      {
        "grants": [
          // Accès Bureau Jean
          {
            "src": ["tag:jean-client"],
            "dst": ["192.168.10.0/24"],
            "via": ["tag:jean-lan-sharer"],
            "ip": ["*"]
          }
        ]
      }
      ''';
      final comments = HuJsonCommentService.extractRuleComments(raw);
      final puzzleService = AclPuzzleService();
      final rules = puzzleService.parseJsonToPuzzle(
        jsonPolicy: {
          'grants': [
            {
              'src': ['tag:jean-client'],
              'dst': ['192.168.10.0/24'],
              'via': ['tag:jean-lan-sharer'],
              'ip': ['*'],
            }
          ]
        },
        availableEntities: const <PuzzleEntity>[],
        ruleComments: comments,
      );

      expect(rules.length, 1);
      expect(rules.first.comment, 'Accès Bureau Jean');
    });
  });
}

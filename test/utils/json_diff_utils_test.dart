import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/utils/json_diff_utils.dart';

void main() {
  group('JsonDiffUtils', () {
    test('detects no changes on identical policies', () {
      final a = {
        'groups': {'group:alice': ['alice']},
        'grants': [
          {
            'src': ['group:alice'],
            'dst': ['*'],
            'ip': ['*'],
          }
        ],
      };
      final b = {
        'groups': {'group:alice': ['alice']},
        'grants': [
          {
            'src': ['group:alice'],
            'dst': ['*'],
            'ip': ['*'],
          }
        ],
      };

      final result = JsonDiffUtils.diffPolicies(
        currentPolicy: a,
        newPolicy: b,
      );

      expect(result.hasChanges, isFalse);
      expect(result.addedCount, 0);
      expect(result.removedCount, 0);
      expect(result.usedSectionFallback, isFalse);
    });

    test('computes line-by-line additions and removals', () {
      final before = {
        'acls': [
          {
            'action': 'accept',
            'src': ['group:alice'],
            'dst': ['100.64.0.2:80'],
          }
        ],
      };
      final after = {
        'acls': [
          {
            'action': 'accept',
            'src': ['group:alice'],
            'dst': ['100.64.0.2:443'],
          }
        ],
      };

      final result = JsonDiffUtils.diffPolicies(
        currentPolicy: before,
        newPolicy: after,
      );

      expect(result.hasChanges, isTrue);
      expect(result.addedCount, 1);
      expect(result.removedCount, 1);
      expect(
        result.lines.any((l) =>
            l.type == DiffLineType.removed && l.content.contains('100.64.0.2:80')),
        isTrue,
      );
      expect(
        result.lines.any((l) =>
            l.type == DiffLineType.added && l.content.contains('100.64.0.2:443')),
        isTrue,
      );
    });

    test('detects HuJSON comment-only additions', () {
      final policy = {
        'grants': [
          {
            'src': ['tag:alice-client'],
            'dst': ['*'],
            'ip': ['*'],
          }
        ],
      };
      const rawBefore = '''{
  "grants": [
    {
      "src": ["tag:alice-client"],
      "dst": ["*"],
      "ip": ["*"]
    }
  ]
}''';
      const rawAfter = '''{
  "grants": [
    //test
    {
      "src": ["tag:alice-client"],
      "dst": ["*"],
      "ip": ["*"]
    }
  ]
}''';

      final result = JsonDiffUtils.diffPolicies(
        currentPolicy: policy,
        newPolicy: policy,
        rawCurrentText: rawBefore,
        rawNewText: rawAfter,
      );

      expect(result.hasChanges, isTrue);
      expect(result.addedCount, 1);
      expect(result.removedCount, 0);
      expect(
        result.lines.any(
            (l) => l.type == DiffLineType.added && l.content.contains('//test')),
        isTrue,
      );
    });

    test('falls back to section summary beyond 1500 lines', () {
      final largeGrantsBefore = List.generate(
        260,
        (i) => {
          'src': ['group:u$i'],
          'dst': ['100.64.0.1'],
          'ip': ['tcp:$i'],
        },
      );
      final largeGrantsAfter = List<Map<String, dynamic>>.from(largeGrantsBefore)
        ..add({
          'src': ['group:extra'],
          'dst': ['100.64.0.2'],
          'ip': ['443'],
        });

      final result = JsonDiffUtils.diffPolicies(
        currentPolicy: {
          'groups': {'group:u0': ['u0']},
          'grants': largeGrantsBefore,
          'ssh': const [],
        },
        newPolicy: {
          'groups': {'group:u0': ['u0']},
          'grants': largeGrantsAfter,
          'ssh': const [],
        },
      );

      expect(result.usedSectionFallback, isTrue);
      expect(result.hasChanges, isTrue);
      final grantsSummary =
          result.sectionSummaries.firstWhere((s) => s.section == 'grants');
      expect(grantsSummary.changed, isTrue);
      expect(grantsSummary.beforeCount, 260);
      expect(grantsSummary.afterCount, 261);

      final groupsSummary =
          result.sectionSummaries.firstWhere((s) => s.section == 'groups');
      expect(groupsSummary.changed, isFalse);
    });
  });
}

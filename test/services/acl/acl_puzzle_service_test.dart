import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/models/acl_puzzle_model.dart';
import 'package:headscalemanager/services/acl_puzzle_service.dart';

void main() {
  group('AclPuzzleService grants', () {
    final service = AclPuzzleService();
    final entities = [
      PuzzleEntity(
        id: 't1',
        type: PuzzleEntityType.tag,
        value: 'tag:jean-client',
        displayLabel: 'Tag: jean-client',
      ),
      PuzzleEntity(
        id: 't2',
        type: PuzzleEntityType.tag,
        value: 'tag:jean-lan-sharer',
        displayLabel: 'Tag: jean-lan-sharer',
      ),
      PuzzleEntity(
        id: 'c1',
        type: PuzzleEntityType.cidr,
        value: '192.168.1.0/24',
        displayLabel: 'Subnet',
      ),
    ];

    test('parse and convert grant with via round-trip', () {
      final policy = {
        'groups': {},
        'grants': [
          {
            'src': ['tag:jean-client'],
            'dst': ['192.168.1.0/24'],
            'via': ['tag:jean-lan-sharer'],
            'ip': ['*'],
          },
        ],
      };

      final rules = service.parseJsonToPuzzle(
        jsonPolicy: policy,
        availableEntities: entities,
      );
      expect(rules, hasLength(1));
      expect(rules.first.via, hasLength(1));
      expect(rules.first.via.first.value, 'tag:jean-lan-sharer');

      final output = service.convertPuzzleToJson(
        rules: rules,
        basePolicy: {'groups': {}, 'tagOwners': {}},
        emitGrants: true,
      );

      final grants = output['grants'] as List;
      expect(grants, hasLength(1));
      expect(grants.first['via'], ['tag:jean-lan-sharer']);
    });
  });
}

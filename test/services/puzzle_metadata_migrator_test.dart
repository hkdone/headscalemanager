import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/models/acl_puzzle_model.dart';
import 'package:headscalemanager/services/puzzle_metadata_migrator.dart';

PuzzleEntity _tag(String value) => PuzzleEntity(
      id: value,
      type: PuzzleEntityType.tag,
      value: value,
      displayLabel: value,
    );

PuzzleEntity _cidr(String value) => PuzzleEntity(
      id: value,
      type: PuzzleEntityType.cidr,
      value: value,
      displayLabel: value,
    );

void main() {
  group('PuzzleMetadataMigrator', () {
    test('migrateEntityKey split lan-sharer tag', () {
      expect(
        PuzzleMetadataMigrator.migrateEntityKey('tag:jean-client;lan-sharer'),
        'tag:jean-lan-sharer',
      );
    });

    test('remappedBlockMeta matches same src/dst with different via', () {
      const oldSig = 'src:tag:jean-client|via:|dst:192.168.1.0/24';

      final rule = PuzzleRule(
        sources: [
          _tag('tag:jean-client'),
          _tag('tag:jean-exit-node'),
          _tag('tag:jean-lan-sharer'),
        ],
        via: [_tag('tag:jean-lan-sharer')],
        destinations: [_cidr('192.168.1.0/24')],
        isGrant: true,
      );

      final stored = {
        oldSig: {'name': 'Mon LAN', 'iconKey': 'lan'},
      };

      final result = PuzzleMetadataMigrator.remappedBlockMeta(
        stored: stored,
        currentRules: [rule],
      );

      expect(result[rule.signature]?['name'], 'Mon LAN');
    });
  });
}

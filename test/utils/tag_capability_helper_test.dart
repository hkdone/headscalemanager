import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/models/acl_engine_mode.dart';
import 'package:headscalemanager/utils/tag_capability_helper.dart';

void main() {
  group('TagCapabilityHelper', () {
    test('buildInitialTags respecte le mode legacy vs standard/grantsV29', () {
      expect(
        TagCapabilityHelper.buildInitialTags(
          engineMode: AclEngineMode.legacy,
          normalizedUser: 'alice',
          isExitNode: true,
          isLanSharer: true,
        ),
        ['tag:alice-client;exit-node;lan-sharer'],
      );

      expect(
        TagCapabilityHelper.buildInitialTags(
          engineMode: AclEngineMode.standard,
          normalizedUser: 'alice',
          isExitNode: true,
          isLanSharer: true,
        ),
        [
          'tag:alice-client',
          'tag:alice-exit-node',
          'tag:alice-lan-sharer',
        ],
      );
    });

    test('addCapabilities ajoute des tags séparés en standard/grantsV29', () {
      final res = TagCapabilityHelper.addCapabilities(
        ['tag:alice-client'],
        engineMode: AclEngineMode.grantsV29,
        normalizedUser: 'alice',
        addExitNode: true,
      );
      expect(res, ['tag:alice-client', 'tag:alice-exit-node']);
    });

    test('removeCapabilities supprime tag:<user>-lan-sharer ET ;lan-sharer', () {
      expect(
        TagCapabilityHelper.removeCapabilities(
          ['tag:alice-client', 'tag:alice-exit-node', 'tag:alice-lan-sharer'],
          removeLanSharer: true,
        ),
        ['tag:alice-client', 'tag:alice-exit-node'],
      );

      expect(
        TagCapabilityHelper.removeCapabilities(
          ['tag:alice-client;exit-node;lan-sharer'],
          removeLanSharer: true,
        ),
        ['tag:alice-client;exit-node'],
      );
    });

    test('reassignOwnerTags réattribue -client, -exit-node et -lan-sharer', () {
      final movedStandard = TagCapabilityHelper.reassignOwnerTags(
        ['tag:alice-client', 'tag:alice-exit-node', 'tag:custom-monitoring'],
        newNormalizedUser: 'bob',
        engineMode: AclEngineMode.standard,
      );
      expect(
        movedStandard,
        ['tag:custom-monitoring', 'tag:bob-client', 'tag:bob-exit-node'],
      );

      final movedLegacy = TagCapabilityHelper.reassignOwnerTags(
        ['tag:alice-client;lan-sharer'],
        newNormalizedUser: 'bob',
        engineMode: AclEngineMode.legacy,
      );
      expect(movedLegacy, ['tag:bob-client;lan-sharer']);
    });
  });
}

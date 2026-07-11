import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/taildrive_share.dart';
import 'package:headscalemanager/models/version_info.dart';
import 'package:headscalemanager/utils/string_utils.dart';

/// Construit les blocs `nodeAttrs` et `grants` Taildrive pour Headscale >= 0.29.0.
class TaildriveBuilder {
  static const taildriveMinVersion = '0.29.0';

  /// Retourne null si version incompatible ou aucun partage configuré.
  static Map<String, dynamic>? build({
    required List<TaildriveShare> shares,
    required List<Node> nodes,
    String? serverVersion,
  }) {
    if (serverVersion == null ||
        !VersionInfo.checkVersionAtLeast(serverVersion, taildriveMinVersion)) {
      return null;
    }

    if (shares.isEmpty) return null;

    final nodeAttrs = <Map<String, dynamic>>[];
    final grants = <Map<String, dynamic>>[];

    final sourceNodeIds = shares.map((s) => s.sourceNodeId).toSet();
    for (var nodeId in sourceNodeIds) {
      final matchingNodes = nodes.where((n) => n.id == nodeId);
      final node = matchingNodes.isNotEmpty ? matchingNodes.first : null;
      if (node != null) {
        final targets = node.tags.isNotEmpty
            ? node.tags
            : ['group:${node.getNormalizedOwner()}'];
        nodeAttrs.add({
          'target': targets,
          'attr': ['drive:share'],
        });
      }
    }

    final recipientGroups = shares
        .map((s) => s.recipient.startsWith('group:')
            ? s.recipient
            : 'group:${normalizeUserName(s.recipient)}')
        .toSet();

    for (var group in recipientGroups) {
      nodeAttrs.add({
        'target': [group],
        'attr': ['drive:access'],
      });
    }

    for (var share in shares) {
      final matchingNodes = nodes.where((n) => n.id == share.sourceNodeId);
      final sourceNode = matchingNodes.isNotEmpty ? matchingNodes.first : null;
      if (sourceNode == null) continue;

      final dstTargets = sourceNode.tags.isNotEmpty
          ? sourceNode.tags
          : ['group:${sourceNode.getNormalizedOwner()}'];

      final src = share.recipient.startsWith('group:')
          ? share.recipient
          : 'group:${normalizeUserName(share.recipient)}';

      grants.add({
        'src': [src],
        'dst': dstTargets,
        'app': {
          'tailscale.com/cap/drive': [
            {
              'shares': [share.shareName],
              'access':
                  share.accessMode == TaildriveAccessMode.rw ? 'rw' : 'ro',
            }
          ]
        }
      });
    }

    return {'nodeAttrs': nodeAttrs, 'grants': grants};
  }

  /// Fusionne la configuration Taildrive dans une politique existante.
  static void mergeIntoPolicy(
    Map<String, dynamic> policy, {
    required List<TaildriveShare> shares,
    required List<Node> nodes,
    String? serverVersion,
  }) {
    final config = build(
      shares: shares,
      nodes: nodes,
      serverVersion: serverVersion,
    );
    if (config == null) return;

    final nodeAttrs =
        config['nodeAttrs'] as List<Map<String, dynamic>>? ?? [];
    final grants = config['grants'] as List<Map<String, dynamic>>? ?? [];

    if (nodeAttrs.isNotEmpty) {
      policy['nodeAttrs'] = nodeAttrs;
    }
    if (grants.isNotEmpty) {
      policy['grants'] = grants;
    }
  }
}

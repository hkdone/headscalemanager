import 'package:headscalemanager/api/headscale_api_service.dart';
import 'package:headscalemanager/models/acl_engine_mode.dart';
import 'package:headscalemanager/models/node.dart';

/// Utilitaire centralisé pour manipuler les tags d'identité et de capacités
/// (`-client`, `exit-node`, `lan-sharer`) selon le moteur ACL actif.
class TagCapabilityHelper {
  /// Construit les tags initiaux d'un nœud ou d'une PreAuthKey selon [engineMode].
  static List<String> buildInitialTags({
    required AclEngineMode engineMode,
    required String normalizedUser,
    bool isExitNode = false,
    bool isLanSharer = false,
  }) {
    if (engineMode == AclEngineMode.legacy) {
      final buffer = StringBuffer('tag:$normalizedUser-client');
      if (isExitNode) buffer.write(';exit-node');
      if (isLanSharer) buffer.write(';lan-sharer');
      return [buffer.toString()];
    }

    return [
      'tag:$normalizedUser-client',
      if (isExitNode) 'tag:$normalizedUser-exit-node',
      if (isLanSharer) 'tag:$normalizedUser-lan-sharer',
    ];
  }

  /// Ajoute les capacités demandées en respectant le format du moteur actif.
  static List<String> addCapabilities(
    List<String> tags, {
    required AclEngineMode engineMode,
    String? normalizedUser,
    bool addExitNode = false,
    bool addLanSharer = false,
  }) {
    final newTags = List<String>.from(tags);
    if (!addExitNode && !addLanSharer) return newTags;

    if (engineMode == AclEngineMode.legacy) {
      final clientTagIndex = newTags.indexWhere((t) => t.contains('-client'));
      if (clientTagIndex != -1) {
        final oldClientTag = newTags[clientTagIndex];
        final parts = oldClientTag
            .replaceFirst('tag:', '')
            .split(';')
            .where((p) => p.isNotEmpty)
            .toSet();

        if (addExitNode) parts.add('exit-node');
        if (addLanSharer) parts.add('lan-sharer');

        final clientPart =
            parts.firstWhere((p) => p.contains('-client'), orElse: () => '');
        if (clientPart.isEmpty) return newTags;

        final otherParts = parts.where((p) => p != clientPart).toList()..sort();
        final builder = StringBuffer('tag:$clientPart');
        if (otherParts.isNotEmpty) {
          builder.write(';${otherParts.join(';')}');
        }
        newTags[clientTagIndex] = builder.toString();

        if (addExitNode) newTags.removeWhere((t) => t == 'tag:exit-node');
        if (addLanSharer) newTags.removeWhere((t) => t == 'tag:lan-sharer');
      } else {
        if (addExitNode && !newTags.contains('tag:exit-node')) {
          newTags.add('tag:exit-node');
        }
        if (addLanSharer && !newTags.contains('tag:lan-sharer')) {
          newTags.add('tag:lan-sharer');
        }
      }
      return newTags;
    }

    // Modes Standard & Grants V29 : tags séparés `tag:<user>-exit-node` / `tag:<user>-lan-sharer`
    final resolvedUser = (normalizedUser != null && normalizedUser.isNotEmpty)
        ? normalizedUser
        : _extractNormalizedUserFromClientTag(newTags);

    if (resolvedUser != null && resolvedUser.isNotEmpty) {
      if (addExitNode) {
        final capTag = 'tag:$resolvedUser-exit-node';
        if (!newTags.contains(capTag)) newTags.add(capTag);
      }
      if (addLanSharer) {
        final capTag = 'tag:$resolvedUser-lan-sharer';
        if (!newTags.contains(capTag)) newTags.add(capTag);
      }
    } else {
      if (addExitNode && !newTags.contains('tag:exit-node')) {
        newTags.add('tag:exit-node');
      }
      if (addLanSharer && !newTags.contains('tag:lan-sharer')) {
        newTags.add('tag:lan-sharer');
      }
    }

    return newTags;
  }

  /// Supprime les capacités demandées quel que soit le format (Legacy `;`,
  /// générique `tag:exit-node` ou séparé `tag:<user>-lan-sharer`).
  static List<String> removeCapabilities(
    List<String> tags, {
    bool removeExitNode = false,
    bool removeLanSharer = false,
  }) {
    final newTags = <String>[];

    for (final tag in tags) {
      if (removeExitNode &&
          (tag == 'tag:exit-node' ||
              (tag.startsWith('tag:') && tag.endsWith('-exit-node')))) {
        continue;
      }
      if (removeLanSharer &&
          (tag == 'tag:lan-sharer' ||
              (tag.startsWith('tag:') && tag.endsWith('-lan-sharer')))) {
        continue;
      }

      if (tag.contains('-client') && tag.contains(';')) {
        final parts = tag
            .replaceFirst('tag:', '')
            .split(';')
            .where((p) => p.isNotEmpty)
            .toSet();

        if (removeExitNode) parts.remove('exit-node');
        if (removeLanSharer) parts.remove('lan-sharer');

        final clientPart =
            parts.firstWhere((p) => p.contains('-client'), orElse: () => '');
        if (clientPart.isEmpty) {
          newTags.add(tag);
          continue;
        }

        final otherParts = parts.where((p) => p != clientPart).toList()..sort();
        final builder = StringBuffer('tag:$clientPart');
        if (otherParts.isNotEmpty) {
          builder.write(';${otherParts.join(';')}');
        }
        newTags.add(builder.toString());
      } else {
        newTags.add(tag);
      }
    }

    return newTags;
  }

  /// Réattribue les tags d'identité et de capacités vers [newNormalizedUser]
  /// lors du déplacement d'un nœud vers un autre utilisateur.
  static List<String> reassignOwnerTags(
    List<String> oldTags, {
    required String newNormalizedUser,
    required AclEngineMode engineMode,
  }) {
    final hadExitNode = oldTags.any(
      (t) =>
          t == 'tag:exit-node' ||
          t.contains(';exit-node') ||
          (t.startsWith('tag:') && t.endsWith('-exit-node')),
    );
    final hadLanSharer = oldTags.any(
      (t) =>
          t == 'tag:lan-sharer' ||
          t.contains(';lan-sharer') ||
          (t.startsWith('tag:') && t.endsWith('-lan-sharer')),
    );

    final preservedCustomTags = oldTags.where((t) {
      if (t.contains('-client')) return false;
      if (t == 'tag:exit-node' ||
          (t.startsWith('tag:') && t.endsWith('-exit-node'))) {
        return false;
      }
      if (t == 'tag:lan-sharer' ||
          (t.startsWith('tag:') && t.endsWith('-lan-sharer'))) {
        return false;
      }
      return true;
    }).toList();

    final rebuilt = buildInitialTags(
      engineMode: engineMode,
      normalizedUser: newNormalizedUser,
      isExitNode: hadExitNode,
      isLanSharer: hadLanSharer,
    );

    return [...preservedCustomTags, ...rebuilt];
  }

  /// Indique si le nœud porte un tag `lan-sharer` obsolète (aucune route partagée).
  static bool hasObsoleteLanSharerTag(Node node) {
    if (node.sharedRoutes.isNotEmpty) return false;
    return node.tags.any(
      (tag) =>
          tag.contains(';lan-sharer') ||
          tag == 'tag:lan-sharer' ||
          (tag.startsWith('tag:') && tag.endsWith('-lan-sharer')),
    );
  }

  /// Nettoie sur le serveur les tags `lan-sharer` des nœuds sans routes partagées.
  static Future<List<Node>> cleanupObsoleteLanSharerTags(
    HeadscaleApiService apiService,
    List<Node> nodes,
  ) async {
    final nodesToCleanup = nodes.where(hasObsoleteLanSharerTag).toList();
    if (nodesToCleanup.isEmpty) return nodes;

    bool anyUpdated = false;
    for (final node in nodesToCleanup) {
      final newTags = removeCapabilities(
        List<String>.from(node.tags),
        removeLanSharer: true,
      );
      if (!_listEquals(node.tags, newTags)) {
        await apiService.setTags(node.id, newTags);
        anyUpdated = true;
      }
    }

    if (!anyUpdated) return nodes;
    return apiService.getNodes();
  }

  static String? _extractNormalizedUserFromClientTag(List<String> tags) {
    final clientTag =
        tags.firstWhere((t) => t.contains('-client'), orElse: () => '');
    if (clientTag.isEmpty) return null;
    final clean = clientTag.replaceFirst('tag:', '').split(';').first;
    final idx = clean.lastIndexOf('-client');
    if (idx <= 0) return null;
    return clean.substring(0, idx);
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

import 'package:headscalemanager/api/headscale_api_service.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/utils/string_utils.dart';

class MigrationResult {
  final int successCount;
  final int failureCount;
  final List<String> errors;

  MigrationResult(this.successCount, this.failureCount, this.errors);
}

class TagMigrationService {
  final HeadscaleApiService apiService;

  TagMigrationService(this.apiService);

  /// Migrates all nodes from "Merged Tags" (Legacy) to "Standard Tags".
  /// e.g. "tag:user;exit-node" -> ["tag:user", "tag:user-exit-node"]
  Future<MigrationResult> migrateToStandard() async {
    int success = 0;
    int fail = 0;
    List<String> errors = [];

    try {
      final nodes = await apiService.getNodes();

      for (final node in nodes) {
        try {
          if (_needsMigration(node)) {
            final newTags = _convertToStandard(node);
            if (!_areTagsEqual(node.tags, newTags)) {
              await apiService.setTags(node.id, newTags);
              success++;
            }
          }
        } catch (e) {
          fail++;
          errors.add('Node ${node.name}: $e');
        }
      }
    } catch (e) {
      errors.add('Global fetch error: $e');
    }

    return MigrationResult(success, fail, errors);
  }

  /// Rolls back all nodes from "Standard Tags" to "Merged Tags" (Legacy).
  /// e.g. ["tag:user", "tag:user-exit-node"] -> "tag:user;exit-node"
  Future<MigrationResult> rollbackToLegacy() async {
    int success = 0;
    int fail = 0;
    List<String> errors = [];

    try {
      final nodes = await apiService.getNodes();

      for (final node in nodes) {
        try {
          if (_needsRollback(node)) {
            final newTags = _convertToLegacy(node);
            if (!_areTagsEqual(node.tags, newTags)) {
              await apiService.setTags(node.id, newTags);
              success++;
            }
          }
        } catch (e) {
          fail++;
          errors.add('Node ${node.name}: $e');
        }
      }
    } catch (e) {
      errors.add('Global fetch error: $e');
    }

    return MigrationResult(success, fail, errors);
  }

  bool _needsMigration(Node node) {
    return node.tags.any((t) => t.contains(';'));
  }

  bool _needsRollback(Node node) {
    // Check if we have standard capability tags like 'tag:*-exit-node' or 'tag:*-lan-sharer'
    return node.tags
        .any((t) => t.endsWith('-exit-node') || t.endsWith('-lan-sharer'));
  }

  List<String> _convertToStandard(Node node) {
    List<String> newTags = [];
    final oldTags = node.tags;
    // Use normalizeUserName to ensure we match ACL generator expectations (lowercase, no domain)
    final userName = normalizeUserName(node.user);

    for (final tag in oldTags) {
      if (tag.contains(';')) {
        final parts = tag.split(';');
        // Standardize: parts[0] is usually basic tag 'tag:foo-client'
        // parts[1..n] are capabilities 'exit-node', 'lan-sharer'

        // Clean leading 'tag:' from parts for easier handling, add it back later
        String baseTag = parts[0].toLowerCase();
        // Logic from EditTagsDialog: consolidated tag is first.

        newTags.add(baseTag);

        for (int i = 1; i < parts.length; i++) {
          final capability = parts[i].toLowerCase();
          if (capability == 'exit-node' || capability == 'lan-sharer') {
            // Create standard capability tag: tag:USER-capability
            newTags.add('tag:$userName-$capability');
          }
        }
      } else {
        newTags.add(tag.toLowerCase());
      }
    }
    return newTags.toSet().toList(); // Remove duplicates
  }

  List<String> _convertToLegacy(Node node) {
    List<String> finalTags = [];

    // Identify capabilities
    bool hasExitNode = node.tags.any((t) => t.endsWith('-exit-node'));
    bool hasLanSharer = node.tags.any((t) => t.endsWith('-lan-sharer'));

    // Identify base tags (everything NOT a capability tag)
    List<String> baseTags = node.tags
        .where((t) => !t.endsWith('-exit-node') && !t.endsWith('-lan-sharer'))
        .toList();

    // If no base tags, we can't merge onto anything, preserving raw tags might be safer?
    // Or we look for 'tag:*-client'.

    // Find primary client tag to merge onto
    int clientTagIndex = baseTags.indexWhere((t) => t.contains('-client'));

    if (clientTagIndex != -1) {
      String primary = baseTags[clientTagIndex];
      StringBuffer merged = StringBuffer(primary);

      if (hasExitNode) merged.write(';exit-node');
      if (hasLanSharer) merged.write(';lan-sharer');

      baseTags[clientTagIndex] = merged.toString();
      finalTags = baseTags;
    } else {
      // No client tag found to merge onto.
      // We synthesize a default client tag based on the user name
      // This handles cases where a node might only have capability tags in the new system
      String primary = 'tag:${normalizeUserName(node.user)}-client';
      StringBuffer merged = StringBuffer(primary);

      if (hasExitNode) merged.write(';exit-node');
      if (hasLanSharer) merged.write(';lan-sharer');

      finalTags.add(merged.toString());
      finalTags.addAll(baseTags);
    }

    return finalTags.toSet().toList();
  }

  bool _areTagsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    return Set.from(a).containsAll(b);
  }
}

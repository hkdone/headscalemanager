import 'package:headscalemanager/models/acl_puzzle_model.dart';

/// Remappe les métadonnées Puzzle après migration Grants V29 ou changement de tags.
class PuzzleMetadataMigrator {
  /// Ancien format fusionné → tags Standard séparés.
  static String? migrateEntityKey(String key) {
    if (!key.startsWith('tag:')) return null;

    final body = key.substring(4);
    if (!body.contains(';')) return null;

    final parts = body.split(';').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return null;

    final clientPart = parts.firstWhere(
      (p) => p.endsWith('-client'),
      orElse: () => parts.first,
    );
    final userPrefix = clientPart.replaceAll('-client', '');

    for (final part in parts) {
      if (part == 'lan-sharer' || part.endsWith('lan-sharer')) {
        return 'tag:$userPrefix-lan-sharer';
      }
      if (part == 'exit-node' || part.endsWith('exit-node')) {
        return 'tag:$userPrefix-exit-node';
      }
    }
    return null;
  }

  static Map<String, String> remappedEntityAliases(
    Map<String, String> aliases,
  ) {
    final result = Map<String, String>.from(aliases);
    for (final entry in aliases.entries) {
      final migrated = migrateEntityKey(entry.key);
      if (migrated != null && !result.containsKey(migrated)) {
        result[migrated] = entry.value;
      }
    }
    return result;
  }

  static Map<String, Map<String, dynamic>> remappedBlockMeta({
    required Map<String, Map<String, dynamic>> stored,
    required List<PuzzleRule> currentRules,
  }) {
    if (stored.isEmpty || currentRules.isEmpty) return stored;

    final result = <String, Map<String, dynamic>>{};
    final orphans = Map<String, Map<String, dynamic>>.from(stored);

    for (final rule in currentRules) {
      final sig = rule.signature;
      if (stored.containsKey(sig)) {
        result[sig] = stored[sig]!;
        orphans.remove(sig);
        continue;
      }

      for (final oldKey in stored.keys) {
        if (_compatibleSignatures(oldKey, sig)) {
          result[sig] = stored[oldKey]!;
          orphans.remove(oldKey);
          break;
        }
      }
    }

    // Conserver les métadonnées orphelines au cas où
    result.addAll(orphans);
    return result;
  }

  static bool _compatibleSignatures(String sigA, String sigB) {
    final a = _parse(sigA);
    final b = _parse(sigB);
    if (a == null || b == null) return false;
    if (!_setEquals(a.dst, b.dst)) return false;
    if (a.src.intersection(b.src).isNotEmpty) return true;
    return a.src.every(b.src.contains) || b.src.every(a.src.contains);
  }

  static _SigParts? _parse(String signature) {
    final parts = signature.split('|');
    if (parts.length != 3) return null;
    if (!parts[0].startsWith('src:') ||
        !parts[1].startsWith('via:') ||
        !parts[2].startsWith('dst:')) {
      return null;
    }
    return _SigParts(
      src: parts[0].substring(4).split(',').where((e) => e.isNotEmpty).toSet(),
      dst: parts[2].substring(4).split(',').where((e) => e.isNotEmpty).toSet(),
    );
  }

  static bool _setEquals(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }
}

class _SigParts {
  final Set<String> src;
  final Set<String> dst;

  const _SigParts({required this.src, required this.dst});
}

import 'dart:convert';
import 'package:headscalemanager/models/acl_puzzle_model.dart';

class AclPuzzleService {
  /// Converts a list of PuzzleRules into a full Headscale ACL Policy JSON
  /// It reuses the base generator for groups/tags definitions but replaces
  /// the 'acls' section with the custom rules.
  Map<String, dynamic> convertPuzzleToJson({
    required List<PuzzleRule> rules,
    required Map<String, dynamic> basePolicy,
  }) {
    // 1. Extract base infrastructure (groups, tagOwners, autoApprovers)
    final groups = basePolicy['groups'] ?? {};
    final tagOwners = basePolicy['tagOwners'] ?? {};
    final autoApprovers = basePolicy['autoApprovers'] ?? {};
    final hosts = basePolicy['hosts'] ?? {};

    // 2. Generate ACLs from Puzzle Rules
    final List<Map<String, dynamic>> generatedAcls = [];

    for (var rule in rules) {
      // 2a. Extract sources
      final List<String> src = rule.sources.map((e) => e.value).toList();

      // 2b. Extract destinations
      // Note: In Headscale ACLs, destinations usually need a port.
      // For simplicity in Puzzle view (Layer 3 focus), we might default to ":*"
      // unless we add port selection to the PuzzleEntity or Rule.
      // Let's assume ":*" for now as the user primarily wants to manage access rights.
      final List<String> dst = rule.destinations.map((e) {
        if (e.value.contains(':')) {
          // If value already has a port (e.g. autogroup:internet:* is common, but usually it's autogroup:internet)
          // actually autogroup:internet needs :* in ACLs.
          // If the entity value is just an IP or tag, we append :*
          // If it's autogroup:internet, we usually treat it as the base.
          return e.value.endsWith(':*') ? e.value : '${e.value}:*';
        } else {
          return '${e.value}:*';
        }
      }).toList();

      generatedAcls.add({
        'action': rule.action,
        'src': src,
        'dst': dst,
      });
    }

    // 3. Assemble Final Policy
    return {
      'groups': groups,
      'tagOwners': tagOwners,
      'hosts': hosts,
      'acls': generatedAcls,
      'autoApprovers': autoApprovers,
    };
  }

  /// Parses a full Headscale ACL Policy JSON into a list of PuzzleRules.
  /// It attempts to map raw strings back to known PuzzleEntities.
  List<PuzzleRule> parseJsonToPuzzle({
    required Map<String, dynamic> jsonPolicy,
    required List<PuzzleEntity> availableEntities,
  }) {
    final List<PuzzleRule> rules = [];
    final acls = jsonPolicy['acls'];

    if (acls is! List) return rules;

    for (var acl in acls) {
      if (acl is! Map<String, dynamic>) continue;

      final action = acl['action']?.toString() ?? 'accept';
      final srcList = acl['src'];
      final dstList = acl['dst'];

      if (srcList is! List || dstList is! List) continue;

      // Map Sources
      final List<PuzzleEntity> sources = [];
      for (var srcItem in srcList) {
        final srcStr = srcItem.toString();
        // Try to find exact match in available entities
        final match = availableEntities.firstWhere(
          (e) => e.value == srcStr,
          orElse: () => PuzzleEntity(
            id: srcStr,
            type: _inferType(srcStr),
            value: srcStr,
            displayLabel: srcStr,
          ),
        );
        sources.add(match);
      }

      // Map Destinations
      final List<PuzzleEntity> destinations = [];
      for (var dstItem in dstList) {
        var dstStr = dstItem.toString();
        // Remove port suffix if present (e.g. ":*") for matching
        // We only support ":*" or exact matches for now in this simple UI
        if (dstStr.endsWith(':*')) {
          dstStr = dstStr.substring(0, dstStr.length - 2);
        }

        final match = availableEntities.firstWhere(
          (e) => e.value == dstStr,
          orElse: () => PuzzleEntity(
            id: dstStr,
            type: _inferType(dstStr),
            value: dstStr,
            displayLabel: dstStr,
          ),
        );
        destinations.add(match);
      }

      rules.add(PuzzleRule(
        sources: sources,
        destinations: destinations,
        action: action,
      ));
    }

    return rules;
  }

  PuzzleEntityType _inferType(String value) {
    if (value.startsWith('group:')) return PuzzleEntityType.group;
    if (value.startsWith('tag:')) return PuzzleEntityType.tag;
    if (value.startsWith('autogroup:internet'))
      return PuzzleEntityType.internet;
    if (value.contains('/'))
      return PuzzleEntityType.cidr; // loose check for CIDR
    // Check if it looks like a host? For now default to host or user?
    // Actually Headscale users are just strings like "myuser".
    // We'll guess User if it has no special chars, but it's ambiguous.
    // Let's default to Host if it's an IP, User otherwise.
    // Simple heuristic:
    if (RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(value))
      return PuzzleEntityType.host;
    return PuzzleEntityType.user;
  }
}

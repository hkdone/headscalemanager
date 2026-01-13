import 'dart:convert';
import 'package:headscalemanager/models/acl_puzzle_model.dart';
import 'package:headscalemanager/services/new_acl_generator_service.dart';

class AclPuzzleService {
  final NewAclGeneratorService _baseGenerator = NewAclGeneratorService();

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
      'autoApprovers': autoApprovers,
      'acls': generatedAcls,
      'hosts': hosts,
    };
  }
}

import 'package:headscalemanager/models/acl_puzzle_model.dart';

class AclPuzzleService {
  Map<String, dynamic> convertPuzzleToJson({
    required List<PuzzleRule> rules,
    required Map<String, dynamic> basePolicy,
    bool emitGrants = false,
  }) {
    if (rules.isEmpty && emitGrants) {
      return basePolicy;
    }

    final groups = basePolicy['groups'] ?? {};
    final tagOwners = basePolicy['tagOwners'] ?? {};
    final autoApprovers = basePolicy['autoApprovers'] ?? {};
    final hosts = basePolicy['hosts'] ?? {};

    final generatedAcls = <Map<String, dynamic>>[];
    final generatedGrants = <Map<String, dynamic>>[];

    for (var rule in rules) {
      final src = rule.sources.map((e) => e.value).toList();
      final dstRaw = rule.destinations.map((e) => e.value).toList();
      final via = rule.via.map((e) => e.value).toList();

      if (emitGrants && (rule.isGrant || via.isNotEmpty)) {
        final grant = <String, dynamic>{
          'src': src,
          'dst': dstRaw,
          'ip': ['*'],
        };
        if (via.isNotEmpty) grant['via'] = via;
        generatedGrants.add(grant);
      } else {
        final dst = dstRaw.map((value) {
          if (value.endsWith(':*')) return value;
          return '$value:*';
        }).toList();
        generatedAcls.add({
          'action': rule.action,
          'src': src,
          'dst': dst,
        });
      }
    }

    final taildriveGrants = <Map<String, dynamic>>[];
    final baseGrants = basePolicy['grants'];
    if (baseGrants is List) {
      for (var g in baseGrants) {
        if (g is Map<String, dynamic> &&
            g['app'] != null &&
            (g['app'] as Map).keys.any((k) =>
                k.toString().contains('cap/drive') ||
                k.toString().contains('cap/taildrive'))) {
          taildriveGrants.add(g);
        }
      }
    }

    final policy = <String, dynamic>{
      'groups': groups,
      'tagOwners': tagOwners,
      'hosts': hosts,
      'autoApprovers': autoApprovers,
    };

    if (emitGrants) {
      policy['grants'] = [...generatedGrants, ...taildriveGrants];
      if (generatedAcls.isNotEmpty) policy['acls'] = generatedAcls;
    } else {
      policy['acls'] = generatedAcls;
      if (taildriveGrants.isNotEmpty) policy['grants'] = taildriveGrants;
    }

    final nodeAttrs = basePolicy['nodeAttrs'];
    if (nodeAttrs != null) policy['nodeAttrs'] = nodeAttrs;

    return policy;
  }

  List<PuzzleRule> parseJsonToPuzzle({
    required Map<String, dynamic> jsonPolicy,
    required List<PuzzleEntity> availableEntities,
  }) {
    final rules = <PuzzleRule>[];
    final seen = <String>{};

    void addRule(PuzzleRule rule) {
      if (seen.add(rule.signature)) rules.add(rule);
    }

    final acls = jsonPolicy['acls'];
    if (acls is List) {
      for (var acl in acls) {
        if (acl is! Map<String, dynamic>) continue;
        final parsed = _parseAclRule(acl, availableEntities);
        if (parsed != null) addRule(parsed);
      }
    }

    final grants = jsonPolicy['grants'];
    if (grants is List) {
      for (var grant in grants) {
        if (grant is! Map<String, dynamic>) continue;
        if (grant['app'] != null) continue;
        if (!grant.containsKey('ip')) continue;
        final parsed = _parseGrantRule(grant, availableEntities);
        if (parsed != null) addRule(parsed);
      }
    }

    return rules;
  }

  PuzzleRule? _parseAclRule(
    Map<String, dynamic> acl,
    List<PuzzleEntity> availableEntities,
  ) {
    final action = acl['action']?.toString() ?? 'accept';
    final srcList = acl['src'];
    final dstList = acl['dst'];
    if (srcList is! List || dstList is! List) return null;

    return PuzzleRule(
      sources: _mapEntities(srcList, availableEntities),
      destinations: _mapDestinations(dstList, availableEntities),
      action: action,
      isGrant: false,
    );
  }

  PuzzleRule? _parseGrantRule(
    Map<String, dynamic> grant,
    List<PuzzleEntity> availableEntities,
  ) {
    final srcList = grant['src'];
    final dstList = grant['dst'];
    if (srcList is! List || dstList is! List) return null;
    final viaList = grant['via'];

    return PuzzleRule(
      sources: _mapEntities(srcList, availableEntities),
      via: viaList is List
          ? _mapEntities(viaList, availableEntities)
          : const [],
      destinations: _mapDestinations(dstList, availableEntities, stripPort: false),
      isGrant: true,
    );
  }

  List<PuzzleEntity> _mapEntities(
      List<dynamic> values, List<PuzzleEntity> availableEntities) {
    return values.map((item) {
      final str = item.toString();
      return availableEntities.firstWhere(
        (e) => e.value == str,
        orElse: () => PuzzleEntity(
          id: str,
          type: _inferType(str),
          value: str,
          displayLabel: _formatLabel(str),
        ),
      );
    }).toList();
  }

  List<PuzzleEntity> _mapDestinations(
    List<dynamic> values,
    List<PuzzleEntity> availableEntities, {
    bool stripPort = true,
  }) {
    return values.map((item) {
      var str = item.toString();
      if (stripPort && str.endsWith(':*')) {
        str = str.substring(0, str.length - 2);
      }
      return availableEntities.firstWhere(
        (e) => e.value == str,
        orElse: () => PuzzleEntity(
          id: str,
          type: _inferType(str),
          value: str,
          displayLabel: _formatLabel(str),
        ),
      );
    }).toList();
  }

  PuzzleEntityType _inferType(String value) {
    if (value.startsWith('group:')) return PuzzleEntityType.group;
    if (value.startsWith('tag:')) return PuzzleEntityType.tag;
    if (value.startsWith('autogroup:internet')) {
      return PuzzleEntityType.internet;
    }
    if (value.contains('/')) return PuzzleEntityType.cidr;
    if (RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(value)) {
      return PuzzleEntityType.host;
    }
    return PuzzleEntityType.user;
  }

  String _formatLabel(String value) {
    if (value.contains(';')) {
      return value.replaceAll('tag:', 'Tag: ');
    }
    if (value.startsWith('tag:')) {
      return value.replaceFirst('tag:', 'Tag: ');
    }
    return value;
  }
}

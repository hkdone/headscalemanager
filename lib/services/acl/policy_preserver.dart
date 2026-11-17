import 'dart:convert';
import 'package:headscalemanager/api/headscale_api_service.dart';
import 'package:headscalemanager/services/acl/hujson_comment_service.dart';
import 'package:headscalemanager/utils/json_utils.dart';

/// Préserve les blocs manuels ou hors périmètre d'une politique ACL serveur
/// lors des régénérations automatiques (`ssh`, `tests`, `ipsets`, `derpMap`,
/// `randomizeClientPort`, `hosts`, `nodeAttrs` non-Taildrive, clés futures).
class PolicyPreserver {
  /// Clés entièrement gérées par le générateur ACL.
  static const Set<String> _managedKeys = {
    'groups',
    'tagOwners',
    'acls',
    'autoApprovers',
    'grants',
  };

  static const Set<String> _taildriveNodeAttrs = {
    'drive:share',
    'drive:access',
    'cap:taildrive',
  };

  /// Fusionne [generatedPolicy] avec les blocs non gérés de [serverPolicy].
  ///
  /// Si [preserveCustomRules] est `true`, préserve également les règles `grants`
  /// et `acls` personnalisées présentes sur [serverPolicy] qui ne sont pas
  /// déjà couvertes par [generatedPolicy] (hors [excludedServerAcls]).
  static Map<String, dynamic> merge(
    Map<String, dynamic> generatedPolicy,
    Map<String, dynamic>? serverPolicy, {
    bool preserveCustomRules = false,
    List<Map<String, dynamic>> excludedServerAcls = const [],
  }) {
    final result = deepCopyMap(generatedPolicy);
    if (serverPolicy == null || serverPolicy.isEmpty) {
      return result;
    }

    for (final entry in serverPolicy.entries) {
      final key = entry.key;
      if (_managedKeys.contains(key)) {
        continue;
      }

      if (key == 'hosts') {
        final mergedHosts = _mergeHosts(
          generatedHosts: result['hosts'],
          serverHosts: entry.value,
        );
        if (mergedHosts != null && mergedHosts.isNotEmpty) {
          result['hosts'] = mergedHosts;
        }
        continue;
      }

      if (key == 'nodeAttrs') {
        final mergedNodeAttrs = _mergeNodeAttrs(
          generatedNodeAttrs: result['nodeAttrs'],
          serverNodeAttrs: entry.value,
        );
        if (mergedNodeAttrs.isNotEmpty) {
          result['nodeAttrs'] = mergedNodeAttrs;
        } else {
          result.remove('nodeAttrs');
        }
        continue;
      }

      // Clés hors périmètre (ssh, tests, ipsets, derpMap, randomizeClientPort, inconnues...)
      // Ne pas écraser si le générateur a déjà explicitement produit cette clé
      if (!result.containsKey(key)) {
        result[key] = _deepCopyValue(entry.value);
      }
    }

    if (preserveCustomRules) {
      final extra = extractExtraCustomRules(
        generatedPolicy: result,
        serverPolicy: serverPolicy,
        excludedServerAcls: excludedServerAcls,
      );
      if (extra.extraGrants.isNotEmpty) {
        final existingGrants = List<dynamic>.from(
          (result['grants'] as List?) ?? const [],
        );
        result['grants'] = [...existingGrants, ...extra.extraGrants];
      }
      if (extra.extraAcls.isNotEmpty) {
        final existingAcls = List<dynamic>.from(
          (result['acls'] as List?) ?? const [],
        );
        result['acls'] = [...existingAcls, ...extra.extraAcls];
      }
    }

    return result;
  }

  /// Extrait les règles `grants` et `acls` personnalisées de [serverPolicy]
  /// qui ne sont ni générées ni subsumées par [generatedPolicy].
  static ({
    List<Map<String, dynamic>> extraGrants,
    List<Map<String, dynamic>> extraAcls,
  }) extractExtraCustomRules({
    required Map<String, dynamic> generatedPolicy,
    required Map<String, dynamic>? serverPolicy,
    List<Map<String, dynamic>> excludedServerAcls = const [],
  }) {
    if (serverPolicy == null || serverPolicy.isEmpty) {
      return (extraGrants: const [], extraAcls: const []);
    }

    final generatedGrants = List<Map<String, dynamic>>.from(
      ((generatedPolicy['grants'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => deepCopyMap(Map<String, dynamic>.from(e))),
    );
    final generatedAcls = List<Map<String, dynamic>>.from(
      ((generatedPolicy['acls'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => deepCopyMap(Map<String, dynamic>.from(e))),
    );

    final genGrantSet = generatedGrants.map(_canonicalJsonEncode).toSet();
    final genAclSet = generatedAcls.map(_canonicalJsonEncode).toSet();
    final excludedAclSet =
        excludedServerAcls.map(_canonicalJsonEncode).toSet();

    final tagOwners = generatedPolicy['tagOwners'] is Map
        ? (generatedPolicy['tagOwners'] as Map)
            .keys
            .map((k) => k.toString())
            .toSet()
        : null;
    final groups = generatedPolicy['groups'] is Map
        ? (generatedPolicy['groups'] as Map)
            .keys
            .map((k) => k.toString())
            .toSet()
        : null;

    final extraGrants = <Map<String, dynamic>>[];
    final serverGrants = serverPolicy['grants'];
    if (serverGrants is List) {
      for (final raw in serverGrants) {
        if (raw is! Map) continue;
        final grant = deepCopyMap(Map<String, dynamic>.from(raw));
        if (_isTaildriveGrant(grant)) continue;
        if (genGrantSet.contains(_canonicalJsonEncode(grant))) continue;
        if (!_hasValidRuleReferences(
          grant,
          declaredTags: tagOwners,
          declaredGroups: groups,
          includeVia: true,
        )) {
          continue;
        }
        if (generatedGrants.any((g) => _isGrantSubsumedBy(grant, g))) {
          continue;
        }
        extraGrants.add(grant);
      }
    }

    final extraAcls = <Map<String, dynamic>>[];
    final serverAcls = serverPolicy['acls'];
    if (serverAcls is List) {
      for (final raw in serverAcls) {
        if (raw is! Map) continue;
        final acl = deepCopyMap(Map<String, dynamic>.from(raw));
        final sig = _canonicalJsonEncode(acl);
        if (genAclSet.contains(sig) || excludedAclSet.contains(sig)) continue;
        if (!_hasValidRuleReferences(
          acl,
          declaredTags: tagOwners,
          declaredGroups: groups,
          includeVia: false,
        )) {
          continue;
        }
        if (generatedAcls.any((a) => _isAclSubsumedBy(acl, a))) {
          continue;
        }
        extraAcls.add(acl);
      }
    }

    return (extraGrants: extraGrants, extraAcls: extraAcls);
  }

  /// Compile une liste de règles temporaires UI vers les entrées `acls`
  /// correspondantes (utile pour exclure une règle fraîchement supprimée).
  static List<Map<String, dynamic>> compileTemporaryRulesToAcls(
    List<Map<String, dynamic>> temporaryRules,
  ) {
    final acls = <Map<String, dynamic>>[];
    for (final rule in temporaryRules) {
      final src = rule['src'] as String?;
      final dst = rule['dst'] as String?;
      final port = rule['port'] as String?;
      final proto = rule['proto'] as String? ?? 'any';

      if (src == null || dst == null) continue;
      final dstPort = (port != null && port.isNotEmpty) ? ':$port' : ':*';

      final ruleMap = <String, dynamic>{
        'action': 'accept',
        'src': [src],
      };
      if (proto != 'any') {
        ruleMap['proto'] = proto;
      }

      if (dst.startsWith('tag:')) {
        acls.add({...ruleMap, 'dst': ['$dst$dstPort']});
        final reverseRuleMap = <String, dynamic>{
          'action': 'accept',
          'src': [dst],
          'dst': ['$src$dstPort'],
        };
        if (proto != 'any') reverseRuleMap['proto'] = proto;
        acls.add(reverseRuleMap);
      } else {
        final destinations = dst
            .split(',')
            .map((d) => d.trim())
            .where((d) => d.isNotEmpty)
            .map((d) => '$d$dstPort')
            .toList();
        if (destinations.isNotEmpty) {
          acls.add({...ruleMap, 'dst': destinations});
        }
      }
    }
    return acls;
  }

  /// Parse une politique brute HuJSON/JSON en Map, ou retourne null si vide.
  static Map<String, dynamic>? parseServerPolicy(String rawPolicy) {
    final trimmed = rawPolicy.trim();
    if (trimmed.isEmpty) return null;
    final decoded = JsonUtils.decodeHuJson(trimmed);
    if (decoded is Map) {
      return deepCopyMap(Map<String, dynamic>.from(decoded));
    }
    return null;
  }

  /// Récupère et parse la politique serveur en tolérant uniquement l'absence
  /// de politique (vide / 404 / "not found"). Les erreurs réseau ou 5xx sont
  /// propagées pour éviter d'écraser des règles manuelles.
  static Future<Map<String, dynamic>?> fetchServerPolicySafely(
    HeadscaleApiService apiService,
  ) async {
    final bundle = await fetchServerPolicyBundleSafely(apiService);
    return bundle.policy;
  }

  /// Récupère le texte HuJSON brut, le Map décodé ainsi que les commentaires
  /// extraits du serveur (règles + en-tête).
  static Future<({
    String rawText,
    Map<String, dynamic>? policy,
    Map<String, String> ruleComments,
    String? leadingComments,
  })> fetchServerPolicyBundleSafely(
    HeadscaleApiService apiService,
  ) async {
    try {
      final raw = await apiService.getAclPolicy();
      return (
        rawText: raw,
        policy: parseServerPolicy(raw),
        ruleComments: HuJsonCommentService.extractRuleComments(raw),
        leadingComments: HuJsonCommentService.extractLeadingComments(raw),
      );
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('statut : 404') ||
          msg.contains('status: 404') ||
          msg.contains('not found')) {
        return (
          rawText: '',
          policy: null,
          ruleComments: const <String, String>{},
          leadingComments: null,
        );
      }
      rethrow;
    }
  }

  /// Récupère (si nécessaire) la politique serveur, fusionne avec [generatedPolicy],
  /// préserve les règles personnalisées (`grants`/`acls` si [preserveCustomRules] est
  /// vrai) et les commentaires HuJSON existants (et ceux de [overrideRuleComments]),
  /// puis envoie le résultat via `setAclPolicy`.
  static Future<Map<String, dynamic>> applyPreservingPolicy({
    required HeadscaleApiService apiService,
    required Map<String, dynamic> generatedPolicy,
    Map<String, dynamic>? serverPolicy,
    String? rawServerPolicy,
    Map<String, String>? overrideRuleComments,
    Set<String> removedCommentSignatures = const {},
    bool pretty = false,
    bool preserveCustomRules = true,
    List<Map<String, dynamic>> excludedServerAcls = const [],
  }) async {
    Map<String, dynamic>? existing = serverPolicy;
    Map<String, String> serverRuleComments = const {};
    String? leadingComments;

    if (rawServerPolicy != null) {
      existing ??= parseServerPolicy(rawServerPolicy);
      serverRuleComments =
          HuJsonCommentService.extractRuleComments(rawServerPolicy);
      leadingComments =
          HuJsonCommentService.extractLeadingComments(rawServerPolicy);
    } else if (existing == null) {
      final bundle = await fetchServerPolicyBundleSafely(apiService);
      existing = bundle.policy;
      serverRuleComments = bundle.ruleComments;
      leadingComments = bundle.leadingComments;
    } else {
      // Uniquement si seul serverPolicy est passé, tenter de préserver les commentaires serveur
      try {
        final bundle = await fetchServerPolicyBundleSafely(apiService);
        serverRuleComments = bundle.ruleComments;
        leadingComments = bundle.leadingComments;
      } catch (_) {}
    }

    final merged = merge(
      generatedPolicy,
      existing,
      preserveCustomRules: preserveCustomRules,
      excludedServerAcls: excludedServerAcls,
    );

    final finalComments = <String, String>{...serverRuleComments};
    for (final sig in removedCommentSignatures) {
      finalComments.remove(sig);
    }
    if (overrideRuleComments != null) {
      overrideRuleComments.forEach((sig, comment) {
        if (comment.trim().isEmpty) {
          finalComments.remove(sig);
        } else {
          finalComments[sig] = comment.trim();
        }
      });
    }

    final hasComments = finalComments.isNotEmpty ||
        (leadingComments != null && leadingComments.trim().isNotEmpty);

    final payload = hasComments
        ? HuJsonCommentService.formatPolicyWithComments(
            merged,
            ruleComments: finalComments,
            leadingComments: leadingComments,
          )
        : (pretty
            ? const JsonEncoder.withIndent('  ').convert(merged)
            : jsonEncode(merged));
    await apiService.setAclPolicy(payload);
    return merged;
  }

  static Map<String, dynamic>? _mergeHosts({
    dynamic generatedHosts,
    dynamic serverHosts,
  }) {
    if (serverHosts is! Map && generatedHosts is! Map) return null;

    final merged = <String, dynamic>{};
    if (generatedHosts is Map) {
      for (final entry in generatedHosts.entries) {
        merged[entry.key.toString()] = _deepCopyValue(entry.value);
      }
    }
    if (serverHosts is Map) {
      // Les entrées manuelles du serveur priment sans écrasement
      for (final entry in serverHosts.entries) {
        merged[entry.key.toString()] = _deepCopyValue(entry.value);
      }
    }
    return merged;
  }

  static List<dynamic> _mergeNodeAttrs({
    dynamic generatedNodeAttrs,
    dynamic serverNodeAttrs,
  }) {
    final merged = <dynamic>[];

    if (serverNodeAttrs is List) {
      for (final item in serverNodeAttrs) {
        if (!_isTaildriveNodeAttr(item)) {
          merged.add(_deepCopyValue(item));
        }
      }
    }

    if (generatedNodeAttrs is List) {
      for (final item in generatedNodeAttrs) {
        merged.add(_deepCopyValue(item));
      }
    }

    return merged;
  }

  static bool _isTaildriveNodeAttr(dynamic item) {
    if (item is! Map) return false;
    final attrs = item['attr'];
    if (attrs is! List) return false;
    return attrs.any(
      (a) => _taildriveNodeAttrs.contains(a.toString()),
    );
  }

  /// Crée une copie profonde d'une politique ACL afin d'éviter les mutations partagées.
  static Map<String, dynamic> deepCopyMap(Map<String, dynamic> source) {
    return source.map(
      (key, value) => MapEntry(key, _deepCopyValue(value)),
    );
  }

  static dynamic _deepCopyValue(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, val) => MapEntry(key.toString(), _deepCopyValue(val)),
      );
    }
    if (value is List) {
      return value.map(_deepCopyValue).toList();
    }
    return value;
  }

  static bool _isTaildriveGrant(Map<String, dynamic> grant) {
    final app = grant['app'];
    if (app is! Map) return false;
    return app.keys.any((k) => k.toString().contains('taildrive'));
  }

  static String _stripAclPort(String value) {
    if (value.startsWith('tag:')) {
      final secondColon = value.indexOf(':', 4);
      return secondColon == -1 ? value : value.substring(0, secondColon);
    }
    if (value.startsWith('group:')) {
      final secondColon = value.indexOf(':', 6);
      return secondColon == -1 ? value : value.substring(0, secondColon);
    }
    return value;
  }

  static bool _hasValidRuleReferences(
    Map<String, dynamic> rule, {
    required Set<String>? declaredTags,
    required Set<String>? declaredGroups,
    required bool includeVia,
  }) {
    bool checkField(dynamic rawList) {
      if (rawList is! List) return true;
      for (final item in rawList) {
        final raw = item.toString();
        final base = _stripAclPort(raw);
        if (base.startsWith('tag:') &&
            declaredTags != null &&
            !declaredTags.contains(base)) {
          return false;
        }
        if (base.startsWith('group:') &&
            declaredGroups != null &&
            !declaredGroups.contains(base)) {
          return false;
        }
      }
      return true;
    }

    if (!checkField(rule['src']) || !checkField(rule['dst'])) {
      return false;
    }
    if (includeVia && !checkField(rule['via'])) {
      return false;
    }
    return true;
  }

  static bool _isGrantSubsumedBy(
    Map<String, dynamic> candidate,
    Map<String, dynamic> generated,
  ) {
    if (candidate['app'] != null || generated['app'] != null) return false;

    final genIp = (generated['ip'] as List?)?.map((e) => e.toString()).toSet();
    final candIp = (candidate['ip'] as List?)?.map((e) => e.toString()).toSet();
    if (genIp == null || !genIp.contains('*')) return false;
    if (candIp == null || candIp.isEmpty) return false;

    final genVia =
        (generated['via'] as List?)?.map((e) => e.toString()).toSet() ??
            const <String>{};
    final candVia =
        (candidate['via'] as List?)?.map((e) => e.toString()).toSet() ??
            const <String>{};
    if (genVia.length != candVia.length || !genVia.containsAll(candVia)) {
      return false;
    }

    final genSrc =
        (generated['src'] as List?)?.map((e) => e.toString()).toSet() ??
            const <String>{};
    final candSrc =
        (candidate['src'] as List?)?.map((e) => e.toString()).toSet() ??
            const <String>{};
    final genDst =
        (generated['dst'] as List?)?.map((e) => e.toString()).toSet() ??
            const <String>{};
    final candDst =
        (candidate['dst'] as List?)?.map((e) => e.toString()).toSet() ??
            const <String>{};

    if (candSrc.isEmpty || candDst.isEmpty) return false;
    return genSrc.containsAll(candSrc) && genDst.containsAll(candDst);
  }

  static bool _isAclSubsumedBy(
    Map<String, dynamic> candidate,
    Map<String, dynamic> generated,
  ) {
    if (candidate['action'] != 'accept' || generated['action'] != 'accept') {
      return false;
    }
    final candProto = (candidate['proto'] ?? 'any').toString();
    final genProto = (generated['proto'] ?? 'any').toString();
    if (genProto != 'any' && candProto != genProto) return false;

    final genSrc =
        (generated['src'] as List?)?.map((e) => e.toString()).toSet() ??
            const <String>{};
    final candSrc =
        (candidate['src'] as List?)?.map((e) => e.toString()).toSet() ??
            const <String>{};
    if (candSrc.isEmpty || !genSrc.containsAll(candSrc)) return false;

    final genDst =
        (generated['dst'] as List?)?.map((e) => e.toString()).toSet() ??
            const <String>{};
    final candDst =
        (candidate['dst'] as List?)?.map((e) => e.toString()).toSet() ??
            const <String>{};
    if (candDst.isEmpty) return false;

    return candDst.every((d) {
      if (genDst.contains(d)) return true;
      final lastColon = d.lastIndexOf(':');
      if (lastColon <= 0) return false;
      final target = d.substring(0, lastColon);
      return genDst.contains('$target:*');
    });
  }

  static String _canonicalJsonEncode(dynamic value) =>
      jsonEncode(_canonicalizeValue(value));

  static dynamic _canonicalizeValue(dynamic value) {
    if (value is Map) {
      final sortedKeys = value.keys.map((k) => k.toString()).toList()..sort();
      return {
        for (final k in sortedKeys) k: _canonicalizeValue(value[k]),
      };
    }
    if (value is List) {
      return value.map(_canonicalizeValue).toList();
    }
    return value;
  }
}

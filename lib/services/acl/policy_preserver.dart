import 'dart:convert';
import 'package:headscalemanager/api/headscale_api_service.dart';
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
  static Map<String, dynamic> merge(
    Map<String, dynamic> generatedPolicy,
    Map<String, dynamic>? serverPolicy,
  ) {
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

    return result;
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
    try {
      final raw = await apiService.getAclPolicy();
      return parseServerPolicy(raw);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('statut : 404') ||
          msg.contains('status: 404') ||
          msg.contains('not found')) {
        return null;
      }
      rethrow;
    }
  }

  /// Récupère (si nécessaire) la politique serveur, fusionne avec [generatedPolicy],
  /// puis envoie le résultat via `setAclPolicy`.
  static Future<Map<String, dynamic>> applyPreservingPolicy({
    required HeadscaleApiService apiService,
    required Map<String, dynamic> generatedPolicy,
    Map<String, dynamic>? serverPolicy,
    String? rawServerPolicy,
    bool pretty = false,
  }) async {
    Map<String, dynamic>? existing = serverPolicy;
    if (existing == null && rawServerPolicy != null) {
      existing = parseServerPolicy(rawServerPolicy);
    } else {
      existing ??= await fetchServerPolicySafely(apiService);
    }

    final merged = merge(generatedPolicy, existing);
    final payload = pretty
        ? const JsonEncoder.withIndent('  ').convert(merged)
        : jsonEncode(merged);
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
}

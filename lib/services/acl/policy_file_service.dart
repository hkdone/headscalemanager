import 'dart:convert';

import 'package:headscalemanager/utils/json_utils.dart';

/// Lecture, validation et modèles de policy ACL Headscale (fichier JSON).
class PolicyFileService {
  static const JsonEncoder encoder = JsonEncoder.withIndent('  ');

  /// Policy minimale « tout autoriser » — point de départ pour un brouillon local.
  static Map<String, dynamic> allowAllTemplate() => {
        'groups': <String, dynamic>{},
        'tagOwners': <String, dynamic>{},
        'acls': [
          {
            'action': 'accept',
            'src': ['*'],
            'dst': ['*:*'],
          },
        ],
        'grants': <Map<String, dynamic>>[],
      };

  /// Parse et valide le contenu d'un fichier policy JSON (HuJSON toléré).
  static Map<String, dynamic> parsePolicyContent(String raw) {
    final cleaned = JsonUtils.cleanJsonComments(raw.trim());
    if (cleaned.isEmpty) {
      throw const FormatException('Fichier vide');
    }

    final decoded = json.decode(cleaned);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
          'La policy doit être un objet JSON ({}), pas un tableau ou une valeur simple.');
    }

    validatePolicy(decoded);
    return decoded;
  }

  /// Vérifie qu'au moins une section policy connue est présente.
  static void validatePolicy(Map<String, dynamic> policy) {
    const knownKeys = {
      'acls',
      'grants',
      'groups',
      'tagOwners',
      'hosts',
      'tests',
      'ssh',
      'nodeAttrs',
      'autoApprovers',
      'ipsets',
    };

    final hasKnownSection = policy.keys.any(knownKeys.contains);
    if (!hasKnownSection) {
      throw const FormatException(
          'Aucune section policy reconnue (acls, grants, groups, tagOwners, …).');
    }
  }

  static String encodePolicy(Map<String, dynamic> policy) =>
      encoder.convert(policy);

  static String backupFileName({DateTime? at}) {
    final date = at ?? DateTime.now();
    final stamp =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}-'
        '${date.hour.toString().padLeft(2, '0')}${date.minute.toString().padLeft(2, '0')}';
    return 'headscale-policy-$stamp.json';
  }
}

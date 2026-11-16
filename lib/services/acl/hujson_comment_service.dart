import 'dart:convert';
import 'package:headscalemanager/utils/json_utils.dart';

/// Gère l'extraction et la réinjection de commentaires HuJSON (`// ...`)
/// associés aux règles `grants` et `acls` (ligne immédiatement au-dessus de `{`).
class HuJsonCommentService {
  /// Signature canonique d'une règle (`src:...|via:...|dst:...`), identique à
  /// `PuzzleRule.signature` et `GrantComposerService.grantSignature`.
  static String ruleSignature(
    Map<String, dynamic> rule, {
    required bool isGrant,
  }) {
    final src = ((rule['src'] as List?)?.map((e) => e.toString()).toList() ??
        [])
      ..sort();
    final via = ((rule['via'] as List?)?.map((e) => e.toString()).toList() ??
        [])
      ..sort();
    final dst = ((rule['dst'] as List?)?.map((e) {
          var s = e.toString();
          if (!isGrant && s.endsWith(':*')) {
            s = s.substring(0, s.length - 2);
          }
          return s;
        }).toList() ??
        [])
      ..sort();
    return 'src:${src.join(",")}|via:${via.join(",")}|dst:${dst.join(",")}';
  }

  /// Extrait les éventuelles lignes de commentaires placées en tête de fichier,
  /// avant la première accolade `{`.
  static String? extractLeadingComments(String raw) {
    if (raw.trim().isEmpty) return null;
    final lines = <String>[];
    final len = raw.length;
    int i = 0;

    while (i < len) {
      final ch = raw[i];
      if (_isWhitespace(ch)) {
        i++;
        continue;
      }
      if (ch == '/' && i + 1 < len) {
        if (raw[i + 1] == '/') {
          final start = i;
          i += 2;
          while (i < len && raw[i] != '\n') {
            i++;
          }
          lines.add(raw.substring(start, i).trimRight());
          continue;
        }
        if (raw[i + 1] == '*') {
          final start = i;
          i += 2;
          while (i + 1 < len && !(raw[i] == '*' && raw[i + 1] == '/')) {
            i++;
          }
          if (i + 1 < len) i += 2;
          lines.add(raw.substring(start, i).trimRight());
          continue;
        }
      }
      break;
    }

    if (lines.isEmpty) return null;
    return lines.join('\n');
  }

  /// Extrait les commentaires situés juste avant chaque règle `{ ... }` dans
  /// les tableaux racine `"grants"` et `"acls"`, indexés par `ruleSignature`.
  static Map<String, String> extractRuleComments(String raw) {
    final result = <String, String>{};
    if (raw.trim().isEmpty) return result;

    final len = raw.length;
    int i = 0;
    int braceDepth = 0;

    int skipString(int start) {
      int pos = start + 1;
      bool escaped = false;
      while (pos < len) {
        final c = raw[pos];
        if (escaped) {
          escaped = false;
        } else if (c == '\\') {
          escaped = true;
        } else if (c == '"') {
          return pos + 1;
        }
        pos++;
      }
      return len;
    }

    int skipWsAndComments(int pos, {List<String>? collectedComments}) {
      while (pos < len) {
        final c = raw[pos];
        if (_isWhitespace(c)) {
          pos++;
          continue;
        }
        if (c == '/' && pos + 1 < len) {
          if (raw[pos + 1] == '/') {
            pos += 2;
            final cStart = pos;
            while (pos < len && raw[pos] != '\n') {
              pos++;
            }
            if (collectedComments != null) {
              final text = raw.substring(cStart, pos).trim();
              if (text.isNotEmpty) collectedComments.add(text);
            }
            continue;
          }
          if (raw[pos + 1] == '*') {
            pos += 2;
            final cStart = pos;
            while (pos + 1 < len && !(raw[pos] == '*' && raw[pos + 1] == '/')) {
              pos++;
            }
            final cEnd = pos;
            if (pos + 1 < len) pos += 2;
            if (collectedComments != null) {
              for (final line in raw.substring(cStart, cEnd).split('\n')) {
                final cleaned = line.trim().replaceFirst(RegExp(r'^\*\s?'), '').trim();
                if (cleaned.isNotEmpty) collectedComments.add(cleaned);
              }
            }
            continue;
          }
        }
        break;
      }
      return pos;
    }

    int parseRuleArray(int openBracketPos, {required bool isGrant}) {
      int pos = openBracketPos + 1;
      final pending = <String>[];

      while (pos < len) {
        pos = skipWsAndComments(pos, collectedComments: pending);
        if (pos >= len) break;

        final c = raw[pos];
        if (c == ']') {
          return pos + 1;
        }
        if (c == ',') {
          pending.clear();
          pos++;
          continue;
        }
        if (c == '{') {
          final objStart = pos;
          int objDepth = 0;
          while (pos < len) {
            final oc = raw[pos];
            if (oc == '"') {
              pos = skipString(pos);
              continue;
            }
            if (oc == '/' && pos + 1 < len && (raw[pos + 1] == '/' || raw[pos + 1] == '*')) {
              pos = skipWsAndComments(pos);
              continue;
            }
            if (oc == '{') {
              objDepth++;
            } else if (oc == '}') {
              objDepth--;
              if (objDepth == 0) {
                pos++;
                break;
              }
            }
            pos++;
          }

          if (pending.isNotEmpty) {
            final objSlice = raw.substring(objStart, pos);
            try {
              final decoded = JsonUtils.decodeHuJson(objSlice);
              if (decoded is Map) {
                final sig = ruleSignature(
                  Map<String, dynamic>.from(decoded),
                  isGrant: isGrant,
                );
                result[sig] = pending.join('\n');
              }
            } catch (_) {
              // Ignorer un objet malformé pendant une édition en cours
            }
            pending.clear();
          }
          continue;
        }

        // Tout autre token inattendu dans le tableau
        if (c == '"') {
          pos = skipString(pos);
        } else {
          pos++;
        }
      }
      return pos;
    }

    while (i < len) {
      i = skipWsAndComments(i);
      if (i >= len) break;

      final c = raw[i];
      if (c == '"') {
        final keyEnd = skipString(i);
        if (braceDepth == 1) {
          final rawKeySlice = raw.substring(i, keyEnd);
          String? keyName;
          try {
            final decodedKey = jsonDecode(rawKeySlice);
            if (decodedKey is String) keyName = decodedKey;
          } catch (_) {}

          final afterKey = skipWsAndComments(keyEnd);
          if (afterKey < len && raw[afterKey] == ':' &&
              (keyName == 'grants' || keyName == 'acls')) {
            final afterColon = skipWsAndComments(afterKey + 1);
            if (afterColon < len && raw[afterColon] == '[') {
              i = parseRuleArray(
                afterColon,
                isGrant: keyName == 'grants',
              );
              continue;
            }
          }
        }
        i = keyEnd;
        continue;
      }

      if (c == '{') {
        braceDepth++;
      } else if (c == '}') {
        if (braceDepth > 0) braceDepth--;
      }
      i++;
    }

    return result;
  }

  /// Formate [policy] en HuJSON (indentation 2 espaces) en insérant les
  /// commentaires `// ...` immédiatement avant `{` pour chaque règle dans
  /// `"grants"` et `"acls"` présente dans [ruleComments].
  static String formatPolicyWithComments(
    Map<String, dynamic> policy, {
    Map<String, String> ruleComments = const {},
    String? leadingComments,
  }) {
    final buffer = StringBuffer();
    if (leadingComments != null && leadingComments.trim().isNotEmpty) {
      buffer.writeln(leadingComments.trimRight());
    }
    _writeMap(
      buffer,
      policy,
      indent: 0,
      isRoot: true,
      ruleComments: ruleComments,
    );
    return buffer.toString();
  }

  static void _writeMap(
    StringBuffer buffer,
    Map<dynamic, dynamic> map, {
    required int indent,
    required bool isRoot,
    required Map<String, String> ruleComments,
  }) {
    if (map.isEmpty) {
      buffer.write('{}');
      return;
    }

    buffer.writeln('{');
    final entries = map.entries.toList();
    for (int idx = 0; idx < entries.length; idx++) {
      final entry = entries[idx];
      final key = entry.key.toString();
      final isLast = idx == entries.length - 1;

      buffer.write('${'  ' * (indent + 1)}${jsonEncode(key)}: ');

      if (isRoot &&
          (key == 'grants' || key == 'acls') &&
          entry.value is List) {
        _writeRuleList(
          buffer,
          entry.value as List<dynamic>,
          indent: indent + 1,
          isGrant: key == 'grants',
          ruleComments: ruleComments,
        );
      } else {
        _writeValue(
          buffer,
          entry.value,
          indent: indent + 1,
          ruleComments: ruleComments,
        );
      }

      if (!isLast) buffer.write(',');
      buffer.writeln();
    }
    buffer.write('${'  ' * indent}}');
  }

  static void _writeRuleList(
    StringBuffer buffer,
    List<dynamic> list, {
    required int indent,
    required bool isGrant,
    required Map<String, String> ruleComments,
  }) {
    if (list.isEmpty) {
      buffer.write('[]');
      return;
    }

    buffer.writeln('[');
    final childIndent = '  ' * (indent + 1);
    for (int idx = 0; idx < list.length; idx++) {
      final item = list[idx];
      final isLast = idx == list.length - 1;

      if (item is Map) {
        final itemMap = Map<String, dynamic>.from(item);
        final sig = ruleSignature(itemMap, isGrant: isGrant);
        final comment = ruleComments[sig];
        if (comment != null && comment.trim().isNotEmpty) {
          for (final line in comment.trim().split('\n')) {
            final cleanLine = line.trim();
            if (cleanLine.isNotEmpty) {
              buffer.writeln('$childIndent// $cleanLine');
            }
          }
        }
      }

      buffer.write(childIndent);
      _writeValue(
        buffer,
        item,
        indent: indent + 1,
        ruleComments: ruleComments,
      );
      if (!isLast) buffer.write(',');
      buffer.writeln();
    }
    buffer.write('${'  ' * indent}]');
  }

  static void _writeValue(
    StringBuffer buffer,
    dynamic value, {
    required int indent,
    required Map<String, String> ruleComments,
  }) {
    if (value is Map) {
      _writeMap(
        buffer,
        value,
        indent: indent,
        isRoot: false,
        ruleComments: ruleComments,
      );
      return;
    }
    if (value is List) {
      if (value.isEmpty) {
        buffer.write('[]');
        return;
      }
      buffer.writeln('[');
      final childIndent = '  ' * (indent + 1);
      for (int idx = 0; idx < value.length; idx++) {
        final isLast = idx == value.length - 1;
        buffer.write(childIndent);
        _writeValue(
          buffer,
          value[idx],
          indent: indent + 1,
          ruleComments: ruleComments,
        );
        if (!isLast) buffer.write(',');
        buffer.writeln();
      }
      buffer.write('${'  ' * indent}]');
      return;
    }
    buffer.write(jsonEncode(value));
  }

  static bool _isWhitespace(String ch) {
    return ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n';
  }
}

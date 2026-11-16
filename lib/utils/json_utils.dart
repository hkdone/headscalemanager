import 'dart:convert';

class JsonUtils {
  /// Nettoie une chaîne HuJSON / JSONC pour la rendre compatible avec `jsonDecode` :
  /// - préserve intégralement les chaînes littérales `"..."` (avec gestion des échappements `\"` et `\\`),
  /// - supprime les commentaires `//...` et `/* ... */` hors chaînes,
  /// - supprime les virgules finales (trailing commas) avant `}` ou `]` hors chaînes.
  static String cleanJsonComments(String jsonString) {
    if (jsonString.isEmpty) return jsonString;

    final withoutComments = _stripCommentsOutsideStrings(jsonString);
    return _stripTrailingCommasOutsideStrings(withoutComments);
  }

  /// Nettoie puis décode une chaîne HuJSON en objet Dart (`Map`, `List`, etc.).
  static dynamic decodeHuJson(String raw) {
    return jsonDecode(cleanJsonComments(raw));
  }

  static String _stripCommentsOutsideStrings(String input) {
    final buffer = StringBuffer();
    bool inString = false;
    bool escaped = false;
    final int len = input.length;

    for (int i = 0; i < len; i++) {
      final char = input[i];

      if (inString) {
        buffer.write(char);
        if (escaped) {
          escaped = false;
        } else if (char == '\\') {
          escaped = true;
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }

      if (char == '"') {
        inString = true;
        buffer.write(char);
        continue;
      }

      if (char == '/' && i + 1 < len) {
        final next = input[i + 1];
        // Commentaire ligne // ...
        if (next == '/') {
          i += 2;
          while (i < len && input[i] != '\n') {
            i++;
          }
          if (i < len && input[i] == '\n') {
            buffer.write('\n');
          }
          continue;
        }
        // Commentaire bloc /* ... */
        if (next == '*') {
          i += 2;
          while (i + 1 < len && !(input[i] == '*' && input[i + 1] == '/')) {
            if (input[i] == '\n') {
              buffer.write('\n');
            }
            i++;
          }
          i++; // Saute le '/' fermant (ou termine proprement en fin de chaîne)
          continue;
        }
      }

      buffer.write(char);
    }

    return buffer.toString();
  }

  static String _stripTrailingCommasOutsideStrings(String input) {
    final buffer = StringBuffer();
    bool inString = false;
    bool escaped = false;
    final int len = input.length;

    for (int i = 0; i < len; i++) {
      final char = input[i];

      if (inString) {
        buffer.write(char);
        if (escaped) {
          escaped = false;
        } else if (char == '\\') {
          escaped = true;
        } else if (char == '"') {
          inString = false;
        }
        continue;
      }

      if (char == '"') {
        inString = true;
        buffer.write(char);
        continue;
      }

      if (char == ',') {
        int lookahead = i + 1;
        while (lookahead < len && _isWhitespace(input[lookahead])) {
          lookahead++;
        }
        if (lookahead < len &&
            (input[lookahead] == '}' || input[lookahead] == ']')) {
          // Virgule finale détectée hors chaîne : on l'omet
          continue;
        }
      }

      buffer.write(char);
    }

    return buffer.toString();
  }

  static bool _isWhitespace(String ch) {
    return ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n';
  }
}

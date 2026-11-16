import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:headscalemanager/utils/json_utils.dart';

void main() {
  group('JsonUtils.cleanJsonComments (HuJSON)', () {
    test('supprime les commentaires //, /* ... */ et virgules finales', () {
      const hujson = '''
      {
        // Commentaire en ligne
        "groups": {
          "group:admins": ["alice@",],
        },
        /* Commentaire
           multi-lignes */
        "acls": [
          {
            "action": "accept", // inline comment
            "src": ["group:admins", ],
            "dst": ["*:*"],
          },
        ],
      }
      ''';

      final decoded = jsonDecode(JsonUtils.cleanJsonComments(hujson))
          as Map<String, dynamic>;
      expect((decoded['groups'] as Map)['group:admins'], ['alice@']);
      expect((decoded['acls'] as List).length, 1);
    });

    test('préserve intégralement //, /*, */, et ,} à l’intérieur des chaînes', () {
      const hujson = r'''
      {
        "commentUrl": "https://example.com//v1/*not-comment*/path",
        "trickyComma": "foo, }",
        "escapedQuote": "hello \" // not comment \\", // réel commentaire
        "trailing": [1, 2,],
      }
      ''';

      final decoded =
          JsonUtils.decodeHuJson(hujson) as Map<String, dynamic>;
      expect(
        decoded['commentUrl'],
        'https://example.com//v1/*not-comment*/path',
      );
      expect(decoded['trickyComma'], 'foo, }');
      expect(decoded['escapedQuote'], r'hello " // not comment \');
      expect(decoded['trailing'], [1, 2]);
    });
  });
}

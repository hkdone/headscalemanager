import 'dart:convert';
import 'package:headscalemanager/utils/string_utils.dart';
import 'package:http/http.dart' as http;
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/models/pre_auth_key.dart';
import 'package:headscalemanager/models/api_key.dart';
import '../models/version_info.dart';

class HeadscaleApiService {
  final String _apiKey;
  final String _baseUrl;

  HeadscaleApiService({required String apiKey, required String baseUrl})
      : _apiKey = apiKey,
        _baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl;

  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };
  }

  String _handleError(String functionName, http.Response response) {
    return 'Échec de $functionName. Statut : ${response.statusCode}, Corps : ${response.body}';
  }

  Future<List<Node>> getNodes() async {
    final String baseDomain = _baseUrl.extractBaseDomain() ?? 'headscale.local';

    final response = await http.get(
      Uri.parse('$_baseUrl/api/v1/node'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> nodesJson = data['nodes'];
      return nodesJson
          .map((nodeJson) =>
              Node.fromJson(nodeJson as Map<String, dynamic>, baseDomain))
          .toList();
    } else {
      throw Exception(_handleError('charger les nœuds', response));
    }
  }

  Future<Node> getNodeDetails(String nodeId) async {
    final String baseDomain = _baseUrl.extractBaseDomain() ?? 'headscale.local';

    final response = await http.get(
      Uri.parse('$_baseUrl/api/v1/node/$nodeId'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      return Node.fromJson(json.decode(response.body)['node'], baseDomain);
    } else {
      throw Exception(_handleError('charger les détails du nœud', response));
    }
  }

  Future<Node> registerMachine(String machineKey, String userName) async {
    final String baseDomain = _baseUrl.extractBaseDomain() ?? 'headscale.local';

    final response = await http.post(
      Uri.parse(
          '$_baseUrl/api/v1/node/register?user=$userName&key=$machineKey'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Node.fromJson(data['node'], baseDomain);
    } else {
      throw Exception(_handleError('enregistrer la machine', response));
    }
  }

  Future<List<User>> getUsers() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/v1/user'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> usersJson = data['users'];
      return usersJson.map((json) => User.fromJson(json)).toList();
    } else {
      throw Exception(_handleError('charger les utilisateurs', response));
    }
  }

  Future<User> createUser(String name) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/user'),
      headers: _getHeaders(),
      body: jsonEncode(<String, String>{'name': name}),
    );

    if (response.statusCode == 200) {
      return User.fromJson(json.decode(response.body));
    } else {
      throw Exception(_handleError('créer un utilisateur', response));
    }
  }

  Future<PreAuthKey> createPreAuthKey(
      String userId, bool reusable, bool ephemeral,
      {DateTime? expiration, List<String>? aclTags}) async {
    final body = {
      'user': userId,
      'reusable': reusable,
      'ephemeral': ephemeral,
    };

    if (expiration != null) {
      body['expiration'] = expiration.toUtc().toIso8601String();
    }

    if (aclTags != null && aclTags.isNotEmpty) {
      body['aclTags'] = aclTags;
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/preauthkey'),
      headers: _getHeaders(),
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final preAuthKeyJson = data['preAuthKey'];
      return PreAuthKey.fromJson(preAuthKeyJson);
    } else {
      throw Exception(
          _handleError('créer une clé de pré-authentification', response));
    }
  }

  Future<String> getAclPolicy() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/v1/policy'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['policy'] != null) {
        return data['policy'];
      } else {
        return '';
      }
    } else {
      throw Exception(_handleError('charger la politique ACL', response));
    }
  }

  Future<void> setAclPolicy(String aclPolicy) async {
    final body = jsonEncode({'policy': aclPolicy});

    final response = await http.put(
      Uri.parse('$_baseUrl/api/v1/policy'),
      headers: _getHeaders(),
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception(_handleError('sauvegarder la politique ACL', response));
    }
  }

  Future<void> deleteUser(String userId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/v1/user/$userId'),
      headers: _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(_handleError('supprimer l\'utilisateur', response));
    }
  }

  Future<void> deleteNode(String nodeId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/v1/node/$nodeId'),
      headers: _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(_handleError('supprimer le nœud', response));
    }
  }

  Future<void> setNodeRoutes(String nodeId, List<String> routes) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/node/$nodeId/approve_routes'),
      headers: _getHeaders(),
      body: jsonEncode(<String, dynamic>{'routes': routes}),
    );

    if (response.statusCode != 200) {
      throw Exception(_handleError('définir les routes du nœud', response));
    }
  }

  Future<void> renameNode(String nodeId, String newName) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/node/$nodeId/rename/$newName'),
      headers: _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(_handleError('renommer le nœud', response));
    }
  }

  Future<void> moveNode(String nodeId, User newUser) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/node/$nodeId/user'),
      headers: _getHeaders(),
      body: jsonEncode(<String, String>{'user': newUser.id}),
    );

    if (response.statusCode != 200) {
      throw Exception(_handleError('déplacer le nœud', response));
    }
  }

  Future<void> renameUser(String oldId, String newName) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/user/$oldId/rename/$newName'),
      headers: _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(_handleError('renommer l\'utilisateur', response));
    }
  }

  Future<List<PreAuthKey>> getPreAuthKeys({String? serverVersion}) async {
    final List<PreAuthKey> allPreAuthKeys = [];

    // HEADSCALE v0.28+ : Endpoint global /api/v1/preauthkey
    if (serverVersion != null &&
        VersionInfo.checkVersionAtLeast(serverVersion, '0.28.0')) {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/preauthkey'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> keysJson = data['preAuthKeys'] ?? [];
        allPreAuthKeys
            .addAll(keysJson.map((json) => PreAuthKey.fromJson(json)).toList());
      } else {
        throw Exception(_handleError('charger les clés (v0.28+)', response));
      }
      return allPreAuthKeys;
    }

    // HEADSCALE < v0.28 : Boucle sur chaque utilisateur
    final users = await getUsers();

    for (final user in users) {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/preauthkey?user=${user.id}'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> keysJson = data['preAuthKeys'] ?? [];
        allPreAuthKeys
            .addAll(keysJson.map((json) => PreAuthKey.fromJson(json)).toList());
      } else {
        // Log error but continue with other users
      }
    }

    return allPreAuthKeys;
  }

  Future<void> expirePreAuthKey(String userId, String key,
      {String? serverVersion, String? keyId}) async {
    // HEADSCALE v0.28+ : Expiration par ID
    if (serverVersion != null &&
        VersionInfo.checkVersionAtLeast(serverVersion, '0.28.0') &&
        keyId != null) {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/preauthkey/expire'),
        headers: _getHeaders(),
        body: jsonEncode(<String, dynamic>{
          'id': keyId, // Nouveau paramètre v0.28
        }),
      );
      if (response.statusCode != 200) {
        throw Exception(_handleError('expirer la clé (ID $keyId)', response));
      }
      return;
    }

    // LEGACY / v0.27 : Expiration par User + Key
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/preauthkey/expire'),
      headers: _getHeaders(),
      body: jsonEncode(<String, String>{
        'user': userId,
        'key': key,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception(
          _handleError('expirer la clé de pré-authentification', response));
    }
  }

  Future<List<ApiKey>> listApiKeys() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/api/v1/apikey'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> apiKeysJson = data['apiKeys'];
      return apiKeysJson.map((json) => ApiKey.fromJson(json)).toList();
    } else {
      throw Exception(_handleError('lister les clés API', response));
    }
  }

  Future<String> createApiKey({DateTime? expiration}) async {
    final body = <String, dynamic>{};
    if (expiration != null) {
      body['expiration'] = expiration.toUtc().toIso8601String();
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/apikey'),
      headers: _getHeaders(),
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['apiKey'];
    } else {
      throw Exception(_handleError('créer la clé API', response));
    }
  }

  Future<void> expireApiKey(String prefix) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/apikey/expire'),
      headers: _getHeaders(),
      body: jsonEncode(<String, String>{'prefix': prefix}),
    );

    if (response.statusCode != 200) {
      throw Exception(_handleError('expirer la clé API', response));
    }
  }

  Future<void> deleteApiKey(String prefix) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/api/v1/apikey/$prefix'),
      headers: _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(_handleError('supprimer la clé API', response));
    }
  }

  Future<Node> setTags(String nodeId, List<String> tags) async {
    final String baseDomain = _baseUrl.extractBaseDomain() ?? 'headscale.local';

    final response = await http.post(
      Uri.parse('$_baseUrl/api/v1/node/$nodeId/tags'),
      headers: _getHeaders(),
      body: jsonEncode(<String, dynamic>{'tags': tags}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Node.fromJson(data['node'], baseDomain);
    } else {
      throw Exception(_handleError('définir les tags', response));
    }
  }

  Future<VersionInfo> getVersion() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/version'),
      headers: {
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return VersionInfo.fromJson(json.decode(response.body));
    } else {
      throw Exception('Impossible de récupérer la version du serveur');
    }
  }
}

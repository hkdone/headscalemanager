import 'dart:convert';
import 'package:headscalemanager/utils/string_utils.dart';
import 'package:http/http.dart' as http;
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/models/pre_auth_key.dart';
import 'package:headscalemanager/models/api_key.dart';
import 'package:headscalemanager/services/storage_service.dart';

/// Service API pour interagir avec le backend Headscale.
/// Cette classe gère toutes les requêtes HTTP vers l'API Headscale,
/// y compris l'authentification et la gestion des erreurs de base.
class HeadscaleApiService {
  /// Instance du service de stockage pour récupérer la clé API et l'URL du serveur.
  final StorageService _storageService = StorageService();

  /// Récupère les en-têtes HTTP nécessaires pour les requêtes API,
  /// incluant le type de contenu, le type d'acceptation et le jeton d'autorisation.
  Future<Map<String, String>> _getHeaders() async {
    final apiKey = await _storageService.getApiKey();
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
  }

  /// Récupère l'URL de base du serveur Headscale à partir du service de stockage.
  /// Assure que l'URL se termine par un slash pour une construction correcte des chemins d'API.
  /// Lève une exception si l'URL du serveur n'est pas configurée.
  Future<String> _getBaseUrl() async {
    final url = await _storageService.getServerUrl();
    if (url == null) {
      throw Exception('L\'URL du serveur n\'est pas configurée.');
    }
    // Assure que l\'URL se termine par un slash pour faciliter la concaténation des chemins d\'API.
    return url.endsWith('/') ? url : '$url/';
  }

  /// Gère les erreurs de réponse HTTP en construisant un message d'erreur descriptif.
  /// Inclut le nom de la fonction qui a échoué, le code de statut et le corps de la réponse.
  String _handleError(String functionName, http.Response response) {
    print('Erreur API: ${response.body}'); // Add this line to print the response body
    return 'Échec de $functionName. Statut : ${response.statusCode}, Corps : ${response.body}';
  }

  /// Récupère tous les nœuds enregistrés auprès de Headscale.
  ///
  /// ATTENTION : Cette implémentation effectue une requête initiale pour obtenir la liste des IDs de nœuds,
  /// puis une requête séparée pour chaque nœud afin d'obtenir ses détails complets.
  /// Cela peut entraîner un problème de "N+1 requêtes" et être inefficace pour un grand nombre de nœuds.
  /// Idéalement, l'API Headscale devrait fournir un endpoint pour récupérer tous les détails en une seule fois.
  Future<List<Node>> getNodes() async {
    // Récupère l'URL de base du serveur.
    final baseUrl = await _getBaseUrl();
    final serverUrl = await _storageService.getServerUrl(); // Get server URL for base domain
    final String baseDomain = serverUrl?.extractBaseDomain() ?? 'headscale.local'; // Extract base domain

    // Effectue la requête GET pour obtenir la liste sommaire des nœuds.
    final response = await http.get(
      Uri.parse('${baseUrl}api/v1/node'),
      headers: await _getHeaders(),
    );

    // Vérifie si la requête a réussi (statut 200 OK).
    if (response.statusCode == 200) {
      // Décode la réponse JSON.
      final data = json.decode(response.body);
      // Extrait la liste des nœuds JSON.
      final List<dynamic> nodesJson = data['nodes'];

      // Mappe directement la liste JSON en une liste d'objets Node.
      // L'endpoint /api/v1/node retourne déjà les détails suffisants.
      return nodesJson
          .map((nodeJson) => Node.fromJson(nodeJson as Map<String, dynamic>, baseDomain))
          .toList();
    } else {
      // Lève une exception si la requête a échoué.
      throw Exception(_handleError('charger les nœuds', response));
    }
  }

  /// Récupère les détails complets d'un seul nœud en utilisant son ID.
  Future<Node> getNodeDetails(String nodeId) async {
    // Récupère l\'URL de base du serveur.
    final baseUrl = await _getBaseUrl();
    final serverUrl = await _storageService.getServerUrl(); // Get server URL for base domain
    final String baseDomain = serverUrl?.extractBaseDomain() ?? 'headscale.local'; // Extract base domain

    // Effectue la requête GET pour obtenir les détails du nœud spécifique.
    final response = await http.get(
      Uri.parse('${baseUrl}api/v1/node/$nodeId'),
      headers: await _getHeaders(),
    );

    // Vérifie si la requête a réussi.
    if (response.statusCode == 200) {
      // Décode la réponse JSON et construit un objet Node à partir des données.
      // Passe le baseDomain au constructeur fromJson du Node.
      return Node.fromJson(json.decode(response.body)['node'], baseDomain); // Supposant que 'node' est la clé pour l\'objet nœud unique
    } else {
      // Lève une exception si la requête a échoué.
      throw Exception(_handleError('charger les détails du nœud', response));
    }
  }

  /// Enregistre une machine pour un utilisateur donné en utilisant la clé de la machine.
  Future<Node> registerMachine(String machineKey, String userName) async {
    final baseUrl = await _getBaseUrl();
    final serverUrl = await _storageService.getServerUrl();
    final String baseDomain = serverUrl?.extractBaseDomain() ?? 'headscale.local';

    final response = await http.post(
      Uri.parse('${baseUrl}api/v1/node/register?user=$userName&key=$machineKey'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Node.fromJson(data['node'], baseDomain);
    } else {
      throw Exception(_handleError('enregistrer la machine', response));
    }
  }

  /// Récupère tous les utilisateurs enregistrés auprès de Headscale.
  Future<List<User>> getUsers() async {
    // Récupère l'URL de base du serveur.
    final baseUrl = await _getBaseUrl();
    // Effectue la requête GET pour obtenir la liste des utilisateurs.
    final response = await http.get(
      Uri.parse('${baseUrl}api/v1/user'),
      headers: await _getHeaders(),
    );

    // Vérifie si la requête a réussi.
    if (response.statusCode == 200) {
      // Décode la réponse JSON et mappe la liste des utilisateurs JSON en objets User.
      final data = json.decode(response.body);
      final List<dynamic> usersJson = data['users'];
      return usersJson.map((json) => User.fromJson(json)).toList();
    } else {
      // Lève une exception si la requête a échoué.
      throw Exception(_handleError('charger les utilisateurs', response));
    }
  }

  /// Crée un nouvel utilisateur avec le nom spécifié.
  Future<User> createUser(String name) async {
    // Récupère l'URL de base du serveur.
    final baseUrl = await _getBaseUrl();
    // Effectue la requête POST pour créer un utilisateur.
    final response = await http.post(
      Uri.parse('${baseUrl}api/v1/user'),
      headers: await _getHeaders(),
      body: jsonEncode(<String, String>{'name': name}),
    );

    // Vérifie si la requête a réussi.
    if (response.statusCode == 200) {
      // Décode la réponse JSON et construit un objet User.
      return User.fromJson(json.decode(response.body));
    } else {
      // Lève une exception si la requête a échoué.
      throw Exception(_handleError('créer un utilisateur', response));
    }
  }

  /// Crée une clé de pré-authentification pour un utilisateur.
  /// Permet de spécifier si la clé est réutilisable, éphémère, sa date d'expiration et les tags ACL.
  Future<PreAuthKey> createPreAuthKey(String userId, bool reusable, bool ephemeral, {DateTime? expiration, List<String>? aclTags}) async {
    // Récupère l'URL de base du serveur.
    final baseUrl = await _getBaseUrl();
    // Construit le corps de la requête avec les paramètres de la clé.
    final body = {
      'user': userId,
      'reusable': reusable,
      'ephemeral': ephemeral,
    };

    // Ajoute la date d'expiration si elle est fournie, formatée en ISO 8601 UTC.
    if (expiration != null) {
      body['expiration'] = expiration.toUtc().toIso8601String();
    }

    // Ajoute les tags ACL s'ils sont fournis.
    if (aclTags != null && aclTags.isNotEmpty) {
      body['aclTags'] = aclTags;
    }

    // Effectue la requête POST pour créer la clé de pré-authentification.
    final response = await http.post(
      Uri.parse('${baseUrl}api/v1/preauthkey'),
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );

    // Vérifie si la requête a réussi.
    if (response.statusCode == 200) {
      // Décode la réponse JSON et extrait l'objet preAuthKey.
      final data = json.decode(response.body);
      final preAuthKeyJson = data['preAuthKey'];
      return PreAuthKey.fromJson(preAuthKeyJson);
    } else {
      // Lève une exception si la requête a échoué.
      throw Exception(_handleError('créer une clé de pré-authentification', response));
    }
  }

  /// Récupère la politique ACL (Access Control List) actuelle.
  Future<String> getAclPolicy() async {
    // Récupère l'URL de base du serveur.
    final baseUrl = await _getBaseUrl();
    // Effectue la requête GET pour obtenir la politique ACL.
    final response = await http.get(
      Uri.parse('${baseUrl}api/v1/policy'),
      headers: await _getHeaders(),
    );

    // Vérifie si la requête a réussi.
    if (response.statusCode == 200) {
      // Décode la réponse JSON et retourne la politique ACL.
      final data = json.decode(response.body);
      // Vérifie si la clé 'policy' existe et n'est pas nulle.
      if (data['policy'] != null) {
        return data['policy'];
      } else {
        // Si 'policy' est nulle ou absente, retourne une chaîne vide ou lève une erreur spécifique.
        // Pour l'instant, nous allons retourner une chaîne vide pour éviter l'erreur de type.
        return '';
      }
    } else {
      // Lève une exception si la requête a échoué.
      throw Exception(_handleError('charger la politique ACL', response));
    }
  }

  /// Définit la politique ACL (Access Control List) avec la chaîne de caractères fournie.
  Future<void> setAclPolicy(String aclPolicy) async {
    // Récupère l'URL de base du serveur.
    final baseUrl = await _getBaseUrl();
    // La politique doit être envoyée dans un objet JSON sous la clé "policy".
    final body = jsonEncode({'policy': aclPolicy});

    // Effectue la requête PUT pour définir la politique ACL.
    final response = await http.put(
      Uri.parse('${baseUrl}api/v1/policy'),
      headers: await _getHeaders(),
      body: body,
    );

    // Lève une exception si la requête n'a pas réussi.
    if (response.statusCode != 200) {
      throw Exception(_handleError('sauvegarder la politique ACL', response));
    }
  }

  /// Supprime un utilisateur en utilisant son ID.
  Future<void> deleteUser(String userId) async {
    // Récupère l'URL de base du serveur.
    final baseUrl = await _getBaseUrl();
    // Effectue la requête DELETE pour supprimer l'utilisateur.
    final response = await http.delete(
      Uri.parse('${baseUrl}api/v1/user/$userId'),
      headers: await _getHeaders(),
    );

    // Lève une exception si la requête n'a pas réussi.
    if (response.statusCode != 200) {
      throw Exception(_handleError('supprimer l\'utilisateur', response));
    }
  }

  /// Supprime un nœud en utilisant son ID.
  Future<void> deleteNode(String nodeId) async {
    // Récupère l'URL de base du serveur.
    final baseUrl = await _getBaseUrl();
    // Effectue la requête DELETE pour supprimer le nœud.
    final response = await http.delete(
      Uri.parse('${baseUrl}api/v1/node/$nodeId'),
      headers: await _getHeaders(),
    );

    // Lève une exception si la requête n'a pas réussi.
    if (response.statusCode != 200) {
      throw Exception(_handleError('supprimer le nœud', response));
    }
  }

  /// Définit les routes pour un nœud (pour la fonctionnalité de nœud de sortie).
  Future<void> setNodeRoutes(String nodeId, List<String> routes) async {
    // Récupère l'URL de base du serveur.
    final baseUrl = await _getBaseUrl();
    // Effectue la requête POST pour approuver les routes du nœud.
    final response = await http.post(
      Uri.parse('${baseUrl}api/v1/node/$nodeId/approve_routes'),
      headers: await _getHeaders(),
      body: jsonEncode(<String, dynamic>{'routes': routes}),
    );

    // Lève une exception si la requête n'a pas réussi.
    if (response.statusCode != 200) {
      throw Exception(_handleError('définir les routes du nœud', response));
    }
  }

  /// Renomme un nœud avec un nouveau nom.
  Future<void> renameNode(String nodeId, String newName) async {
    // Récupère l'URL de base du serveur.
    final baseUrl = await _getBaseUrl();
    // Effectue la requête POST pour renommer le nœud.
    final response = await http.post(
      Uri.parse('${baseUrl}api/v1/node/$nodeId/rename/$newName'),
      headers: await _getHeaders(),
    );

    // Lève une exception si la requête n'a pas réussi.
    if (response.statusCode != 200) {
      throw Exception(_handleError('renommer le nœud', response));
    }
  }

  /// Déplace un nœud vers un utilisateur différent et met à jour ses tags.
  Future<void> moveNode(String nodeId, String newUserId) async {
    print('Déplacement du nœud $nodeId vers l\'utilisateur $newUserId');
    final baseUrl = await _getBaseUrl();

    // 1. Récupérer le nœud avant le déplacement pour obtenir ses tags actuels et son nom.
    final oldNode = await getNodeDetails(nodeId);
    final oldNodeName = oldNode.name;
    final oldTags = List<String>.from(oldNode.tags); // Copie pour modification

    // 2. Effectuer le déplacement du nœud.
    final response = await http.post(
      Uri.parse('${baseUrl}api/v1/node/$nodeId/user'),
      headers: await _getHeaders(),
      body: jsonEncode(<String, String>{'user': newUserId}),
    );

    if (response.statusCode != 200) {
      print('Échec du déplacement du nœud. Statut: ${response.statusCode}, Corps: ${response.body}');
      throw Exception(_handleError('déplacer le nœud', response));
    }
    print('Nœud déplacé avec succès.');

    // 3. Récupérer le nœud après le déplacement pour obtenir son nouveau nom (si Headscale le change)
    // et les tags potentiellement mis à jour par Headscale.
    final newNode = await getNodeDetails(nodeId);
    final newNodeName = newNode.name;
    List<String> updatedTags = List<String>.from(newNode.tags);

    // 4. Mettre à jour les tags :
    // Supprimer l'ancien tag obligatoire et ajouter le nouveau.
    final oldMandatoryTag = 'tag:$oldNodeName';
    final newMandatoryTag = 'tag:$newNodeName';

    // Supprimer l'ancien tag s'il existe
    updatedTags.removeWhere((tag) => tag == oldMandatoryTag);

    // Ajouter le nouveau tag s'il n'est pas déjà présent
    if (!updatedTags.contains(newMandatoryTag)) {
      updatedTags.add(newMandatoryTag);
    }

    // Appeler setTags pour mettre à jour les tags du nœud.
    await setTags(nodeId, updatedTags);
    print('Tags du nœud mis à jour avec succès après le déplacement.');
  }


  /// Récupère toutes les clés de pré-authentification.
  Future<List<PreAuthKey>> getPreAuthKeys() async {
    final baseUrl = await _getBaseUrl();
    final List<PreAuthKey> allPreAuthKeys = [];

    // First, get all users
    final users = await getUsers();

    // Then, for each user, get their pre-auth keys
    for (final user in users) {
      final response = await http.get(
        Uri.parse('${baseUrl}api/v1/preauthkey?user=${user.id}'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> keysJson = data['preAuthKeys'];
        allPreAuthKeys.addAll(keysJson.map((json) => PreAuthKey.fromJson(json)).toList());
      } else {
        // Log the error but continue with other users
        print(_handleError('charger les clés de pré-authentification pour l\'utilisateur ${user.name}', response));
      }
    }

    return allPreAuthKeys;
  }

  /// Fait expirer une clé de pré-authentification.
  Future<void> expirePreAuthKey(String userId, String key) async {
    final baseUrl = await _getBaseUrl();
    final response = await http.post(
      Uri.parse('${baseUrl}api/v1/preauthkey/expire'),
      headers: await _getHeaders(),
      body: jsonEncode(<String, String>{
        'user': userId,
        'key': key,
      }),
    );
    print('Expire PreAuthKey Status Code: ${response.statusCode}');
    if (response.statusCode != 200) {
      print('Erreur lors de l\'expiration de la clé: ${response.body}');
      throw Exception(_handleError('expirer la clé de pré-authentification', response));
    }
  }

  /// Récupère toutes les clés d'API.
  Future<List<ApiKey>> listApiKeys() async {
    final baseUrl = await _getBaseUrl();
    final response = await http.get(
      Uri.parse('${baseUrl}api/v1/apikey'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> apiKeysJson = data['apiKeys'];
      return apiKeysJson.map((json) => ApiKey.fromJson(json)).toList();
    } else {
      throw Exception(_handleError('lister les clés API', response));
    }
  }

  /// Crée une nouvelle clé d'API.
  /// Permet de spécifier une date d'expiration pour la clé.
  Future<String> createApiKey({DateTime? expiration}) async {
    final baseUrl = await _getBaseUrl();
    final body = <String, dynamic>{};
    if (expiration != null) {
      body['expiration'] = expiration.toUtc().toIso8601String();
    }

    final response = await http.post(
      Uri.parse('${baseUrl}api/v1/apikey'),
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['apiKey'];
    } else {
      throw Exception(_handleError('créer la clé API', response));
    }
  }

  /// Fait expirer une clé d'API.
  Future<void> expireApiKey(String prefix) async {
    final baseUrl = await _getBaseUrl();
    final response = await http.post(
      Uri.parse('${baseUrl}api/v1/apikey/expire'),
      headers: await _getHeaders(),
      body: jsonEncode(<String, String>{'prefix': prefix}),
    );

    if (response.statusCode != 200) {
      throw Exception(_handleError('expirer la clé API', response));
    }
  }

  /// Supprime une clé d'API.
  Future<void> deleteApiKey(String prefix) async {
    final baseUrl = await _getBaseUrl();
    final response = await http.delete(
      Uri.parse('${baseUrl}api/v1/apikey/$prefix'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(_handleError('supprimer la clé API', response));
    }
  }

  /// Définit les tags pour un nœud.
  Future<Node> setTags(String nodeId, List<String> tags) async {
    final baseUrl = await _getBaseUrl();
    final serverUrl = await _storageService.getServerUrl();
    final String baseDomain = serverUrl?.extractBaseDomain() ?? 'headscale.local';

    final response = await http.post(
      Uri.parse('${baseUrl}api/v1/node/$nodeId/tags'),
      headers: await _getHeaders(),
      body: jsonEncode(<String, dynamic>{'tags': tags}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Node.fromJson(data['node'], baseDomain);
    } else {
      throw Exception(_handleError('définir les tags', response));
    }
  }



  
}

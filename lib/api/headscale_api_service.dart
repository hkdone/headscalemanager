import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/models/pre_auth_key.dart';
import 'package:headscalemanager/services/storage_service.dart';

class HeadscaleApiService {
  final StorageService _storageService = StorageService();

  Future<Map<String, String>> _getHeaders() async {
    final apiKey = await _storageService.getApiKey();
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
  }

  Future<String> _getBaseUrl() async {
    final url = await _storageService.getServerUrl();
    if (url == null) {
      throw Exception('Server URL is not configured');
    }
    // Ensure the URL ends with a slash
    return url.endsWith('/') ? url : '$url/';
  }

  String _handleError(String functionName, http.Response response) {
    return 'Failed to $functionName. Status: ${response.statusCode}, Body: ${response.body}';
  }

  // Get all nodes (now fetches full details for each)
  Future<List<Node>> getNodes() async {
    final baseUrl = await _getBaseUrl();
    final response = await http.get(
      Uri.parse('${baseUrl}api/v1/node'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> nodesJson = data['nodes'];

      // Fetch full details for each node
      final List<Node> detailedNodes = [];
      for (var nodeJson in nodesJson) {
        // The basic nodeJson from the list might not have all fields,
        // so we only extract the ID and then fetch full details.
        final nodeId = nodeJson['id'];
        if (nodeId != null) {
          try {
            final detailedNode = await getNodeDetails(nodeId);
            detailedNodes.add(detailedNode);
          } catch (e) {
            print('Error fetching details for node $nodeId: $e');
            // Optionally, add a placeholder node or skip
          }
        }
      }
      return detailedNodes;
    } else {
      throw Exception(_handleError('load nodes', response));
    }
  }

  // Get details for a single node
  Future<Node> getNodeDetails(String nodeId) async {
    final baseUrl = await _getBaseUrl();
    final response = await http.get(
      Uri.parse('${baseUrl}api/v1/node/$nodeId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Node.fromJson(data['node']); // Assuming 'node' is the key for the single node object
    } else {
      throw Exception(_handleError('load node details', response));
    }
  }

  // Register a machine for a user using the machine key
  Future<void> registerMachine(String machineKey, String userName) async {
    final baseUrl = await _getBaseUrl();
    final response = await http.post(
      Uri.parse('${baseUrl}api/v1/machine/$machineKey/register'),
      headers: await _getHeaders(),
      body: jsonEncode(<String, String>{'user': userName}),
    );

    if (response.statusCode != 200) {
      throw Exception(_handleError('register machine', response));
    }
  }

  // Get all users
  Future<List<User>> getUsers() async {
    final baseUrl = await _getBaseUrl();
    final response = await http.get(
      Uri.parse('${baseUrl}api/v1/user'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> usersJson = data['users'];
      return usersJson.map((json) => User.fromJson(json)).toList();
    } else {
      throw Exception(_handleError('load users', response));
    }
  }

  // Create a user
  Future<User> createUser(String name) async {
    final baseUrl = await _getBaseUrl();
    final response = await http.post(
      Uri.parse('${baseUrl}api/v1/user'),
      headers: await _getHeaders(),
      body: jsonEncode(<String, String>{'name': name}),
    );

    if (response.statusCode == 200) {
      return User.fromJson(json.decode(response.body));
    } else {
      throw Exception(_handleError('create user', response));
    }
  }

  // Create a pre-authenticated key
  Future<PreAuthKey> createPreAuthKey(String userId, bool reusable, bool ephemeral, {DateTime? expiration}) async {
    final baseUrl = await _getBaseUrl();
    final body = {
      'user': userId,
      'reusable': reusable,
      'ephemeral': ephemeral,
    };

    if (expiration != null) {
      body['expiration'] = expiration.toUtc().toIso8601String();
    }

    final response = await http.post(
      Uri.parse('${baseUrl}api/v1/preauthkey'),
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return PreAuthKey.fromJson(json.decode(response.body));
    } else {
      throw Exception(_handleError('create pre-auth key', response));
    }
  }

  // Get ACL policy
  Future<String> getAclPolicy() async {
    final baseUrl = await _getBaseUrl();
    final response = await http.get(
      Uri.parse('${baseUrl}api/v1/acl'),
      headers: await _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['acl']; // Assuming the policy is returned in a simple string
    } else {
      throw Exception(_handleError('load ACL policy', response));
    }
  }

  // Set ACL policy
  Future<void> setAclPolicy(Map<dynamic, dynamic> aclMap) async {
    final baseUrl = await _getBaseUrl();
    final response = await http.post(
      Uri.parse('${baseUrl}api/v1/acl'),
      headers: await _getHeaders(),
      body: jsonEncode(aclMap),
    );

    if (response.statusCode != 200) {
      throw Exception(_handleError('save ACL policy', response));
    }
  }

  // Delete a user
  Future<void> deleteUser(String userId) async {
    final baseUrl = await _getBaseUrl();
    final response = await http.delete(
      Uri.parse('${baseUrl}api/v1/user/$userId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(_handleError('delete user', response));
    }
  }

  // Delete a node
  Future<void> deleteNode(String nodeId) async {
    final baseUrl = await _getBaseUrl();
    final response = await http.delete(
      Uri.parse('${baseUrl}api/v1/node/$nodeId'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(_handleError('delete node', response));
    }
  }

  // Set routes for a node (for exit node functionality)
  Future<void> setNodeRoutes(String nodeId, List<String> routes) async {
    final baseUrl = await _getBaseUrl();
    final response = await http.post(
      Uri.parse('${baseUrl}api/v1/node/$nodeId/approve_routes'),
      headers: await _getHeaders(),
      body: jsonEncode(<String, dynamic>{'routes': routes}),
    );

    if (response.statusCode != 200) {
      throw Exception(_handleError('set node routes', response));
    }
  }

  // Rename a node
  Future<void> renameNode(String nodeId, String newName) async {
    final baseUrl = await _getBaseUrl();
    final response = await http.post(
      Uri.parse('${baseUrl}api/v1/node/$nodeId/rename/$newName'),
      headers: await _getHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(_handleError('rename node', response));
    }
  }

  // Move a node to a different user
  Future<void> moveNode(String nodeId, String userName) async {
    final baseUrl = await _getBaseUrl();
    final response = await http.post(
      Uri.parse('${baseUrl}api/v1/node/$nodeId/user'),
      headers: await _getHeaders(),
      body: jsonEncode(<String, String>{'user': userName}),
    );

    if (response.statusCode != 200) {
      throw Exception(_handleError('move node', response));
    }
  }

  // Set tags for a machine
  Future<void> setMachineTags(String machineId, List<String> tags) async {
    final baseUrl = await _getBaseUrl();
    // Headscale API endpoint: POST /api/v1/machine/{machineId}/tags
    // Body should be a JSON array of strings: e.g., ["tag:prod", "tag:db"]
    final response = await http.post(
      Uri.parse('${baseUrl}api/v1/machine/$machineId/tags'),
      headers: await _getHeaders(),
      body: jsonEncode(tags),
    );
    if (response.statusCode != 200) {
      throw Exception(_handleError('set machine tags', response));
    }
    // No specific return value needed, just confirmation of success or failure.
  }
}
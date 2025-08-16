import 'dart:convert';

class Node {
  final String id;
  final String machineKey;
  final String name;
  final String user;
  final List<String> ipAddresses;
  final bool online;
  final DateTime lastSeen;
  final List<String> advertisedRoutes; // New field
  final String fqdn;
  final List<String> tags; // Added tags field

  Node({
    required this.id,
    required this.machineKey,
    required this.name,
    required this.user,
    required this.ipAddresses,
    required this.online,
    required this.lastSeen,
    required this.advertisedRoutes,
    required this.fqdn,
    required this.tags, // Added tags to constructor
  });

  factory Node.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'] as Map<String, dynamic>?;

    return Node(
      id: json['id'] ?? '',
      machineKey: json['machineKey'] ?? '',
      name: json['name'] ?? 'Unknown Node',
      user: userMap != null ? (userMap['name'] ?? 'N/A') : 'N/A',
      ipAddresses: List<String>.from(json['ipAddresses'] ?? []),
      online: json['online'] ?? false,
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'])
          : DateTime.now(),
      advertisedRoutes: List<String>.from(json['subnetRoutes'] ?? []),
      fqdn: json['fqdn'] ?? '',
      tags: List<String>.from(
          json['forcedTags'] ?? json['validTags'] ?? json['tags'] ??
              []), // Added tags from JSON
    );
  }

  String get givenName {
    // The name is often a hex string, let's try to parse it
    try {
      final decoded = utf8.decode(base64.decode(name));
      return decoded;
    } catch (e) {
      return name;
    }
  }
}
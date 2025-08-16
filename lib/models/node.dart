

class Node {
  final String id;
  final String machineKey;
  final String hostname; // Le nom de machine stable
  final String name; // Le nom modifiable par l'utilisateur (givenName)
  final String user;
  final List<String> ipAddresses;
  final bool online;
  final DateTime lastSeen;
  final List<String> advertisedRoutes;
  final List<String> tags;

  Node({
    required this.id,
    required this.machineKey,
    required this.hostname,
    required this.name,
    required this.user,
    required this.ipAddresses,
    required this.online,
    required this.lastSeen,
    required this.advertisedRoutes,
    required this.tags,
  });

  factory Node.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'] as Map<String, dynamic>?;
    
    // The editable name is from 'givenName' (camelCase), fallback to hostname if empty
    final givenName = json['givenName'] as String? ?? '';
    // The stable hostname is from 'name', fallback to 'Unknown Hostname'
    final hostname = json['name'] as String? ?? 'Unknown Hostname';

    return Node(
      id: json['id'] ?? '',
      machineKey: json['machineKey'] ?? '',
      hostname: hostname,
      name: givenName.isNotEmpty ? givenName : hostname, // Use givenName, fallback to hostname
      user: userMap != null ? (userMap['name'] ?? 'N/A') : 'N/A',
      ipAddresses: List<String>.from(json['ipAddresses'] ?? []),
      online: json['online'] ?? false,
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'])
          : DateTime.now(),
      advertisedRoutes: List<String>.from(json['subnetRoutes'] ?? []),
      tags: List<String>.from(
          json['forcedTags'] ?? json['validTags'] ?? json['tags'] ?? []),
    );
  }

  String get fqdn => '$name.nasfilecloud.synology.me';
}
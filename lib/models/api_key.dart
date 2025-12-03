class ApiKey {
  final String id;
  final String prefix;
  final DateTime? expiration;
  final DateTime? lastSeen;
  final DateTime createdAt;

  ApiKey({
    required this.id,
    required this.prefix,
    this.expiration,
    this.lastSeen,
    required this.createdAt,
  });

  factory ApiKey.fromJson(Map<String, dynamic> json) {
    return ApiKey(
      id: json['id'],
      prefix: json['prefix'],
      expiration: json['expiration'] != null && json['expiration'] is String
          ? DateTime.parse(json['expiration'])
          : null,
      lastSeen: json['lastSeen'] != null && json['lastSeen'] is String
          ? DateTime.parse(json['lastSeen'])
          : null,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

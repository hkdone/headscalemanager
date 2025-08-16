class PreAuthKey {
  final String user;
  final String key;
  final bool reusable;
  final bool ephemeral;
  final DateTime expiration;
  final DateTime createdAt;

  PreAuthKey({
    required this.user,
    required this.key,
    required this.reusable,
    required this.ephemeral,
    required this.expiration,
    required this.createdAt,
  });

  factory PreAuthKey.fromJson(Map<String, dynamic> json) {
    // Directly use the json map as the keyData
    // No need to check for 'preAuthKey' key here, as the map itself is the PreAuthKey data
    final keyData = json;

    DateTime parsedExpiration;
    try {
      parsedExpiration = keyData['expiration'] != null && keyData['expiration'].isNotEmpty
          ? DateTime.parse(keyData['expiration'])
          : DateTime.now().add(const Duration(days: 365 * 100)); // Default to 100 years in future if no expiration or invalid
    } catch (e) {
      // Handle parsing error, e.g., if expiration is an empty string or invalid format
      print('Error parsing expiration date: ${keyData['expiration']} - $e');
      parsedExpiration = DateTime.now().add(const Duration(days: 365 * 100)); // Default to a very distant future
    }

    DateTime parsedCreatedAt;
    try {
      parsedCreatedAt = keyData['createdAt'] != null && keyData['createdAt'].isNotEmpty
          ? DateTime.parse(keyData['createdAt'])
          : DateTime.now();
    } catch (e) {
      print('Error parsing creation date: ${keyData['createdAt']} - $e');
      parsedCreatedAt = DateTime.now();
    }


    return PreAuthKey(
      user: keyData['user']?['name'] ?? 'Unknown User',
      key: keyData['key'] ?? '',
      reusable: keyData['reusable'] ?? false,
      ephemeral: keyData['ephemeral'] ?? false,
      expiration: parsedExpiration,
      createdAt: parsedCreatedAt,
    );
  }
}
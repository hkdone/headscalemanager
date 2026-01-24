import 'package:headscalemanager/models/user.dart';

class PreAuthKey {
  /// L'utilisateur Headscale auquel cette clé de pré-authentification est associée.
  final User? user;

  /// Identifiant unique de la clé (v0.28+). Null pour les versions antérieures.
  final String? id;

  /// La clé de pré-authentification elle-même.
  final String key;

  /// Indique si cette clé peut être utilisée plusieurs fois.
  final bool reusable;

  /// Indique si cette clé est éphémère (utilisée une seule fois et supprimée).
  final bool ephemeral;

  /// Liste des tags ACL associés à cette clé (v0.28+).
  final List<String> aclTags;

  /// Indique si cette clé a été utilisée.
  final bool used;

  /// La date et l'heure d'expiration de cette clé.
  final DateTime? expiration;

  /// La date et l'heure de création de cette clé.
  final DateTime? createdAt;

  /// Constructeur de la classe PreAuthKey.
  PreAuthKey({
    this.id,
    this.user,
    required this.key,
    this.aclTags = const [],
    required this.reusable,
    required this.ephemeral,
    required this.used,
    this.expiration,
    this.createdAt,
  });

  /// Constructeur d'usine (factory constructor) pour créer une instance de PreAuthKey à partir d'un Map JSON.
  factory PreAuthKey.fromJson(Map<String, dynamic> json) {
    return PreAuthKey(
      id: json['id']?.toString(), // v0.28+
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      aclTags: List<String>.from(json['aclTags'] ?? []),
      key: json['key'] ?? '',
      reusable: json['reusable'] ?? false,
      ephemeral: json['ephemeral'] ?? false,
      used: json['used'] ?? false,
      expiration: json['expiration'] != null && json['expiration'] is String
          ? DateTime.parse(json['expiration'])
          : null,
      createdAt: json['createdAt'] != null && json['createdAt'] is String
          ? DateTime.parse(json['createdAt'])
          : null,
    );
  }
}

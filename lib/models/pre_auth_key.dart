import 'package:headscalemanager/models/user.dart';

class PreAuthKey {
  /// L'utilisateur Headscale auquel cette clé de pré-authentification est associée.
  final User? user;

  /// La clé de pré-authentification elle-même.
  final String key;

  /// Indique si cette clé peut être utilisée plusieurs fois.
  final bool reusable;

  /// Indique si cette clé est éphémère (utilisée une seule fois et supprimée).
  final bool ephemeral;

  /// Indique si cette clé a été utilisée.
  final bool used;

  /// La date et l'heure d'expiration de cette clé.
  final DateTime? expiration;

  /// La date et l'heure de création de cette clé.
  final DateTime? createdAt;

  /// Constructeur de la classe PreAuthKey.
  PreAuthKey({
    this.user,
    required this.key,
    required this.reusable,
    required this.ephemeral,
    required this.used,
    this.expiration,
    this.createdAt,
  });

  /// Constructeur d'usine (factory constructor) pour créer une instance de PreAuthKey à partir d'un Map JSON.
  factory PreAuthKey.fromJson(Map<String, dynamic> json) {
    return PreAuthKey(
      user: json['user'] != null ? User.fromJson(json['user']) : null,
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
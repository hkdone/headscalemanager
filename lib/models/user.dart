class User {
  /// Identifiant unique de l'utilisateur.
  final String id;

  /// Nom de l'utilisateur.
  final String name;

  /// Date et heure de création de l'utilisateur.
  final DateTime? createdAt;

  /// Email de l'utilisateur (OIDC).
  final String? email;

  /// Nom d'affichage (OIDC).
  final String? displayName;

  /// Fournisseur d'identité (ex: 'google', 'github' ou vide pour CLI/Manual).
  final String? provider;

  /// URL de l'avatar (OIDC).
  final String? profilePicUrl;

  /// Constructeur de la classe User.
  ///
  /// Tous les champs sont requis pour la création d'une instance de User.
  User({
    required this.id,
    required this.name,
    this.createdAt,
    this.email,
    this.displayName,
    this.provider,
    this.profilePicUrl,
  });

  /// Constructeur d'usine (factory constructor) pour créer une instance de User à partir d'un Map JSON.
  ///
  /// Cette méthode gère la désérialisation des données JSON en un objet User.
  factory User.fromJson(Map<String, dynamic> json) {
    final rawName = json['name'] as String?;
    final rawEmail = json['email'] as String?;
    final rawDisplayName = json['displayName'] as String?;
    // Headscale OIDC peut créer un utilisateur avec name="" — on utilise
    // l'email puis le displayName comme fallback pour éviter les ACLs invalides (group:)
    final resolvedName = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : (rawEmail != null && rawEmail.isNotEmpty)
            ? rawEmail
            : (rawDisplayName != null && rawDisplayName.isNotEmpty)
                ? rawDisplayName
                : 'Unknown User';
    return User(
      id: json['id'] ?? '',
      name: resolvedName,
      createdAt: json['createdAt'] != null && json['createdAt'] is String
          ? DateTime.parse(json['createdAt'])
          : null,
      email: rawEmail,
      displayName: rawDisplayName,
      provider: json['provider'] as String?,
      profilePicUrl: json['profilePicUrl'] as String?,
    );
  }

  /// Surcharge de l'opérateur d'égalité (==).
  ///
  /// Deux objets User sont considérés comme égaux si leur 'id' est identique.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && runtimeType == other.runtimeType && id == other.id;

  /// Surcharge du getter hashCode.
  ///
  /// Le code de hachage est basé sur l'id de l'utilisateur, ce qui est essentiel
  /// pour le bon fonctionnement des collections (Set, Map) qui utilisent le hachage.
  @override
  int get hashCode => id.hashCode;
}

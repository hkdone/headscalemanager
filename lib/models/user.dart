class User {
  /// Identifiant unique de l'utilisateur.
  final String id;

  /// Nom de l'utilisateur.
  final String name;

  /// Date et heure de création de l'utilisateur.
  final DateTime? createdAt;

  /// Constructeur de la classe User.
  ///
  /// Tous les champs sont requis pour la création d'une instance de User.
  User({
    required this.id,
    required this.name,
    this.createdAt,
  });

  /// Constructeur d'usine (factory constructor) pour créer une instance de User à partir d'un Map JSON.
  ///
  /// Cette méthode gère la désérialisation des données JSON en un objet User,
  /// en assurant la gestion des valeurs par défaut et le parsing de la date de création.
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      // L'ID de l'utilisateur, avec un fallback à une chaîne vide.
      id: json['id'] ?? '',
      // Le nom de l'utilisateur, avec un fallback à 'Unknown User'.
      name: json['name'] ?? 'Unknown User',
      // Date de création de l'utilisateur. Si 'createdAt' est nul, utilise la date et l'heure actuelles.
      // ATTENTION : Utiliser DateTime.now() comme fallback peut être trompeur car cela suggère
      // que l'utilisateur vient d'être créé, alors que l'information était absente.
      createdAt: json['createdAt'] != null && json['createdAt'] is String
          ? DateTime.parse(json['createdAt'])
          : null,
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

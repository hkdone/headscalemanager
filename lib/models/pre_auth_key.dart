class PreAuthKey {
  /// L'utilisateur Headscale auquel cette clé de pré-authentification est associée.
  final String user;

  /// La clé de pré-authentification elle-même.
  final String key;

  /// Indique si cette clé peut être utilisée plusieurs fois.
  final bool reusable;

  /// Indique si cette clé est éphémère (utilisée une seule fois et supprimée).
  final bool ephemeral;

  /// La date et l'heure d'expiration de cette clé.
  final DateTime expiration;

  /// La date et l'heure de création de cette clé.
  final DateTime createdAt;

  /// Constructeur de la classe PreAuthKey.
  ///
  /// Tous les champs sont requis pour la création d'une instance de PreAuthKey.
  PreAuthKey({
    required this.user,
    required this.key,
    required this.reusable,
    required this.ephemeral,
    required this.expiration,
    required this.createdAt,
  });

  /// Constructeur d'usine (factory constructor) pour créer une instance de PreAuthKey à partir d'un Map JSON.
  ///
  /// Cette méthode gère la désérialisation des données JSON provenant de l'API Headscale
  /// en un objet PreAuthKey. Elle s'attend à ce que les données de la clé soient imbriquées
  /// sous la clé 'preAuthKey' dans le JSON d'entrée.
  factory PreAuthKey.fromJson(Map<String, dynamic> json) {
    // Extrait les données de la clé de pré-authentification, qui sont imbriquées sous 'preAuthKey'.
    final keyData = json['preAuthKey'] as Map<String, dynamic>?;
    // Lève une exception si les données de la clé ne sont pas trouvées.
    if (keyData == null) {
      throw Exception('L\'objet preAuthKey n\'a pas été trouvé dans la réponse de l\'API.');
    }

    // Tente d'analyser la date d'expiration.
    DateTime parsedExpiration;
    try {
      // Si 'expiration' est présent et non vide, l'analyse.
      // Sinon, définit une date très lointaine (100 ans dans le futur) comme valeur par défaut,
      // ce qui peut indiquer que la clé n'expire pas.
      // ATTENTION : Utiliser une date très lointaine comme "jamais expire" est une convention.
      // Si l'API peut renvoyer null pour "jamais expire", il serait plus précis de rendre
      // le champ 'expiration' nullable (DateTime?) dans la classe.
      parsedExpiration = keyData['expiration'] != null && keyData['expiration'].isNotEmpty
          ? DateTime.parse(keyData['expiration'])
          : DateTime.now().add(const Duration(days: 365 * 100)); // Valeur par défaut : 100 ans dans le futur
    } catch (e) {
      // Gère les erreurs de parsing (par exemple, si 'expiration' est une chaîne vide ou un format invalide).
      // Affiche l'erreur et utilise la valeur par défaut.
      // NOTE : Dans une application de production, il serait préférable d'utiliser un système de logging
      // plutôt que 'print' pour les erreurs.
      print('Erreur lors de l\'analyse de la date d\'expiration : ${keyData['expiration']} - $e');
      parsedExpiration = DateTime.now().add(const Duration(days: 365 * 100)); // Valeur par défaut en cas d'erreur
    }

    // Tente d'analyser la date de création.
    DateTime parsedCreatedAt;
    try {
      // Si 'createdAt' est présent et non vide, l'analyse.
      // Sinon, utilise la date et l'heure actuelles comme valeur par défaut.
      parsedCreatedAt = keyData['createdAt'] != null && keyData['createdAt'].isNotEmpty
          ? DateTime.parse(keyData['createdAt'])
          : DateTime.now();
    } catch (e) {
      // Gère les erreurs de parsing.
      // NOTE : Dans une application de production, il serait préférable d'utiliser un système de logging.
      print('Erreur lors de l\'analyse de la date de création : ${keyData['createdAt']} - $e');
      parsedCreatedAt = DateTime.now(); // Valeur par défaut en cas d'erreur
    }

    return PreAuthKey(
      // Nom de l'utilisateur associé à la clé, avec un fallback à 'Unknown User'.
      user: keyData['user']?['name'] ?? 'Unknown User',
      // La clé elle-même, avec un fallback à une chaîne vide.
      key: keyData['key'] ?? '',
      // Indique si la clé est réutilisable, avec un fallback à false.
      reusable: keyData['reusable'] ?? false,
      // Indique si la clé est éphémère, avec un fallback à false.
      ephemeral: keyData['ephemeral'] ?? false,
      // La date d'expiration analysée ou par défaut.
      expiration: parsedExpiration,
      // La date de création analysée ou par défaut.
      createdAt: parsedCreatedAt,
    );
  }
}
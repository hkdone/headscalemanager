class Node {
  /// Identifiant unique du nœud.
  final String id;

  /// Clé machine unique associée à ce nœud.
  final String machineKey;

  /// Nom d'hôte stable du nœud, tel que rapporté par la machine.
  final String hostname;

  /// Nom modifiable du nœud, tel que défini par l'utilisateur (givenName dans l'API Headscale).
  final String name;

  /// Nom de l'utilisateur Headscale auquel ce nœud est associé.
  final String user;

  /// Liste des adresses IP assignées à ce nœud.
  final List<String> ipAddresses;

  /// Statut en ligne du nœud (true si en ligne, false sinon).
  final bool online;

  /// Date et heure de la dernière fois que le nœud a été vu en ligne.
  final DateTime lastSeen;

  /// Liste des routes réseau annoncées par ce nœud.
  final List<String> advertisedRoutes;

  /// Liste des tags associés à ce nœud.
  final List<String> tags;

  /// Constructeur de la classe Node.
  ///
  /// Tous les champs sont requis pour la création d'une instance de Node.
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

  /// Constructeur d'usine (factory constructor) pour créer une instance de Node à partir d'un Map JSON.
  ///
  /// Cette méthode gère la désérialisation des données JSON provenant de l'API Headscale
  /// en un objet Node, en assurant la gestion des valeurs par défaut et des mappings spécifiques.
  factory Node.fromJson(Map<String, dynamic> json) {
    // Extrait les informations de l'utilisateur, qui peuvent être imbriquées.
    final userMap = json['user'] as Map<String, dynamic>?;

    // Le nom modifiable (givenName) est extrait de 'givenName' (camelCase dans l'API),
    // avec un fallback à une chaîne vide si non présent.
    final givenName = json['givenName'] as String? ?? '';
    // Le nom d'hôte stable est extrait de 'name' dans l'API,
    // avec un fallback à 'Unknown Hostname' si non présent.
    final hostname = json['name'] as String? ?? 'Unknown Hostname';

    return Node(
      // L'ID du nœud, avec un fallback à une chaîne vide.
      id: json['id'] ?? '',
      // La clé machine du nœud, avec un fallback à une chaîne vide.
      machineKey: json['machineKey'] ?? '',
      // Le nom d'hôte stable.
      hostname: hostname,
      // Le nom affichable du nœud : utilise 'givenName' s'il est présent, sinon utilise 'hostname'.
      name: givenName.isNotEmpty ? givenName : hostname,
      // Le nom de l'utilisateur associé au nœud, avec un fallback à 'N/A'.
      user: userMap != null ? (userMap['name'] ?? 'N/A') : 'N/A',
      // Liste des adresses IP, convertie à partir d'une liste dynamique, avec un fallback à une liste vide.
      ipAddresses: List<String>.from(json['ipAddresses'] ?? []),
      // Statut en ligne du nœud, avec un fallback à false.
      online: json['online'] ?? false,
      // Date de la dernière connexion. Si 'lastSeen' est nul, utilise la date et l'heure actuelles.
      // ATTENTION : Utiliser DateTime.now() comme fallback peut être trompeur car cela suggère
      // que le nœud vient d'être vu, alors que l'information était absente.
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'])
          : DateTime.now(),
      // Routes annoncées, mappées depuis 'subnetRoutes', avec un fallback à une liste vide.
      advertisedRoutes: List<String>.from(json['subnetRoutes'] ?? []),
      // Tags du nœud, avec une priorité sur 'forcedTags', puis 'validTags', puis 'tags',
      // avec un fallback à une liste vide.
      tags: List<String>.from(
          json['forcedTags'] ?? json['validTags'] ?? json['tags'] ?? []),
    );
  }

  /// Getter pour le Fully Qualified Domain Name (FQDN) du nœud.
  ///
  /// Construit le FQDN en utilisant le nom du nœud et un domaine codé en dur.
  /// ATTENTION : Le domaine 'nasfilecloud.synology.me' est codé en dur.
  /// Il est recommandé de rendre ce domaine configurable si l'application
  /// doit être déployée dans différents environnements.
  String get fqdn => '$name.nasfilecloud.synology.me';
}
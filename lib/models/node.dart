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

  /// Liste des routes réseau partagées par ce nœud (correspond à approvedRoutes de l'API).
  final List<String> sharedRoutes;
  /// Indique si ce nœud est un nœud de sortie (basé sur la présence de 0.0.0.0/0 ou ::/0 dans availableRoutes).
  final bool isExitNode;

  /// Liste des tags associés à ce nœud.
  final List<String> tags;

  /// Le domaine de base du serveur Headscale, utilisé pour construire le FQDN.
  final String baseDomain;

  /// L'endpoint public du nœud (IP:port).
  final String endpoint;

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
    required this.sharedRoutes,
    required this.isExitNode,
    required this.tags,
    required this.baseDomain,
    required this.endpoint,
  });

  /// Constructeur d'usine (factory constructor) pour créer une instance de Node à partir d'un Map JSON.
  ///
  /// Cette méthode gère la désérialisation des données JSON provenant de l'API Headscale
  /// en un objet Node, en assurant la gestion des valeurs par défaut et des mappings spécifiques.
  /// Le [baseDomain] est nécessaire pour construire le FQDN du nœud.
  factory Node.fromJson(Map<String, dynamic> json, String baseDomain) {
    // Ajout de baseDomain
    // Extrait les informations de l'utilisateur, qui peuvent être imbriquées.
    final userMap = json['user'] as Map<String, dynamic>?;

    // Le nom modifiable (givenName) est extrait de 'givenName' (camelCase dans l'API),
    // avec un fallback à une chaîne vide si non présent.
    final givenName = json['givenName'] as String? ?? '';
    // Le nom d'hôte stable est extrait de 'name' dans l'API,
    // avec un fallback à 'Unknown Hostname' si non présent.
    final hostname = json['name'] as String? ?? 'Unknown Hostname';

    final List<String> availableRoutes = List<String>.from(json['availableRoutes'] ?? []);
    final bool isExitNode = availableRoutes.contains('0.0.0.0/0') || availableRoutes.contains('::/0');

    return Node(
      id: json['id'] ?? '',
      machineKey: json['machineKey'] ?? '',
      hostname: hostname,
      name: givenName.isNotEmpty ? givenName : hostname,
      user: userMap != null ? (userMap['name'] ?? 'N/A') : 'N/A',
      ipAddresses: List<String>.from(json['ipAddresses'] ?? []),
      online: json['online'] ?? false,
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'])
          : DateTime.now(),
      sharedRoutes: List<String>.from(json['approvedRoutes'] ?? []),
      isExitNode: isExitNode,
      tags: List<String>.from(
          json['forcedTags'] ?? json['validTags'] ?? json['tags'] ?? []),
      baseDomain: baseDomain,
      // L'endpoint public du nœud (IP:port). Peut être vide si le nœud est hors ligne
      // ou si l'information n'est pas disponible.
      endpoint: json['endpoint'] as String? ?? '',
    );
  }

  /// Getter pour le Fully Qualified Domain Name (FQDN) du nœud.
  ///
  /// Construit le FQDN en utilisant le nom du nœud et le domaine de base du serveur.
  String get fqdn => '$name.$baseDomain'; // Utilisation du nouveau champ

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Node && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

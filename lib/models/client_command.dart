import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/models/pre_auth_key.dart';

// Types de commandes
enum CommandType {
  static, // Commande statique
  dynamic, // Commande avec paramètres personnalisables
  serverBased, // Commande basée sur les données du serveur
  interactive, // Commande avec interface interactive
}

// Types de paramètres
enum ParameterType {
  text, // Texte libre
  ipAddress, // Adresse IP
  subnet, // Sous-réseau (CIDR)
  nodeSelect, // Sélection de nœud
  userSelect, // Sélection d'utilisateur
  authKeySelect, // Sélection de clé d'auth
  routeSelect, // Sélection de route
  boolean, // Booléen
  number, // Nombre
}

// Paramètre de commande
class CommandParameter {
  final String id;
  final String label;
  final String description;
  final ParameterType type;
  final bool required;
  final String? defaultValue;
  final List<String>? options;
  final String? placeholder;
  final String? validation;

  const CommandParameter({
    required this.id,
    required this.label,
    required this.description,
    required this.type,
    this.required = true,
    this.defaultValue,
    this.options,
    this.placeholder,
    this.validation,
  });

  factory CommandParameter.fromJson(Map<String, dynamic> json) {
    return CommandParameter(
      id: json['id'] as String,
      label: json['label'] as String,
      description: json['description'] as String,
      type: ParameterType.values.firstWhere(
        (t) => t.toString() == 'ParameterType.${json['type']}',
        orElse: () => ParameterType.text,
      ),
      required: json['required'] as bool? ?? true,
      defaultValue: json['defaultValue'] as String?,
      options:
          json['options'] != null ? List<String>.from(json['options']) : null,
      placeholder: json['placeholder'] as String?,
      validation: json['validation'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'description': description,
      'type': type.toString().split('.').last,
      'required': required,
      'defaultValue': defaultValue,
      'options': options,
      'placeholder': placeholder,
      'validation': validation,
    };
  }
}

class ClientCommand {
  final String id;
  final String title;
  final String description;
  final String windowsCommand;
  final String linuxCommand;
  final String category;
  final List<String> tags;
  final bool requiresElevation;
  final String? notes;
  final CommandType type;
  final List<CommandParameter>? parameters;
  final bool isDynamic;

  const ClientCommand({
    required this.id,
    required this.title,
    required this.description,
    required this.windowsCommand,
    required this.linuxCommand,
    required this.category,
    required this.tags,
    this.requiresElevation = false,
    this.notes,
    this.type = CommandType.static,
    this.parameters,
    this.isDynamic = false,
  });

  factory ClientCommand.fromJson(Map<String, dynamic> json) {
    return ClientCommand(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      windowsCommand: json['windowsCommand'] as String,
      linuxCommand: json['linuxCommand'] as String,
      category: json['category'] as String,
      tags: List<String>.from(json['tags'] as List),
      requiresElevation: json['requiresElevation'] as bool? ?? false,
      notes: json['notes'] as String?,
      type: CommandType.values.firstWhere(
        (t) => t.toString() == 'CommandType.${json['type'] ?? 'static'}',
        orElse: () => CommandType.static,
      ),
      parameters: json['parameters'] != null
          ? (json['parameters'] as List)
              .map((p) => CommandParameter.fromJson(p))
              .toList()
          : null,
      isDynamic: json['isDynamic'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'windowsCommand': windowsCommand,
      'linuxCommand': linuxCommand,
      'category': category,
      'tags': tags,
      'requiresElevation': requiresElevation,
      'notes': notes,
      'type': type.toString().split('.').last,
      'parameters': parameters?.map((p) => p.toJson()).toList(),
      'isDynamic': isDynamic,
    };
  }

  String getCommandForPlatform(String platform) {
    switch (platform.toLowerCase()) {
      case 'windows':
        return windowsCommand;
      case 'linux':
        return linuxCommand;
      default:
        return windowsCommand;
    }
  }

  // Générer la commande avec les paramètres fournis
  String generateCommand(String platform, Map<String, String> parameterValues) {
    String command = getCommandForPlatform(platform);

    // Remplacer les placeholders par les valeurs
    parameterValues.forEach((key, value) {
      command = command.replaceAll('{$key}', value);
    });

    // Nettoyer les placeholders non remplis et les espaces en trop
    command = command
        .replaceAll(RegExp(r'\s?\{[a-zA-Z0-9_]+\}\s?'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return command;
  }
}

// Catégories prédéfinies
class CommandCategories {
  static const String connection = 'Connexion';
  static const String routing = 'Routage';
  static const String troubleshooting = 'Dépannage';
  static const String configuration = 'Configuration';
  static const String monitoring = 'Surveillance';
  static const String security = 'Sécurité';
  static const String maintenance = 'Maintenance';
  static const String serverSpecific = 'Spécifique Serveur';
}

// Générateur de commandes dynamiques
class DynamicCommandGenerator {
  // Générer des commandes basées sur le serveur actuel
  static List<ClientCommand> generateServerBasedCommands(String serverUrl) {
    return [
      // Connexion avec serveur personnalisé
      ClientCommand(
        id: 'connect_to_server',
        title: 'Connexion au serveur configuré',
        description:
            'Se connecter au serveur Headscale configuré dans l\'application',
        windowsCommand: 'tailscale up --login-server=$serverUrl',
        linuxCommand: 'sudo tailscale up --login-server=$serverUrl',
        category: CommandCategories.connection,
        tags: ['connexion', 'serveur', 'up'],
        type: CommandType.serverBased,
        isDynamic: false,
      ),

      // Connexion avec clé d'auth personnalisée
      ClientCommand(
        id: 'connect_with_custom_key',
        title: 'Connexion avec clé pré-authentifiée',
        description:
            'Se connecter avec une clé pré-authentifiée (à saisir manuellement)',
        windowsCommand:
            'tailscale up --login-server=$serverUrl --authkey={authkey}',
        linuxCommand:
            'sudo tailscale up --login-server=$serverUrl --authkey={authkey}',
        category: CommandCategories.connection,
        tags: ['connexion', 'authkey', 'up'],
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'authkey',
            label: 'Clé d\'authentification',
            description: 'Entrez votre clé pré-authentifiée',
            type: ParameterType.text,
            placeholder: 'nodekey-xxxxx ou tskey-xxxxx',
          ),
        ],
      ),
    ];
  }

  // Générer des commandes basées sur les nœuds existants
  static List<ClientCommand> generateNodeBasedCommands(List<Node> nodes) {
    List<ClientCommand> commands = [];

    // Commandes pour utiliser des nœuds de sortie existants
    final exitNodes = nodes.where((n) => n.isExitNode && n.online).toList();
    if (exitNodes.isNotEmpty) {
      commands.add(
        ClientCommand(
          id: 'use_specific_exit_node',
          title: 'Utiliser un nœud de sortie spécifique',
          description: 'Router le trafic via un nœud de sortie disponible',
          windowsCommand:
              'tailscale up --login-server={server_url} --exit-node={node_name}',
          linuxCommand:
              'sudo tailscale up --login-server={server_url} --exit-node={node_name}',
          category: CommandCategories.routing,
          tags: ['exit-node', 'routing', 'spécifique', 'serveur'],
          type: CommandType.dynamic,
          isDynamic: true,
          parameters: [
            CommandParameter(
              id: 'server_url',
              label: 'URL du serveur Headscale',
              description: 'URL de votre serveur Headscale',
              type: ParameterType.text,
              placeholder: 'https://headscale.example.com',
              required: true,
            ),
            CommandParameter(
              id: 'node_name',
              label: 'Nœud de sortie',
              description: 'Sélectionnez un nœud de sortie disponible',
              type: ParameterType.nodeSelect,
              options: exitNodes.map((n) => n.name).toList(),
            ),
          ],
        ),
      );
    }

    // Commandes pour ping vers des nœuds spécifiques
    if (nodes.isNotEmpty) {
      commands.add(
        ClientCommand(
          id: 'ping_specific_node',
          title: 'Ping vers un nœud spécifique',
          description: 'Tester la connectivité vers un nœud du réseau',
          windowsCommand: 'tailscale ping {node_ip}',
          linuxCommand: 'tailscale ping {node_ip}',
          category: CommandCategories.troubleshooting,
          tags: ['ping', 'test', 'spécifique'],
          type: CommandType.dynamic,
          isDynamic: true,
          parameters: [
            CommandParameter(
              id: 'node_ip',
              label: 'Nœud cible',
              description: 'Sélectionnez un nœud à tester',
              type: ParameterType.nodeSelect,
              options: nodes
                  .map((n) => n.ipAddresses.first.isNotEmpty
                      ? '${n.name} (${n.ipAddresses.first})'
                      : n.name)
                  .toList(),
            ),
          ],
        ),
      );
    }

    return commands;
  }

  // Générer des commandes basées sur les routes existantes
  static List<ClientCommand> generateRouteBasedCommands(List<Node> nodes) {
    List<ClientCommand> commands = [];

    // Collecter toutes les routes partagées
    final allRoutes = <String>{};
    for (var node in nodes) {
      allRoutes.addAll(node.sharedRoutes);
    }

    if (allRoutes.isNotEmpty) {
      // Commande pour annoncer des routes spécifiques
      commands.add(
        ClientCommand(
          id: 'advertise_specific_routes',
          title: 'Annoncer des routes spécifiques',
          description: 'Annoncer des routes de sous-réseau personnalisées',
          windowsCommand:
              'tailscale up --login-server={server_url} --advertise-routes={routes}',
          linuxCommand:
              'sudo tailscale up --login-server={server_url} --advertise-routes={routes}',
          category: CommandCategories.routing,
          tags: ['routes', 'subnet', 'personnalisé', 'serveur'],
          type: CommandType.dynamic,
          isDynamic: true,
          parameters: [
            CommandParameter(
              id: 'server_url',
              label: 'URL du serveur Headscale',
              description: 'URL de votre serveur Headscale',
              type: ParameterType.text,
              placeholder: 'https://headscale.example.com',
              required: true,
            ),
            CommandParameter(
              id: 'routes',
              label: 'Routes à annoncer',
              description:
                  'Entrez les routes séparées par des virgules (ex: 192.168.1.0/24,10.0.0.0/8)',
              type: ParameterType.text,
              placeholder: '192.168.1.0/24,10.0.0.0/8',
              validation:
                  r'^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,2})(,\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d{1,2})*$',
            ),
          ],
        ),
      );
    }

    return commands;
  }

  // Générer des commandes interactives
  static List<ClientCommand> generateInteractiveCommands() {
    return [
      // Configuration personnalisée complète
      ClientCommand(
        id: 'custom_setup',
        title: 'Configuration personnalisée',
        description: 'Configuration complète avec paramètres personnalisés',
        windowsCommand:
            'tailscale up --login-server={server_url} --hostname={hostname} {additional_params}',
        linuxCommand:
            'sudo tailscale up --login-server={server_url} --hostname={hostname} {additional_params}',
        category: CommandCategories.configuration,
        tags: ['configuration', 'personnalisé', 'complet'],
        type: CommandType.interactive,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: 'URL du serveur',
            description: 'URL de votre serveur Headscale',
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
          ),
          CommandParameter(
            id: 'hostname',
            label: 'Nom d\'hôte',
            description: 'Nom personnalisé pour ce nœud',
            type: ParameterType.text,
            placeholder: 'mon-ordinateur',
            required: false,
          ),
          CommandParameter(
            id: 'accept_routes',
            label: 'Accepter les routes',
            description: 'Accepter les routes annoncées par d\'autres nœuds',
            type: ParameterType.boolean,
            defaultValue: 'false',
          ),
          CommandParameter(
            id: 'advertise_exit_node',
            label: 'Devenir nœud de sortie',
            description: 'Configurer ce nœud comme point de sortie Internet',
            type: ParameterType.boolean,
            defaultValue: 'false',
          ),
          CommandParameter(
            id: 'enable_ssh',
            label: 'Activer SSH',
            description: 'Activer l\'accès SSH via Tailscale',
            type: ParameterType.boolean,
            defaultValue: 'false',
          ),
        ],
      ),

      // Commande de routage avancé
      ClientCommand(
        id: 'advanced_routing',
        title: 'Configuration de routage avancée',
        description: 'Configuration avancée des routes et du routage',
        windowsCommand:
            'tailscale up --login-server={server_url} --advertise-routes={routes} {exit_node_param} {accept_routes_param}',
        linuxCommand:
            'sudo tailscale up --login-server={server_url} --advertise-routes={routes} {exit_node_param} {accept_routes_param}',
        category: CommandCategories.routing,
        tags: ['routing', 'avancé', 'personnalisé', 'serveur'],
        type: CommandType.interactive,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: 'URL du serveur Headscale',
            description: 'URL de votre serveur Headscale',
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
          CommandParameter(
            id: 'routes',
            label: 'Routes à annoncer',
            description: 'Routes de sous-réseau à partager',
            type: ParameterType.text,
            placeholder: '192.168.1.0/24,10.0.0.0/8',
            required: false,
          ),
          CommandParameter(
            id: 'use_exit_node',
            label: 'Utiliser comme nœud de sortie',
            description: 'Configurer ce nœud pour router le trafic Internet',
            type: ParameterType.boolean,
            defaultValue: 'false',
          ),
          CommandParameter(
            id: 'accept_routes',
            label: 'Accepter les routes',
            description: 'Accepter les routes des autres nœuds',
            type: ParameterType.boolean,
            defaultValue: 'true',
          ),
        ],
      ),
    ];
  }

  // Générer toutes les commandes (statiques + dynamiques)
  static List<ClientCommand> generateAllCommands({
    String? serverUrl,
    List<Node>? nodes,
    List<PreAuthKey>? authKeys,
    List<User>? users,
  }) {
    List<ClientCommand> allCommands = [];

    // Commandes statiques de base
    allCommands.addAll(_getStaticCommands());

    // Commandes basées sur le serveur
    if (serverUrl != null) {
      allCommands.addAll(generateServerBasedCommands(serverUrl));
    }

    // Commandes basées sur les nœuds
    if (nodes != null && nodes.isNotEmpty) {
      allCommands.addAll(generateNodeBasedCommands(nodes));
      allCommands.addAll(generateRouteBasedCommands(nodes));
    }

    // Commandes interactives
    allCommands.addAll(generateInteractiveCommands());

    return allCommands;
  }

  // Commandes statiques de base
  static List<ClientCommand> _getStaticCommands() {
    return [
      // CONNEXION
      ClientCommand(
        id: 'connect_basic',
        title: 'Connexion simple',
        description:
            'Se connecter à Tailscale en spécifiant un serveur Headscale',
        windowsCommand: 'tailscale up --login-server={server_url}',
        linuxCommand: 'sudo tailscale up --login-server={server_url}',
        category: CommandCategories.connection,
        tags: ['connexion', 'up', 'simple', 'serveur'],
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: 'URL du serveur Headscale',
            description: 'Entrez l\'URL de votre serveur Headscale',
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
        ],
      ),

      ClientCommand(
        id: 'connect_with_authkey',
        title: 'Connexion avec clé d\'authentification',
        description:
            'Se connecter à un serveur Headscale avec une clé pré-authentifiée',
        windowsCommand:
            'tailscale up --login-server={server_url} --authkey={authkey}',
        linuxCommand:
            'sudo tailscale up --login-server={server_url} --authkey={authkey}',
        category: CommandCategories.connection,
        tags: ['connexion', 'up', 'authkey', 'serveur'],
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: 'URL du serveur Headscale',
            description: 'Entrez l\'URL de votre serveur Headscale',
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
          CommandParameter(
            id: 'authkey',
            label: 'Clé d\'authentification',
            description: 'Entrez votre clé pré-authentifiée',
            type: ParameterType.text,
            placeholder: 'nodekey-xxxxx ou tskey-xxxxx',
            required: true,
          ),
        ],
      ),

      ClientCommand(
        id: 'connect_with_routes',
        title: 'Connexion avec routes personnalisées',
        description: 'Se connecter en annonçant des routes spécifiques',
        windowsCommand:
            'tailscale up --login-server={server_url} --advertise-routes={routes}',
        linuxCommand:
            'sudo tailscale up --login-server={server_url} --advertise-routes={routes}',
        category: CommandCategories.connection,
        tags: ['connexion', 'up', 'routes', 'serveur'],
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: 'URL du serveur Headscale',
            description: 'Entrez l\'URL de votre serveur Headscale',
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
          CommandParameter(
            id: 'routes',
            label: 'Routes à annoncer',
            description: 'Entrez les routes séparées par des virgules',
            type: ParameterType.text,
            placeholder: '192.168.1.0/24,10.0.0.0/8',
            required: true,
          ),
        ],
      ),

      ClientCommand(
        id: 'disconnect',
        title: 'Déconnexion',
        description: 'Se déconnecter du réseau Headscale',
        windowsCommand: 'tailscale down',
        linuxCommand: 'sudo tailscale down',
        category: CommandCategories.connection,
        tags: ['déconnexion', 'down'],
      ),

      ClientCommand(
        id: 'logout',
        title: 'Déconnexion complète',
        description:
            'Se déconnecter et supprimer les informations d\'authentification',
        windowsCommand: 'tailscale logout',
        linuxCommand: 'sudo tailscale logout',
        category: CommandCategories.connection,
        tags: ['logout', 'reset'],
      ),

      // SURVEILLANCE
      ClientCommand(
        id: 'status',
        title: 'Statut de connexion',
        description: 'Afficher le statut actuel de Tailscale',
        windowsCommand: 'tailscale status',
        linuxCommand: 'tailscale status',
        category: CommandCategories.monitoring,
        tags: ['status', 'info'],
      ),

      ClientCommand(
        id: 'ip_info',
        title: 'Informations IP',
        description: 'Afficher l\'adresse IP Tailscale',
        windowsCommand: 'tailscale ip',
        linuxCommand: 'tailscale ip',
        category: CommandCategories.monitoring,
        tags: ['ip', 'address'],
      ),

      ClientCommand(
        id: 'netcheck',
        title: 'Test de connectivité réseau',
        description: 'Tester la connectivité réseau et les performances',
        windowsCommand: 'tailscale netcheck',
        linuxCommand: 'tailscale netcheck',
        category: CommandCategories.troubleshooting,
        tags: ['network', 'test', 'connectivity'],
      ),

      // CONFIGURATION
      ClientCommand(
        id: 'accept_routes',
        title: 'Accepter les routes',
        description: 'Accepter les routes annoncées par d\'autres nœuds',
        windowsCommand:
            'tailscale up --login-server={server_url} --accept-routes',
        linuxCommand:
            'sudo tailscale up --login-server={server_url} --accept-routes',
        category: CommandCategories.configuration,
        tags: ['routes', 'accept', 'serveur'],
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: 'URL du serveur Headscale',
            description:
                'Nécessaire pour s\'assurer que la commande est appliquée au bon réseau',
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
        ],
      ),

      ClientCommand(
        id: 'disable_key_expiry',
        title: 'Désactiver expiration clé',
        description: 'Empêcher l\'expiration automatique de la clé',
        windowsCommand: 'tailscale up --login-server={server_url} --timeout=0',
        linuxCommand:
            'sudo tailscale up --login-server={server_url} --timeout=0',
        category: CommandCategories.configuration,
        tags: ['key', 'expiry', 'timeout', 'serveur'],
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: 'URL du serveur Headscale',
            description:
                'Nécessaire pour s\'assurer que la commande est appliquée au bon réseau',
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
        ],
      ),

      // SÉCURITÉ
      ClientCommand(
        id: 'enable_ssh',
        title: 'Activer SSH Tailscale',
        description: 'Activer l\'accès SSH via Tailscale',
        windowsCommand: 'tailscale up --login-server={server_url} --ssh',
        linuxCommand: 'sudo tailscale up --login-server={server_url} --ssh',
        category: CommandCategories.security,
        tags: ['ssh', 'remote', 'serveur'],
        requiresElevation: true,
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: 'URL du serveur Headscale',
            description:
                'Nécessaire pour s\'assurer que la commande est appliquée au bon réseau',
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
        ],
      ),

      ClientCommand(
        id: 'disable_ssh',
        title: 'Désactiver SSH Tailscale',
        description: 'Désactiver l\'accès SSH via Tailscale',
        windowsCommand: 'tailscale up --login-server={server_url} --ssh=false',
        linuxCommand:
            'sudo tailscale up --login-server={server_url} --ssh=false',
        category: CommandCategories.security,
        tags: ['ssh', 'disable', 'serveur'],
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: 'URL du serveur Headscale',
            description:
                'Nécessaire pour s\'assurer que la commande est appliquée au bon réseau',
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
        ],
      ),

      // MAINTENANCE
      ClientCommand(
        id: 'update',
        title: 'Mettre à jour Tailscale',
        description: 'Mettre à jour vers la dernière version',
        windowsCommand: 'tailscale update',
        linuxCommand: 'sudo tailscale update',
        category: CommandCategories.maintenance,
        tags: ['update', 'upgrade'],
        requiresElevation: true,
      ),

      ClientCommand(
        id: 'version',
        title: 'Version Tailscale',
        description: 'Afficher la version installée',
        windowsCommand: 'tailscale version',
        linuxCommand: 'tailscale version',
        category: CommandCategories.maintenance,
        tags: ['version', 'info'],
      ),

      ClientCommand(
        id: 'bugreport',
        title: 'Rapport de bug',
        description: 'Générer un rapport de diagnostic',
        windowsCommand: 'tailscale bugreport',
        linuxCommand: 'sudo tailscale bugreport',
        category: CommandCategories.troubleshooting,
        tags: ['bug', 'diagnostic', 'support'],
      ),

      // LINUX SPÉCIFIQUES
      ClientCommand(
        id: 'enable_ip_forwarding',
        title: 'Activer IP forwarding (Linux)',
        description: 'Activer le transfert IP pour le routage de sous-réseau',
        windowsCommand: 'echo "Non applicable sur Windows"',
        linuxCommand:
            'echo \'net.ipv4.ip_forward = 1\' | sudo tee -a /etc/sysctl.conf && echo \'net.ipv6.conf.all.forwarding = 1\' | sudo tee -a /etc/sysctl.conf && sudo sysctl -p',
        category: CommandCategories.configuration,
        tags: ['linux', 'forwarding', 'routing'],
        requiresElevation: true,
        notes: 'Requis sur Linux pour annoncer des routes de sous-réseau',
      ),

      ClientCommand(
        id: 'install_tailscale_debian',
        title: 'Installer Tailscale (Debian/Ubuntu)',
        description: 'Installer Tailscale sur les systèmes basés sur Debian',
        windowsCommand: 'echo "Non applicable sur Windows"',
        linuxCommand: 'curl -fsSL https://tailscale.com/install.sh | sh',
        category: CommandCategories.maintenance,
        tags: ['linux', 'install', 'debian', 'ubuntu'],
        requiresElevation: true,
        notes: 'Installation automatique pour Debian, Ubuntu et dérivés',
      ),

      ClientCommand(
        id: 'install_tailscale_rhel',
        title: 'Installer Tailscale (RHEL/CentOS/Fedora)',
        description: 'Installer Tailscale sur les systèmes Red Hat',
        windowsCommand: 'echo "Non applicable sur Windows"',
        linuxCommand:
            'sudo dnf config-manager --add-repo https://pkgs.tailscale.com/stable/rhel/8/tailscale.repo && sudo dnf install tailscale',
        category: CommandCategories.maintenance,
        tags: ['linux', 'install', 'rhel', 'centos', 'fedora'],
        requiresElevation: true,
        notes: 'Installation pour Red Hat Enterprise Linux, CentOS, Fedora',
      ),

      ClientCommand(
        id: 'install_tailscale_arch',
        title: 'Installer Tailscale (Arch Linux)',
        description: 'Installer Tailscale sur Arch Linux',
        windowsCommand: 'echo "Non applicable sur Windows"',
        linuxCommand: 'sudo pacman -S tailscale',
        category: CommandCategories.maintenance,
        tags: ['linux', 'install', 'arch'],
        requiresElevation: true,
        notes: 'Installation via le gestionnaire de paquets pacman',
      ),

      ClientCommand(
        id: 'enable_tailscale_service',
        title: 'Activer le service Tailscale (Linux)',
        description: 'Activer et démarrer le service Tailscale au boot',
        windowsCommand: 'echo "Non applicable sur Windows"',
        linuxCommand: 'sudo systemctl enable --now tailscaled',
        category: CommandCategories.configuration,
        tags: ['linux', 'service', 'systemd'],
        requiresElevation: true,
        notes: 'Active le démon Tailscale et le démarre automatiquement',
      ),

      ClientCommand(
        id: 'check_tailscale_service',
        title: 'Vérifier le service Tailscale (Linux)',
        description: 'Vérifier le statut du service Tailscale',
        windowsCommand: 'echo "Non applicable sur Windows"',
        linuxCommand: 'sudo systemctl status tailscaled',
        category: CommandCategories.troubleshooting,
        tags: ['linux', 'service', 'status'],
        requiresElevation: false,
        notes: 'Affiche l\'état du démon Tailscale',
      ),

      ClientCommand(
        id: 'restart_tailscale_service',
        title: 'Redémarrer le service Tailscale (Linux)',
        description: 'Redémarrer le démon Tailscale',
        windowsCommand: 'echo "Non applicable sur Windows"',
        linuxCommand: 'sudo systemctl restart tailscaled',
        category: CommandCategories.troubleshooting,
        tags: ['linux', 'service', 'restart'],
        requiresElevation: true,
        notes: 'Redémarre le service en cas de problème',
      ),

      ClientCommand(
        id: 'check_firewall_ufw',
        title: 'Configurer UFW pour Tailscale (Linux)',
        description: 'Configurer le pare-feu UFW pour autoriser Tailscale',
        windowsCommand: 'echo "Non applicable sur Windows"',
        linuxCommand:
            'sudo ufw allow in on tailscale0 && sudo ufw allow out on tailscale0',
        category: CommandCategories.security,
        tags: ['linux', 'firewall', 'ufw'],
        requiresElevation: true,
        notes: 'Configure UFW pour autoriser le trafic Tailscale',
      ),

      ClientCommand(
        id: 'check_firewall_iptables',
        title: 'Configurer iptables pour Tailscale (Linux)',
        description: 'Configurer iptables pour autoriser Tailscale',
        windowsCommand: 'echo "Non applicable sur Windows"',
        linuxCommand:
            'sudo iptables -I INPUT -i tailscale0 -j ACCEPT && sudo iptables -I FORWARD -i tailscale0 -j ACCEPT && sudo iptables -I FORWARD -o tailscale0 -j ACCEPT',
        category: CommandCategories.security,
        tags: ['linux', 'firewall', 'iptables'],
        requiresElevation: true,
        notes: 'Configure iptables pour autoriser le trafic Tailscale',
      ),

      ClientCommand(
          id: 'setup_subnet_router_linux',
          title: 'Configurer routeur de sous-réseau (Linux)',
          description:
              'Configuration complète pour devenir un routeur de sous-réseau',
          windowsCommand: 'echo "Non applicable sur Windows"',
          linuxCommand:
              'echo \'net.ipv4.ip_forward = 1\' | sudo tee -a /etc/sysctl.conf && echo \'net.ipv6.conf.all.forwarding = 1\' | sudo tee -a /etc/sysctl.conf && sudo sysctl -p && sudo tailscale up --login-server={server_url} --advertise-routes=192.168.1.0/24 --accept-routes',
          category: CommandCategories.routing,
          tags: ['linux', 'subnet', 'router', 'forwarding', 'serveur'],
          requiresElevation: true,
          notes:
              'Active le forwarding IP et configure le routage de sous-réseau. Remplacez les routes par les vôtres.',
          type: CommandType.dynamic,
          isDynamic: true,
          parameters: [
            CommandParameter(
              id: 'server_url',
              label: 'URL du serveur Headscale',
              description: 'URL de votre serveur Headscale',
              type: ParameterType.text,
              placeholder: 'https://headscale.example.com',
              required: true,
            ),
          ]),

      ClientCommand(
        id: 'check_tailscale_logs',
        title: 'Consulter les logs Tailscale (Linux)',
        description: 'Afficher les logs du service Tailscale',
        windowsCommand: 'echo "Non applicable sur Windows"',
        linuxCommand: 'sudo journalctl -u tailscaled -f',
        category: CommandCategories.troubleshooting,
        tags: ['linux', 'logs', 'debug'],
        requiresElevation: false,
        notes: 'Affiche les logs en temps réel du démon Tailscale',
      ),

      ClientCommand(
        id: 'uninstall_tailscale_debian',
        title: 'Désinstaller Tailscale (Debian/Ubuntu)',
        description: 'Désinstaller complètement Tailscale',
        windowsCommand: 'echo "Non applicable sur Windows"',
        linuxCommand: 'sudo apt remove tailscale && sudo apt purge tailscale',
        category: CommandCategories.maintenance,
        tags: ['linux', 'uninstall', 'debian', 'ubuntu'],
        requiresElevation: true,
        notes: 'Supprime Tailscale et ses fichiers de configuration',
      ),

      ClientCommand(
        id: 'backup_tailscale_config',
        title: 'Sauvegarder la configuration Tailscale (Linux)',
        description: 'Sauvegarder les fichiers de configuration Tailscale',
        windowsCommand: 'echo "Non applicable sur Windows"',
        linuxCommand:
            'sudo tar -czf ~/tailscale-backup-\$(date +%Y%m%d).tar.gz /var/lib/tailscale/',
        category: CommandCategories.maintenance,
        tags: ['linux', 'backup', 'configuration'],
        requiresElevation: true,
        notes: 'Crée une archive de sauvegarde dans le répertoire home',
      ),

      ClientCommand(
        id: 'check_network_interfaces',
        title: 'Vérifier les interfaces réseau (Linux)',
        description: 'Afficher toutes les interfaces réseau incluant Tailscale',
        windowsCommand: 'echo "Non applicable sur Windows"',
        linuxCommand:
            'ip addr show && echo "--- Routes Tailscale ---" && ip route show table 52',
        category: CommandCategories.troubleshooting,
        tags: ['linux', 'network', 'interfaces'],
        requiresElevation: false,
        notes: 'Affiche les interfaces et les routes Tailscale',
      ),

      ClientCommand(
          id: 'setup_exit_node_linux',
          title: 'Configurer nœud de sortie (Linux)',
          description: 'Configuration complète pour devenir un nœud de sortie',
          windowsCommand: 'echo "Non applicable sur Windows"',
          linuxCommand:
              'echo \'net.ipv4.ip_forward = 1\' | sudo tee -a /etc/sysctl.conf && echo \'net.ipv6.conf.all.forwarding = 1\' | sudo tee -a /etc/sysctl.conf && sudo sysctl -p && sudo tailscale up --login-server={server_url} --advertise-exit-node',
          category: CommandCategories.routing,
          tags: ['linux', 'exit-node', 'forwarding', 'serveur'],
          requiresElevation: true,
          notes:
              'Active le forwarding et configure ce nœud comme point de sortie Internet',
          type: CommandType.dynamic,
          isDynamic: true,
          parameters: [
            CommandParameter(
              id: 'server_url',
              label: 'URL du serveur Headscale',
              description: 'URL de votre serveur Headscale',
              type: ParameterType.text,
              placeholder: 'https://headscale.example.com',
              required: true,
            ),
          ]),

      ClientCommand(
          id: 'configure_dns_linux',
          title: 'Configurer DNS Tailscale (Linux)',
          description: 'Configurer la résolution DNS via Tailscale',
          windowsCommand: 'echo "Non applicable sur Windows"',
          linuxCommand:
              'sudo tailscale up --login-server={server_url} --accept-dns=true',
          category: CommandCategories.configuration,
          tags: ['linux', 'dns', 'resolution', 'serveur'],
          requiresElevation: true,
          type: CommandType.dynamic,
          isDynamic: true,
          parameters: [
            CommandParameter(
              id: 'server_url',
              label: 'URL du serveur Headscale',
              description: 'URL de votre serveur Headscale',
              type: ParameterType.text,
              placeholder: 'https://headscale.example.com',
              required: true,
            ),
          ]),
    ];
  }
}

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

  static String get(String category, bool isFr) {
    if (isFr) return category;
    switch (category) {
      case connection:
        return 'Connection';
      case routing:
        return 'Routing';
      case troubleshooting:
        return 'Troubleshooting';
      case configuration:
        return 'Configuration';
      case monitoring:
        return 'Monitoring';
      case security:
        return 'Security';
      case maintenance:
        return 'Maintenance';
      case serverSpecific:
        return 'Server Specific';
      default:
        return category;
    }
  }
}

// Générateur de commandes dynamiques
class DynamicCommandGenerator {
  // Générer des commandes basées sur le serveur actuel
  static List<ClientCommand> generateServerBasedCommands(String serverUrl,
      {bool isFr = true}) {
    return [
      // Connexion avec serveur personnalisé
      ClientCommand(
        id: 'connect_to_server',
        title: isFr
            ? 'Connexion au serveur configuré'
            : 'Connect to configured server',
        description: isFr
            ? 'Se connecter au serveur Headscale configuré dans l\'application'
            : 'Connect to the Headscale server configured in the application',
        windowsCommand: 'tailscale up --login-server=$serverUrl',
        linuxCommand: 'sudo tailscale up --login-server=$serverUrl',
        category: CommandCategories.get(CommandCategories.connection, isFr),
        tags: ['connexion', 'serveur', 'up'],
        type: CommandType.serverBased,
        isDynamic: false,
      ),

      // Connexion avec clé d'auth personnalisée
      ClientCommand(
        id: 'connect_with_custom_key',
        title: isFr
            ? 'Connexion avec clé pré-authentifiée'
            : 'Connect with pre-auth key',
        description: isFr
            ? 'Se connecter avec une clé pré-authentifiée (à saisir manuellement)'
            : 'Connect with a pre-authentication key (enter manually)',
        windowsCommand:
            'tailscale up --login-server=$serverUrl --authkey={authkey}',
        linuxCommand:
            'sudo tailscale up --login-server=$serverUrl --authkey={authkey}',
        category: CommandCategories.get(CommandCategories.connection, isFr),
        tags: ['connexion', 'authkey', 'up'],
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'authkey',
            label: isFr ? 'Clé d\'authentification' : 'Authentication key',
            description: isFr
                ? 'Entrez votre clé pré-authentifiée'
                : 'Enter your pre-auth key',
            type: ParameterType.text,
            placeholder: 'nodekey-xxxxx ou tskey-xxxxx',
          ),
        ],
      ),
    ];
  }

  // Générer des commandes basées sur les nœuds existants
  static List<ClientCommand> generateNodeBasedCommands(List<Node> nodes,
      {bool isFr = true}) {
    List<ClientCommand> commands = [];

    // Commandes pour utiliser des nœuds de sortie existants
    final exitNodes = nodes.where((n) => n.isExitNode && n.online).toList();
    if (exitNodes.isNotEmpty) {
      commands.add(
        ClientCommand(
          id: 'use_specific_exit_node',
          title: isFr
              ? 'Utiliser un nœud de sortie spécifique'
              : 'Use a specific exit node',
          description: isFr
              ? 'Router le trafic via un nœud de sortie disponible'
              : 'Route traffic through an available exit node',
          windowsCommand:
              'tailscale up --login-server={server_url} --exit-node={node_name}',
          linuxCommand:
              'sudo tailscale up --login-server={server_url} --exit-node={node_name}',
          category: CommandCategories.get(CommandCategories.routing, isFr),
          tags: ['exit-node', 'routing', 'spécifique', 'serveur'],
          type: CommandType.dynamic,
          isDynamic: true,
          parameters: [
            CommandParameter(
              id: 'server_url',
              label: isFr ? 'URL du serveur Headscale' : 'Headscale server URL',
              description: isFr
                  ? 'URL de votre serveur Headscale'
                  : 'Your Headscale server URL',
              type: ParameterType.text,
              placeholder: 'https://headscale.example.com',
              required: true,
            ),
            CommandParameter(
              id: 'node_name',
              label: isFr ? 'Nœud de sortie' : 'Exit node',
              description: isFr
                  ? 'Sélectionnez un nœud de sortie disponible'
                  : 'Select an available exit node',
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
          title: isFr ? 'Ping vers un nœud spécifique' : 'Ping a specific node',
          description: isFr
              ? 'Tester la connectivité vers un nœud du réseau'
              : 'Test connectivity to a network node',
          windowsCommand: 'tailscale ping {node_ip}',
          linuxCommand: 'tailscale ping {node_ip}',
          category:
              CommandCategories.get(CommandCategories.troubleshooting, isFr),
          tags: ['ping', 'test', 'spécifique'],
          type: CommandType.dynamic,
          isDynamic: true,
          parameters: [
            CommandParameter(
              id: 'node_ip',
              label: isFr ? 'Nœud cible' : 'Target node',
              description: isFr
                  ? 'Sélectionnez un nœud à tester'
                  : 'Select a node to test',
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
  static List<ClientCommand> generateRouteBasedCommands(List<Node> nodes,
      {bool isFr = true}) {
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
          title: isFr
              ? 'Annoncer des routes spécifiques'
              : 'Advertise specific routes',
          description: isFr
              ? 'Annoncer des routes de sous-réseau personnalisées'
              : 'Advertise custom subnet routes',
          windowsCommand:
              'tailscale up --login-server={server_url} --advertise-routes={routes}',
          linuxCommand:
              'sudo tailscale up --login-server={server_url} --advertise-routes={routes}',
          category: CommandCategories.get(CommandCategories.routing, isFr),
          tags: ['routes', 'subnet', 'personnalisé', 'serveur'],
          type: CommandType.dynamic,
          isDynamic: true,
          parameters: [
            CommandParameter(
              id: 'server_url',
              label: isFr ? 'URL du serveur Headscale' : 'Headscale server URL',
              description: isFr
                  ? 'URL de votre serveur Headscale'
                  : 'Your Headscale server URL',
              type: ParameterType.text,
              placeholder: 'https://headscale.example.com',
              required: true,
            ),
            CommandParameter(
              id: 'routes',
              label: isFr ? 'Routes à annoncer' : 'Routes to advertise',
              description: isFr
                  ? 'Entrez les routes séparées par des virgules (ex: 192.168.1.0/24,10.0.0.0/8)'
                  : 'Enter routes separated by commas (e.g. 192.168.1.0/24,10.0.0.0/8)',
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
  static List<ClientCommand> generateInteractiveCommands({bool isFr = true}) {
    return [
      // Configuration personnalisée complète
      ClientCommand(
        id: 'custom_setup',
        title: isFr ? 'Configuration personnalisée' : 'Custom Setup',
        description: isFr
            ? 'Configuration complète avec paramètres personnalisés'
            : 'Full setup with custom parameters',
        windowsCommand:
            'tailscale up --login-server={server_url} --hostname={hostname} {additional_params}',
        linuxCommand:
            'sudo tailscale up --login-server={server_url} --hostname={hostname} {additional_params}',
        category: CommandCategories.get(CommandCategories.configuration, isFr),
        tags: ['configuration', 'personnalisé', 'complet'],
        type: CommandType.interactive,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: isFr ? 'URL du serveur' : 'Server URL',
            description: isFr
                ? 'URL de votre serveur Headscale'
                : 'Your Headscale server URL',
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
          ),
          CommandParameter(
            id: 'hostname',
            label: isFr ? 'Nom d\'hôte' : 'Hostname',
            description: isFr
                ? 'Nom personnalisé pour ce nœud'
                : 'Custom name for this node',
            type: ParameterType.text,
            placeholder: 'mon-ordinateur',
            required: false,
          ),
          CommandParameter(
            id: 'accept_routes',
            label: isFr ? 'Accepter les routes' : 'Accept routes',
            description: isFr
                ? 'Accepter les routes annoncées par d\'autres nœuds'
                : 'Accept routes advertised by other nodes',
            type: ParameterType.boolean,
            defaultValue: 'false',
          ),
          CommandParameter(
            id: 'advertise_exit_node',
            label: isFr ? 'Devenir nœud de sortie' : 'Become exit node',
            description: isFr
                ? 'Configurer ce nœud comme point de sortie Internet'
                : 'Configure this node as an Internet exit point',
            type: ParameterType.boolean,
            defaultValue: 'false',
          ),
          CommandParameter(
            id: 'enable_ssh',
            label: isFr ? 'Activer SSH' : 'Enable SSH',
            description: isFr
                ? 'Activer l\'accès SSH via Tailscale'
                : 'Enable SSH access via Tailscale',
            type: ParameterType.boolean,
            defaultValue: 'false',
          ),
        ],
      ),

      // Commande de routage avancé
      ClientCommand(
        id: 'advanced_routing',
        title: isFr
            ? 'Configuration de routage avancée'
            : 'Advanced routing configuration',
        description: isFr
            ? 'Configuration avancée des routes et du routage'
            : 'Advanced route and routing configuration',
        windowsCommand:
            'tailscale up --login-server={server_url} --advertise-routes={routes} {exit_node_param} {accept_routes_param}',
        linuxCommand:
            'sudo tailscale up --login-server={server_url} --advertise-routes={routes} {exit_node_param} {accept_routes_param}',
        category: CommandCategories.get(CommandCategories.routing, isFr),
        tags: ['routing', 'avancé', 'personnalisé', 'serveur'],
        type: CommandType.interactive,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: isFr ? 'URL du serveur Headscale' : 'Headscale server URL',
            description: isFr
                ? 'URL de votre serveur Headscale'
                : 'Your Headscale server URL',
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
          CommandParameter(
            id: 'routes',
            label: isFr ? 'Routes à annoncer' : 'Routes to advertise',
            description: isFr
                ? 'Routes de sous-réseau à partager'
                : 'Subnet routes to share',
            type: ParameterType.text,
            placeholder: '192.168.1.0/24,10.0.0.0/8',
            required: false,
          ),
          CommandParameter(
            id: 'use_exit_node',
            label: isFr ? 'Utiliser comme nœud de sortie' : 'Use as exit node',
            description: isFr
                ? 'Configurer ce nœud pour router le trafic Internet'
                : 'Configure this node to route Internet traffic',
            type: ParameterType.boolean,
            defaultValue: 'false',
          ),
          CommandParameter(
            id: 'accept_routes',
            label: isFr ? 'Accepter les routes' : 'Accept routes',
            description: isFr
                ? 'Accepter les routes des autres nœuds'
                : 'Accept routes from other nodes',
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
    bool isFr = true,
  }) {
    List<ClientCommand> allCommands = [];

    // Commandes statiques de base
    allCommands.addAll(_getStaticCommands(isFr: isFr));

    // Commandes basées sur le serveur
    if (serverUrl != null) {
      allCommands.addAll(generateServerBasedCommands(serverUrl, isFr: isFr));
    }

    // Commandes basées sur les nœuds
    if (nodes != null && nodes.isNotEmpty) {
      allCommands.addAll(generateNodeBasedCommands(nodes, isFr: isFr));
      allCommands.addAll(generateRouteBasedCommands(nodes, isFr: isFr));
    }

    // Commandes interactives
    allCommands.addAll(generateInteractiveCommands(isFr: isFr));

    return allCommands;
  }

  // Commandes statiques de base
  static List<ClientCommand> _getStaticCommands({bool isFr = true}) {
    return [
      // WEB UI
      ClientCommand(
        id: 'web_ui',
        title:
            isFr ? "Ouvrir l'interface web locale" : "Open local web interface",
        description: isFr
            ? "Ouvre l'interface web locale du client Tailscale pour voir les pairs et le statut (si supporté par le client)."
            : "Opens the local Tailscale client web interface to view peers and status (if supported by the client).",
        windowsCommand: 'tailscale web',
        linuxCommand: 'tailscale web',
        category: CommandCategories.get(CommandCategories.monitoring, isFr),
        tags: ['web', 'ui', 'interface', 'monitoring'],
        notes: isFr
            ? "Cette commande peut ouvrir un navigateur directement ou afficher une URL à copier."
            : "This command may open a browser directly or display a URL to copy.",
      ),

      // SERVE
      ClientCommand(
        id: 'serve',
        title: isFr ? "Exposer un service (Serve)" : "Expose a service (Serve)",
        description: isFr
            ? "Partage un service local (ex: serveur web) sur le réseau Tailscale."
            : "Shares a local service (e.g., web server) on the Tailscale network.",
        windowsCommand: 'tailscale serve {protocol} /{port}',
        linuxCommand: 'tailscale serve {protocol} /{port}',
        category: CommandCategories.get(CommandCategories.routing, isFr),
        tags: ['serve', 'proxy', 'https', 'tcp'],
        type: CommandType.interactive,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'protocol',
            label: isFr ? 'Protocole' : 'Protocol',
            description: isFr
                ? 'Protocole à utiliser (https, http, tcp). Par défaut https.'
                : 'Protocol to use (https, http, tcp). Default is https.',
            type: ParameterType.text,
            defaultValue: 'https',
            options: ['https', 'http', 'tcp'],
            required: false,
          ),
          CommandParameter(
            id: 'port',
            label: isFr ? 'Port local du service' : 'Local service port',
            description: isFr
                ? 'Le port sur lequel votre service écoute en local.'
                : 'The port your service is listening on locally.',
            type: ParameterType.number,
            placeholder: '80, 3000, 8080...',
            required: true,
          ),
        ],
      ),

      // FILE
      ClientCommand(
        id: 'file_cp',
        title:
            isFr ? "Envoyer un fichier (Taildrop)" : "Send a file (Taildrop)",
        description: isFr
            ? "Envoyer un fichier à une autre de vos machines."
            : "Send a file to another of your machines.",
        windowsCommand: 'tailscale file cp {filepath} {target_node}:',
        linuxCommand: 'tailscale file cp {filepath} {target_node}:',
        category: CommandCategories.get(CommandCategories.maintenance, isFr),
        tags: ['file', 'taildrop', 'send', 'cp'],
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'filepath',
            label: isFr ? 'Chemin du fichier' : 'File path',
            description: isFr
                ? 'Chemin complet du fichier à envoyer.'
                : 'Full path of the file to send.',
            type: ParameterType.text,
            placeholder: 'C:\\Users\\...\\report.pdf ou /home/.../report.pdf',
            required: true,
          ),
          CommandParameter(
            id: 'target_node',
            label: isFr ? 'Machine de destination' : 'Target machine',
            description: isFr
                ? 'Le nom ou l\'IP de la machine à qui envoyer le fichier.'
                : 'The name or IP of the machine to send the file to.',
            type: ParameterType.nodeSelect,
            required: true,
          ),
        ],
      ),
      ClientCommand(
        id: 'file_get',
        title: isFr
            ? "Recevoir des fichiers (Taildrop)"
            : "Receive files (Taildrop)",
        description: isFr
            ? "Vérifier et recevoir les fichiers en attente de réception."
            : "Check for and receive incoming files.",
        windowsCommand: 'tailscale file get',
        linuxCommand: 'tailscale file get',
        category: CommandCategories.get(CommandCategories.maintenance, isFr),
        tags: ['file', 'taildrop', 'get', 'receive'],
      ),

      // DEBUG
      ClientCommand(
        id: 'debug_derp',
        title:
            isFr ? "Debug: Statut des relais DERP" : "Debug: DERP relay status",
        description: isFr
            ? "Affiche la latence des serveurs relais DERP."
            : "Displays latency to DERP relay servers.",
        windowsCommand: 'tailscale debug derp',
        linuxCommand: 'tailscale debug derp',
        category:
            CommandCategories.get(CommandCategories.troubleshooting, isFr),
        tags: ['debug', 'derp', 'relay', 'latency'],
      ),

      // UP FLAGS
      ClientCommand(
        id: 'force_reauth',
        title:
            isFr ? "Forcer la ré-authentification" : "Force re-authentication",
        description: isFr
            ? "Force une nouvelle authentification du client."
            : "Forces client re-authentication.",
        windowsCommand: 'tailscale up --force-reauth',
        linuxCommand: 'sudo tailscale up --force-reauth',
        category: CommandCategories.get(CommandCategories.connection, isFr),
        tags: ['up', 'reauth', 'login'],
      ),
      ClientCommand(
        id: 'shields_up',
        title: isFr ? "Activer 'Shields Up'" : "Enable 'Shields Up'",
        description: isFr
            ? "Bloque toutes les connexions entrantes, même depuis votre réseau Tailscale."
            : "Blocks all incoming connections, even from your Tailscale network.",
        windowsCommand: 'tailscale up --shields-up',
        linuxCommand: 'sudo tailscale up --shields-up',
        category: CommandCategories.get(CommandCategories.security, isFr),
        tags: ['up', 'firewall', 'shields', 'security'],
      ),
      ClientCommand(
        id: 'exit_node_allow_lan',
        title: isFr
            ? "Autoriser l'accès LAN en mode Exit Node"
            : "Allow LAN access in Exit Node mode",
        description: isFr
            ? "Permet à la machine d'accéder à son propre réseau local physique tout en utilisant un exit node."
            : "Allows the machine to access its own physical LAN while using an exit node.",
        windowsCommand: 'tailscale up --exit-node-allow-lan-access=true',
        linuxCommand: 'sudo tailscale up --exit-node-allow-lan-access=true',
        category: CommandCategories.get(CommandCategories.routing, isFr),
        tags: ['up', 'exit-node', 'lan', 'routing'],
      ),

      // CONNEXION
      ClientCommand(
        id: 'connect_basic',
        title: isFr ? 'Connexion simple' : 'Simple connection',
        description: isFr
            ? 'Se connecter à Tailscale en spécifiant un serveur Headscale'
            : 'Connect to Tailscale specifying a Headscale server',
        windowsCommand: 'tailscale up --login-server={server_url}',
        linuxCommand: 'sudo tailscale up --login-server={server_url}',
        category: CommandCategories.get(CommandCategories.connection, isFr),
        tags: ['connexion', 'up', 'simple', 'serveur'],
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: isFr ? 'URL du serveur Headscale' : 'Headscale server URL',
            description: isFr
                ? 'Entrez l\'URL de votre serveur Headscale'
                : 'Enter your Headscale server URL',
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
        ],
      ),

      ClientCommand(
        id: 'connect_with_authkey',
        title: isFr
            ? 'Connexion avec clé d\'authentification'
            : 'Connection with auth key',
        description: isFr
            ? 'Se connecter à un serveur Headscale avec une clé pré-authentifiée'
            : 'Connect to a Headscale server with a pre-auth key',
        windowsCommand:
            'tailscale up --login-server={server_url} --authkey={authkey}',
        linuxCommand:
            'sudo tailscale up --login-server={server_url} --authkey={authkey}',
        category: CommandCategories.get(CommandCategories.connection, isFr),
        tags: ['connexion', 'up', 'authkey', 'serveur'],
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: isFr ? 'URL du serveur Headscale' : 'Headscale server URL',
            description: isFr
                ? 'Entrez l\'URL de votre serveur Headscale'
                : 'Enter your Headscale server URL',
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
          CommandParameter(
            id: 'authkey',
            label: isFr ? 'Clé d\'authentification' : 'Auth key',
            description: isFr
                ? 'Entrez votre clé pré-authentifiée'
                : 'Enter your pre-auth key',
            type: ParameterType.text,
            placeholder: 'nodekey-xxxxx ou tskey-xxxxx',
            required: true,
          ),
        ],
      ),

      ClientCommand(
        id: 'connect_with_routes',
        title: isFr
            ? 'Connexion avec routes personnalisées'
            : 'Connection with custom routes',
        description: isFr
            ? 'Se connecter en annonçant des routes spécifiques'
            : 'Connect while advertising specific routes',
        windowsCommand:
            'tailscale up --login-server={server_url} --advertise-routes={routes}',
        linuxCommand:
            'sudo tailscale up --login-server={server_url} --advertise-routes={routes}',
        category: CommandCategories.get(CommandCategories.connection, isFr),
        tags: ['connexion', 'up', 'routes', 'serveur'],
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: isFr ? 'URL du serveur Headscale' : 'Headscale server URL',
            description: isFr
                ? 'Entrez l\'URL de votre serveur Headscale'
                : 'Enter your Headscale server URL',
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
          CommandParameter(
            id: 'routes',
            label: isFr ? 'Routes à annoncer' : 'Routes to advertise',
            description: isFr
                ? 'Entrez les routes séparées par des virgules'
                : 'Enter routes separated by commas',
            type: ParameterType.text,
            placeholder: '192.168.1.0/24,10.0.0.0/8',
            required: true,
          ),
        ],
      ),

      ClientCommand(
        id: 'disconnect',
        title: isFr ? 'Déconnexion' : 'Disconnect',
        description: isFr
            ? 'Se déconnecter du réseau Headscale'
            : 'Disconnect from Headscale network',
        windowsCommand: 'tailscale down',
        linuxCommand: 'sudo tailscale down',
        category: CommandCategories.get(CommandCategories.connection, isFr),
        tags: ['déconnexion', 'down'],
      ),

      ClientCommand(
        id: 'logout',
        title: isFr ? 'Déconnexion complète' : 'Full logout',
        description: isFr
            ? 'Se déconnecter et supprimer les informations d\'authentification'
            : 'Disconnect and remove authentication info',
        windowsCommand: 'tailscale logout',
        linuxCommand: 'sudo tailscale logout',
        category: CommandCategories.get(CommandCategories.connection, isFr),
        tags: ['logout', 'reset'],
      ),

      // SURVEILLANCE
      ClientCommand(
        id: 'status',
        title: isFr ? 'Statut de connexion' : 'Connection status',
        description: isFr
            ? 'Afficher le statut actuel de Tailscale'
            : 'Show current Tailscale status',
        windowsCommand: 'tailscale status',
        linuxCommand: 'tailscale status',
        category: CommandCategories.get(CommandCategories.monitoring, isFr),
        tags: ['status', 'info'],
      ),

      ClientCommand(
        id: 'ip_info',
        title: isFr ? 'Informations IP' : 'IP Information',
        description: isFr
            ? 'Afficher l\'adresse IP Tailscale'
            : 'Show Tailscale IP address',
        windowsCommand: 'tailscale ip',
        linuxCommand: 'tailscale ip',
        category: CommandCategories.get(CommandCategories.monitoring, isFr),
        tags: ['ip', 'address'],
      ),

      ClientCommand(
        id: 'netcheck',
        title:
            isFr ? 'Test de connectivité réseau' : 'Network connectivity test',
        description: isFr
            ? 'Tester la connectivité réseau et les performances'
            : 'Test network connectivity and performance',
        windowsCommand: 'tailscale netcheck',
        linuxCommand: 'tailscale netcheck',
        category:
            CommandCategories.get(CommandCategories.troubleshooting, isFr),
        tags: ['network', 'test', 'connectivity'],
      ),

      // CONFIGURATION
      ClientCommand(
        id: 'accept_routes',
        title: isFr ? 'Accepter les routes' : 'Accept routes',
        description: isFr
            ? 'Accepter les routes annoncées par d\'autres nœuds'
            : 'Accept routes advertised by other nodes',
        windowsCommand:
            'tailscale up --login-server={server_url} --accept-routes',
        linuxCommand:
            'sudo tailscale up --login-server={server_url} --accept-routes',
        category: CommandCategories.get(CommandCategories.configuration, isFr),
        tags: ['routes', 'accept', 'serveur'],
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: isFr ? 'URL du serveur Headscale' : 'Headscale server URL',
            description: isFr
                ? 'Nécessaire pour s\'assurer que la commande est appliquée au bon réseau'
                : 'Required to ensure command applies to the correct network',
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
        ],
      ),

      ClientCommand(
        id: 'disable_key_expiry',
        title: isFr ? 'Désactiver expiration clé' : 'Disable key expiry',
        description: isFr
            ? 'Empêcher l\'expiration automatique de la clé'
            : 'Prevent automatic key expiration',
        windowsCommand: 'tailscale up --login-server={server_url} --timeout=0',
        linuxCommand:
            'sudo tailscale up --login-server={server_url} --timeout=0',
        category: CommandCategories.get(CommandCategories.configuration, isFr),
        tags: ['key', 'expiry', 'timeout', 'serveur'],
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: isFr ? 'URL du serveur Headscale' : 'Headscale server URL',
            description: isFr
                ? 'Nécessaire pour s\'assurer que la commande est appliquée au bon réseau'
                : 'Required to ensure command applies to the correct network',
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
        ],
      ),

      // SÉCURITÉ
      ClientCommand(
        id: 'enable_ssh',
        title: isFr ? 'Activer SSH Tailscale' : 'Enable Tailscale SSH',
        description: isFr
            ? 'Activer l\'accès SSH via Tailscale'
            : 'Enable SSH access via Tailscale',
        windowsCommand: 'tailscale up --login-server={server_url} --ssh',
        linuxCommand: 'sudo tailscale up --login-server={server_url} --ssh',
        category: CommandCategories.get(CommandCategories.security, isFr),
        tags: ['ssh', 'remote', 'serveur'],
        requiresElevation: true,
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: isFr ? 'URL du serveur Headscale' : 'Headscale server URL',
            description: isFr
                ? 'Nécessaire pour s\'assurer que la commande est appliquée au bon réseau'
                : 'Required to ensure command applies to the correct network',
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
        ],
      ),

      ClientCommand(
        id: 'disable_ssh',
        title: isFr ? 'Désactiver SSH Tailscale' : 'Disable Tailscale SSH',
        description: isFr
            ? 'Désactiver l\'accès SSH via Tailscale'
            : 'Disable SSH access via Tailscale',
        windowsCommand: 'tailscale up --login-server={server_url} --ssh=false',
        linuxCommand:
            'sudo tailscale up --login-server={server_url} --ssh=false',
        category: CommandCategories.get(CommandCategories.security, isFr),
        tags: ['ssh', 'disable', 'serveur'],
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: isFr ? 'URL du serveur Headscale' : 'Headscale server URL',
            description: isFr
                ? 'Nécessaire pour s\'assurer que la commande est appliquée au bon réseau'
                : 'Required to ensure command applies to the correct network',
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
        ],
      ),

      // MAINTENANCE
      ClientCommand(
        id: 'update',
        title: isFr ? 'Mettre à jour Tailscale' : 'Update Tailscale',
        description: isFr
            ? 'Mettre à jour vers la dernière version'
            : 'Update to the latest version',
        windowsCommand: 'tailscale update',
        linuxCommand: 'sudo tailscale update',
        category: CommandCategories.get(CommandCategories.maintenance, isFr),
        tags: ['update', 'upgrade'],
        requiresElevation: true,
      ),

      ClientCommand(
        id: 'version',
        title: isFr ? 'Version Tailscale' : 'Tailscale Version',
        description:
            isFr ? 'Afficher la version installée' : 'Show installed version',
        windowsCommand: 'tailscale version',
        linuxCommand: 'tailscale version',
        category: CommandCategories.get(CommandCategories.maintenance, isFr),
        tags: ['version', 'info'],
      ),

      ClientCommand(
        id: 'bugreport',
        title: isFr ? 'Rapport de bug' : 'Bug report',
        description: isFr
            ? 'Générer un rapport de diagnostic'
            : 'Generate a diagnostic report',
        windowsCommand: 'tailscale bugreport',
        linuxCommand: 'sudo tailscale bugreport',
        category:
            CommandCategories.get(CommandCategories.troubleshooting, isFr),
        tags: ['bug', 'diagnostic', 'support'],
      ),

      // LINUX SPÉCIFIQUES
      ClientCommand(
        id: 'enable_ip_forwarding',
        title: isFr
            ? 'Activer IP forwarding (Linux)'
            : 'Enable IP forwarding (Linux)',
        description: isFr
            ? 'Activer le transfert IP pour le routage de sous-réseau'
            : 'Enable IP forwarding for subnet routing',
        windowsCommand: 'echo "Non applicable sur Windows"',
        linuxCommand:
            'echo \'net.ipv4.ip_forward = 1\' | sudo tee -a /etc/sysctl.conf && echo \'net.ipv6.conf.all.forwarding = 1\' | sudo tee -a /etc/sysctl.conf && sudo sysctl -p',
        category: CommandCategories.get(CommandCategories.configuration, isFr),
        tags: ['linux', 'forwarding', 'routing'],
        requiresElevation: true,
        notes: isFr
            ? 'Requis sur Linux pour annoncer des routes de sous-réseau'
            : 'Required on Linux to advertise subnet routes',
      ),

      ClientCommand(
        id: 'install_tailscale_debian',
        title: isFr
            ? 'Installer Tailscale (Debian/Ubuntu)'
            : 'Install Tailscale (Debian/Ubuntu)',
        description: isFr
            ? 'Installer Tailscale sur les systèmes basés sur Debian'
            : 'Install Tailscale on Debian-based systems',
        windowsCommand: 'echo "Non applicable sur Windows"',
        linuxCommand: 'curl -fsSL https://tailscale.com/install.sh | sh',
        category: CommandCategories.get(CommandCategories.maintenance, isFr),
        tags: ['linux', 'install', 'debian', 'ubuntu'],
        requiresElevation: true,
        notes: isFr
            ? 'Installation automatique pour Debian, Ubuntu et dérivés'
            : 'Automatic installation for Debian, Ubuntu and derivatives',
      ),

      ClientCommand(
        id: 'install_tailscale_rhel',
        title: isFr
            ? 'Installer Tailscale (RHEL/CentOS/Fedora)'
            : 'Install Tailscale (RHEL/CentOS/Fedora)',
        description: isFr
            ? 'Installer Tailscale sur les systèmes Red Hat'
            : 'Install Tailscale on Red Hat systems',
        windowsCommand: 'echo "Non applicable sur Windows"',
        linuxCommand:
            'sudo dnf config-manager --add-repo https://pkgs.tailscale.com/stable/rhel/8/tailscale.repo && sudo dnf install tailscale',
        category: CommandCategories.get(CommandCategories.maintenance, isFr),
        tags: ['linux', 'install', 'rhel', 'centos', 'fedora'],
        requiresElevation: true,
        notes: isFr
            ? 'Installation pour Red Hat Enterprise Linux, CentOS, Fedora'
            : 'Installation for Red Hat Enterprise Linux, CentOS, Fedora',
      ),

      ClientCommand(
        id: 'install_tailscale_arch',
        title: isFr
            ? 'Installer Tailscale (Arch Linux)'
            : 'Install Tailscale (Arch Linux)',
        description: isFr
            ? 'Installer Tailscale sur Arch Linux'
            : 'Install Tailscale on Arch Linux',
        windowsCommand: 'echo "Non applicable sur Windows"',
        linuxCommand: 'sudo pacman -S tailscale',
        category: CommandCategories.get(CommandCategories.maintenance, isFr),
        tags: ['linux', 'install', 'arch'],
        requiresElevation: true,
        notes: isFr
            ? 'Installation via le gestionnaire de paquets pacman'
            : 'Installation via pacman package manager',
      ),

      ClientCommand(
        id: 'enable_tailscale_service',
        title: isFr
            ? 'Activer le service Tailscale (Linux)'
            : 'Enable Tailscale service (Linux)',
        description: isFr
            ? 'Activer et démarrer le service Tailscale au boot'
            : 'Enable and start Tailscale service at boot',
        windowsCommand: 'echo "Non applicable sur Windows"',
        linuxCommand: 'sudo systemctl enable --now tailscaled',
        category: CommandCategories.get(CommandCategories.configuration, isFr),
        tags: ['linux', 'service', 'systemd'],
        requiresElevation: true,
        notes: isFr
            ? 'Active le démon Tailscale et le démarre automatiquement'
            : 'Enables Tailscale daemon and starts it automatically',
      ),

      ClientCommand(
        id: 'check_tailscale_service',
        title: isFr
            ? 'Vérifier le service Tailscale (Linux)'
            : 'Check Tailscale service (Linux)',
        description: isFr
            ? 'Vérifier le statut du service Tailscale'
            : 'Check Tailscale service status',
        windowsCommand: 'echo "Non applicable sur Windows"',
        linuxCommand: 'sudo systemctl status tailscaled',
        category:
            CommandCategories.get(CommandCategories.troubleshooting, isFr),
        tags: ['linux', 'service', 'status'],
        requiresElevation: false,
        notes: isFr
            ? 'Affiche l\'état du démon Tailscale'
            : 'Shows Tailscale daemon status',
      ),

      ClientCommand(
        id: 'restart_tailscale_service',
        title: isFr
            ? 'Redémarrer le service Tailscale (Linux)'
            : 'Restart Tailscale service (Linux)',
        description:
            isFr ? 'Redémarrer le démon Tailscale' : 'Restart Tailscale daemon',
        windowsCommand: 'echo "Non applicable sur Windows"',
        linuxCommand: 'sudo systemctl restart tailscaled',
        category:
            CommandCategories.get(CommandCategories.troubleshooting, isFr),
        tags: ['linux', 'service', 'restart'],
        requiresElevation: true,
        notes: isFr
            ? 'Redémarre le service en cas de problème'
            : 'Restarts the service in case of issues',
      ),

      ClientCommand(
        id: 'check_firewall_ufw',
        title: isFr
            ? 'Configurer UFW pour Tailscale (Linux)'
            : 'Configure UFW for Tailscale (Linux)',
        description: isFr
            ? 'Configurer le pare-feu UFW pour autoriser Tailscale'
            : 'Configure UFW firewall to allow Tailscale',
        windowsCommand: 'echo "Non applicable sur Windows"',
        linuxCommand:
            'sudo ufw allow in on tailscale0 && sudo ufw allow out on tailscale0',
        category: CommandCategories.get(CommandCategories.security, isFr),
        tags: ['linux', 'firewall', 'ufw'],
        requiresElevation: true,
        notes: isFr
            ? 'Configure UFW pour autoriser le trafic Tailscale'
            : 'Configures UFW to allow Tailscale traffic',
      ),

      ClientCommand(
        id: 'check_firewall_iptables',
        title: isFr
            ? 'Configurer iptables pour Tailscale (Linux)'
            : 'Configure iptables for Tailscale (Linux)',
        description: isFr
            ? 'Configurer iptables pour autoriser Tailscale'
            : 'Configure iptables to allow Tailscale',
        windowsCommand: 'echo "Non applicable sur Windows"',
        linuxCommand:
            'sudo iptables -I INPUT -i tailscale0 -j ACCEPT && sudo iptables -I FORWARD -i tailscale0 -j ACCEPT && sudo iptables -I FORWARD -o tailscale0 -j ACCEPT',
        category: CommandCategories.get(CommandCategories.security, isFr),
        tags: ['linux', 'firewall', 'iptables'],
        requiresElevation: true,
        notes: isFr
            ? 'Configure iptables pour autoriser le trafic Tailscale'
            : 'Configures iptables to allow Tailscale traffic',
      ),

      ClientCommand(
        id: 'setup_subnet_router_linux',
        title: isFr
            ? 'Configurer routeur de sous-réseau (Linux)'
            : 'Configure subnet router (Linux)',
        description: isFr
            ? 'Configuration complète pour devenir un routeur de sous-réseau'
            : 'Full configuration to become a subnet router',
        windowsCommand: 'echo "Non applicable sur Windows"',
        linuxCommand:
            'echo \'net.ipv4.ip_forward = 1\' | sudo tee -a /etc/sysctl.conf && echo \'net.ipv6.conf.all.forwarding = 1\' | sudo tee -a /etc/sysctl.conf && sudo sysctl -p && sudo tailscale up --login-server={server_url} --advertise-routes=192.168.1.0/24 --accept-routes',
        category: CommandCategories.get(CommandCategories.routing, isFr),
        tags: ['linux', 'subnet', 'router', 'forwarding', 'serveur'],
        requiresElevation: true,
        notes: isFr
            ? 'Active le forwarding IP et configure le routage de sous-réseau. Remplacez les routes par les vôtres.'
            : 'Enables IP forwarding and configures subnet routing. Replace routes with yours.',
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: isFr ? 'URL du serveur Headscale' : 'Headscale server URL',
            description: isFr
                ? 'URL de votre serveur Headscale'
                : 'Your Headscale server URL',
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
        ],
      ),

      ClientCommand(
        id: 'check_tailscale_logs',
        title: isFr
            ? 'Consulter les logs Tailscale (Linux)'
            : 'View Tailscale logs (Linux)',
        description: isFr
            ? 'Afficher les logs du service Tailscale'
            : 'Show logs of Tailscale service',
        windowsCommand: 'echo "Non applicable sur Windows"',
        linuxCommand: 'sudo journalctl -u tailscaled -f',
        category:
            CommandCategories.get(CommandCategories.troubleshooting, isFr),
        tags: ['linux', 'logs', 'debug'],
        requiresElevation: false,
        notes: isFr
            ? 'Affiche les logs en temps réel du démon Tailscale'
            : 'Shows real-time logs of the Tailscale daemon',
      ),

      ClientCommand(
        id: 'uninstall_tailscale_debian',
        title: isFr
            ? 'Désinstaller Tailscale (Debian/Ubuntu)'
            : 'Uninstall Tailscale (Debian/Ubuntu)',
        description: isFr
            ? 'Désinstaller complètement Tailscale'
            : 'Uninstall Tailscale completely',
        windowsCommand: 'echo "Non applicable sur Windows"',
        linuxCommand: 'sudo apt remove tailscale && sudo apt purge tailscale',
        category: CommandCategories.get(CommandCategories.maintenance, isFr),
        tags: ['linux', 'uninstall', 'debian', 'ubuntu'],
        requiresElevation: true,
        notes: isFr
            ? 'Supprime Tailscale et ses fichiers de configuration'
            : 'Removes Tailscale and its configuration files',
      ),

      ClientCommand(
        id: 'backup_tailscale_config',
        title: isFr
            ? 'Sauvegarder la configuration Tailscale (Linux)'
            : 'Backup Tailscale configuration (Linux)',
        description: isFr
            ? 'Sauvegarder les fichiers de configuration Tailscale'
            : 'Backup Tailscale configuration files',
        windowsCommand: 'echo "Non applicable sur Windows"',
        linuxCommand:
            'sudo tar -czf ~/tailscale-backup-\$(date +%Y%m%d).tar.gz /var/lib/tailscale/',
        category: CommandCategories.get(CommandCategories.maintenance, isFr),
        tags: ['linux', 'backup', 'configuration'],
        requiresElevation: true,
        notes: isFr
            ? 'Crée une archive de sauvegarde dans le répertoire home'
            : 'Creates a backup archive in the home directory',
      ),

      ClientCommand(
        id: 'check_network_interfaces',
        title: isFr
            ? 'Vérifier les interfaces réseau (Linux)'
            : 'Check network interfaces (Linux)',
        description: isFr
            ? 'Afficher toutes les interfaces réseau incluant Tailscale'
            : 'Show all network interfaces including Tailscale',
        windowsCommand: 'echo "Non applicable sur Windows"',
        linuxCommand:
            'ip addr show && echo "--- Routes Tailscale ---" && ip route show table 52',
        category:
            CommandCategories.get(CommandCategories.troubleshooting, isFr),
        tags: ['linux', 'network', 'interfaces'],
        requiresElevation: false,
        notes: isFr
            ? 'Affiche les interfaces et les routes Tailscale'
            : 'Shows interfaces and Tailscale routes',
      ),

      ClientCommand(
        id: 'setup_exit_node_linux',
        title: isFr
            ? 'Configurer nœud de sortie (Linux)'
            : 'Configure exit node (Linux)',
        description: isFr
            ? 'Configuration complète pour devenir un nœud de sortie'
            : 'Full configuration to become an exit node',
        windowsCommand: 'echo "Non applicable sur Windows"',
        linuxCommand:
            'echo \'net.ipv4.ip_forward = 1\' | sudo tee -a /etc/sysctl.conf && echo \'net.ipv6.conf.all.forwarding = 1\' | sudo tee -a /etc/sysctl.conf && sudo sysctl -p && sudo tailscale up --login-server={server_url} --advertise-exit-node',
        category: CommandCategories.get(CommandCategories.routing, isFr),
        tags: ['linux', 'exit-node', 'forwarding', 'serveur'],
        requiresElevation: true,
        notes: isFr
            ? 'Active le forwarding et configure ce nœud comme point de sortie Internet'
            : 'Enables forwarding and configures this node as an Internet exit point',
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: isFr ? 'URL du serveur Headscale' : 'Headscale server URL',
            description: isFr
                ? 'URL de votre serveur Headscale'
                : 'Your Headscale server URL',
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
        ],
      ),

      ClientCommand(
        id: 'configure_dns_linux',
        title: isFr
            ? 'Configurer DNS Tailscale (Linux)'
            : 'Configure Tailscale DNS (Linux)',
        description: isFr
            ? 'Configurer la résolution DNS via Tailscale'
            : 'Configure DNS resolution via Tailscale',
        windowsCommand: 'echo "Non applicable sur Windows"',
        linuxCommand:
            'sudo tailscale up --login-server={server_url} --accept-dns=true',
        category: CommandCategories.get(CommandCategories.configuration, isFr),
        tags: ['linux', 'dns', 'resolution', 'serveur'],
        requiresElevation: true,
        type: CommandType.dynamic,
        isDynamic: true,
        parameters: [
          CommandParameter(
            id: 'server_url',
            label: isFr ? 'URL du serveur Headscale' : 'Headscale server URL',
            description: isFr
                ? 'URL de votre serveur Headscale'
                : 'Your Headscale server URL',
            type: ParameterType.text,
            placeholder: 'https://headscale.example.com',
            required: true,
          ),
        ],
      ),
    ];
  }
}

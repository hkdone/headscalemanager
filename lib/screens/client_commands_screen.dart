import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headscalemanager/models/client_command.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/widgets/client_commands/command_filters_section.dart';
import 'package:headscalemanager/widgets/client_commands/commands_list.dart';
import 'package:headscalemanager/widgets/client_commands/parameter_config_dialog.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class ClientCommandsScreen extends StatefulWidget {
  const ClientCommandsScreen({super.key});

  @override
  State<ClientCommandsScreen> createState() => _ClientCommandsScreenState();
}

class _ClientCommandsScreenState extends State<ClientCommandsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ClientCommand> _allCommands = [];
  List<ClientCommand> _filteredCommands = [];
  String _selectedCategory = ''; // Will be initialized in initState
  String _selectedPlatform = 'Windows';
  bool _showOnlyElevated = false;
  String _allCategoriesString = 'Toutes'; // Default to French

  @override
  void initState() {
    super.initState();
    // Use a post-frame callback to access context safely for locale
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isFr = context.read<AppProvider>().locale.languageCode == 'fr';
      setState(() {
        _allCategoriesString = isFr ? 'Toutes' : 'All';
        _selectedCategory = _allCategoriesString;
      });
      _loadCommands();
    });
    _searchController.addListener(_filterCommands);
  }

  void _loadCommands() async {
    if (!mounted) return;
    final appProvider = context.read<AppProvider>();
    final isFr = appProvider.locale.languageCode == 'fr';

    try {
      final serverUrl = appProvider.activeServer?.url;
      final nodes = await appProvider.apiService.getNodes();
      final authKeys = await appProvider.apiService.getPreAuthKeys();
      final users = await appProvider.apiService.getUsers();

      _allCommands = DynamicCommandGenerator.generateAllCommands(
        serverUrl: serverUrl,
        nodes: nodes,
        authKeys: authKeys,
        users: users,
        isFr: isFr,
      );
    } catch (e) {
      // Fallback to static commands in case of an API error
      _allCommands = DynamicCommandGenerator.generateAllCommands(isFr: isFr);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFr
                ? 'Échec du chargement des commandes dynamiques: ${e.toString()}'
                : 'Failed to load dynamic commands: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _filterCommands();
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterCommands);
    _searchController.dispose();
    super.dispose();
  }

  void _filterCommands() {
    setState(() {
      _filteredCommands = _allCommands.where((command) {
        final searchTerm = _searchController.text.toLowerCase();
        final matchesSearch = searchTerm.isEmpty ||
            command.title.toLowerCase().contains(searchTerm) ||
            command.description.toLowerCase().contains(searchTerm) ||
            command.tags.any((tag) => tag.toLowerCase().contains(searchTerm));

        final matchesCategory = _selectedCategory == _allCategoriesString ||
            command.category == _selectedCategory;

        final matchesElevation =
            !_showOnlyElevated || command.requiresElevation;

        final isLinuxOnly = command.tags.contains('linux') &&
            command.windowsCommand.contains('Non applicable');
        final matchesPlatform =
            !(_selectedPlatform == 'Windows' && isLinuxOnly);

        return matchesSearch &&
            matchesCategory &&
            matchesElevation &&
            matchesPlatform;
      }).toList();
    });
  }

  List<String> _getCategories() {
    final categories = {_allCategoriesString};
    categories.addAll(_allCommands.map((cmd) => cmd.category));
    return categories.toList()
      ..sort((a, b) {
        if (a == _allCategoriesString) return -1;
        if (b == _allCategoriesString) return 1;
        return a.compareTo(b);
      });
  }

  void _copyToClipboard(String command) {
    Clipboard.setData(ClipboardData(text: command));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.read<AppProvider>().locale.languageCode == 'fr'
              ? 'Commande copiée dans le presse-papiers'
              : 'Command copied to clipboard',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareCommand(ClientCommand command) {
    final platformCommand = command.getCommandForPlatform(_selectedPlatform);
    SharePlus.instance.share(
      ShareParams(
        text: platformCommand,
        subject: 'Tailscale Command: ${command.title}',
      ),
    );
  }

  void _showParameterDialog(ClientCommand command) {
    showDialog(
      context: context,
      builder: (context) => ParameterConfigDialog(
        command: command,
        platform: _selectedPlatform,
        isFr: context.read<AppProvider>().locale.languageCode == 'fr',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          isFr ? 'Commandes Clients' : 'Client Commands',
          style: Theme.of(context).appBarTheme.titleTextStyle,
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: Theme.of(context).appBarTheme.iconTheme,
      ),
      body: SafeArea(
        child: Column(
          children: [
            CommandFiltersSection(
              isFr: isFr,
              searchController: _searchController,
              selectedPlatform: _selectedPlatform,
              selectedCategory: _selectedCategory,
              showOnlyElevated: _showOnlyElevated,
              categories: _getCategories(),
              onPlatformChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedPlatform = value;
                    _filterCommands();
                  });
                }
              },
              onCategoryChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value;
                    _filterCommands();
                  });
                }
              },
              onElevationChanged: (value) {
                if (value != null) {
                  setState(() {
                    _showOnlyElevated = value;
                    _filterCommands();
                  });
                }
              },
              onSearchClear: () {
                _searchController.clear();
              },
            ),
            Expanded(
              child: CommandsList(
                filteredCommands: _filteredCommands,
                isFr: isFr,
                selectedPlatform: _selectedPlatform,
                onCopy: _copyToClipboard,
                onShare: _shareCommand,
                onConfigure: _showParameterDialog,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

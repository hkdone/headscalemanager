import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/screens/help_screen.dart';
import 'package:headscalemanager/screens/help_screen_en.dart';
import 'package:headscalemanager/screens/security_settings_screen.dart';
import 'package:headscalemanager/services/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:headscalemanager/screens/add_edit_server_screen.dart';
import 'package:headscalemanager/services/tag_migration_service.dart';
import 'package:headscalemanager/widgets/server_list_tile.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appProvider = context.watch<AppProvider>();
    final isFr = appProvider.locale.languageCode == 'fr';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(isFr ? 'Paramètres' : 'Settings',
            style: theme.appBarTheme.titleTextStyle),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: theme.appBarTheme.iconTheme,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(isFr ? 'Serveurs' : 'Servers',
                  style: theme.textTheme.headlineSmall),
              const SizedBox(height: 16),
              Expanded(
                flex: 1, // Give 1/3 of space to server list (adjust as needed)
                child: _buildServerList(context),
              ),
              const Divider(height: 16),
              Expanded(
                flex: 2, // Give 2/3 of space to scrollable settings
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                            isFr
                                ? 'Notifications en arrière-plan'
                                : 'Background Notifications',
                            style: theme.textTheme.titleMedium),
                        subtitle: Text(
                            isFr
                                ? 'Vérifie périodiquement les nouvelles demandes d\'approbation.'
                                : 'Periodically check for new approval requests.',
                            style: theme.textTheme.bodySmall),
                        value: _notificationsEnabled,
                        onChanged: (bool value) async {
                          setState(() {
                            _notificationsEnabled = value;
                          });
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('notificationsEnabled', value);
                          await NotificationService.enableBackgroundTask(value);
                        },
                      ),
                      const Divider(height: 16),
                      // --- Grouped ACL & Migration Section ---
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header with Help
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      isFr
                                          ? 'Moteur ACL & Migration'
                                          : 'ACL Engine & Migration',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.help_outline,
                                        color: Colors.blue),
                                    onPressed: () =>
                                        _showMigrationHelpDialog(context, isFr),
                                    tooltip: isFr ? 'Aide' : 'Help',
                                  ),
                                ],
                              ),
                              const Divider(),
                              // Standard Engine Toggle
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  isFr
                                      ? 'Utiliser le moteur ACL standard'
                                      : 'Use Standard ACL Engine',
                                  style: theme.textTheme.bodyLarge,
                                ),
                                subtitle: Text(
                                  isFr
                                      ? 'Sépare les tags (Identity vs Capability).'
                                      : 'Splits tags (Identity vs Capability).',
                                  style: theme.textTheme.bodySmall,
                                ),
                                value: appProvider.useStandardAclEngine,
                                onChanged: (bool value) async {
                                  await appProvider
                                      .setStandardAclEngineEnabled(value);
                                },
                              ),
                              const SizedBox(height: 8),
                              // Danger Zone Header inside Card
                              Text(
                                isFr
                                    ? 'Zone de Danger / Migration'
                                    : 'Danger / Migration Zone',
                                style: theme.textTheme.titleSmall?.copyWith(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold),
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(isFr
                                    ? 'Migrer vers Standard'
                                    : 'Migrate to Standard'),
                                subtitle: Text(isFr
                                    ? 'Convertit les tags fusionnés.'
                                    : 'Converts merged tags.'),
                                trailing: const Icon(Icons.arrow_forward,
                                    color: Colors.orange),
                                onTap: () => _confirmAction(
                                    context,
                                    isFr
                                        ? 'Migrer tous les nœuds ?'
                                        : 'Migrate all nodes?',
                                    isFr
                                        ? 'Ceci va modifier les tags de TOUS vos nœuds. Assurez-vous d\'avoir activé le moteur Standard avant.'
                                        : 'This will modify tags for ALL nodes. Ensure Standard Engine is enabled first.',
                                    () => _performMigration(
                                        context, appProvider)),
                              ),
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(isFr
                                    ? 'Rollback vers Legacy'
                                    : 'Rollback to Legacy'),
                                subtitle: Text(isFr
                                    ? 'Re-fusionne les tags.'
                                    : 'Re-merges tags.'),
                                trailing: const Icon(Icons.history,
                                    color: Colors.red),
                                onTap: () => _confirmAction(
                                    context,
                                    isFr
                                        ? 'Annuler la migration ?'
                                        : 'Rollback migration?',
                                    isFr
                                        ? 'Ceci va remettre les tags au format fusionné (legacy).'
                                        : 'This will revert tags to the merged format.',
                                    () =>
                                        _performRollback(context, appProvider)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          final locale = context.read<AppProvider>().locale;
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => locale.languageCode == 'fr'
                                  ? const HelpScreen()
                                  : const HelpScreenEn(),
                            ),
                          );
                        },
                        child: Text(isFr ? 'Besoin d\'aide ?' : 'Need help?',
                            style: theme.textTheme.labelLarge
                                ?.copyWith(color: theme.colorScheme.primary)),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          backgroundColor: theme.colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        child: Text(isFr ? 'Fermer' : 'Close',
                            style: theme.textTheme.labelLarge?.copyWith(
                                fontSize: 16,
                                color: theme.colorScheme.onPrimary)),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: SpeedDial(
        icon: Icons.menu,
        activeIcon: Icons.close,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.add),
            label: isFr ? 'Ajouter un serveur' : 'Add Server',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddEditServerScreen()),
              );
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.security),
            label: isFr ? 'Sécurité' : 'Security',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const SecuritySettingsScreen()),
              );
            },
          ),
          SpeedDialChild(
            child: Text(isFr ? 'EN' : 'FR'),
            label: isFr ? 'Switch to English' : 'Passer en Français',
            onTap: () {
              final newLocale = isFr ? const Locale('en') : const Locale('fr');
              appProvider.setLocale(newLocale);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildServerList(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final servers = appProvider.servers;

    if (servers.isEmpty) {
      return Center(
        child: Text(
          appProvider.locale.languageCode == 'fr'
              ? 'Aucun serveur configuré.'
              : 'No servers configured.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return ListView.builder(
      itemCount: servers.length,
      itemBuilder: (context, index) {
        final server = servers[index];
        return ServerListTile(server: server);
      },
    );
  }

  Future<void> _confirmAction(BuildContext context, String title,
      String content, VoidCallback onConfirm) async {
    final isFr = context.read<AppProvider>().locale.languageCode == 'fr';
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              child: Text(isFr ? 'Annuler' : 'Cancel'),
              onPressed: () => Navigator.of(ctx).pop()),
          TextButton(
              child: Text(isFr ? 'Confirmer' : 'Confirm'),
              onPressed: () {
                Navigator.of(ctx).pop();
                onConfirm();
              }),
        ],
      ),
    );
  }

  Future<void> _performMigration(
      BuildContext context, AppProvider appProvider) async {
    final migrationService = TagMigrationService(appProvider.apiService);
    final isFr = appProvider.locale.languageCode == 'fr';

    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (_) => const Center(child: CircularProgressIndicator()));

    final result = await migrationService.migrateToStandard();

    if (context.mounted) Navigator.of(context).pop(); // Close loader

    if (context.mounted) {
      showDialog(
          context: context,
          builder: (_) => AlertDialog(
                title: Text(isFr ? 'Résultat Migration' : 'Migration Result'),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Succès: ${result.successCount}'),
                      Text('Echecs: ${result.failureCount}'),
                      if (result.errors.isNotEmpty) ...[
                        const Divider(),
                        ...result.errors.map((e) => Text(e,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 12))),
                      ]
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'))
                ],
              ));
    }
  }

  Future<void> _performRollback(
      BuildContext context, AppProvider appProvider) async {
    final migrationService = TagMigrationService(appProvider.apiService);
    final isFr = appProvider.locale.languageCode == 'fr';

    showDialog(
        barrierDismissible: false,
        context: context,
        builder: (_) => const Center(child: CircularProgressIndicator()));

    final result = await migrationService.rollbackToLegacy();

    if (context.mounted) Navigator.of(context).pop(); // Close loader

    if (context.mounted) {
      showDialog(
          context: context,
          builder: (_) => AlertDialog(
                title: Text(isFr ? 'Résultat Rollback' : 'Rollback Result'),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Succès: ${result.successCount}'),
                      Text('Echecs: ${result.failureCount}'),
                      if (result.errors.isNotEmpty) ...[
                        const Divider(),
                        ...result.errors.map((e) => Text(e,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 12))),
                      ]
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'))
                ],
              ));
    }
  }

  void _showMigrationHelpDialog(BuildContext context, bool isFr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isFr ? 'Aide Migration ACL' : 'ACL Migration Help'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHelpSection(
                context,
                isFr ? '1. Principe' : '1. Principle',
                isFr
                    ? 'Le moteur Legacy utilise des tags "fusionnés" (ex: tag:user;exit-node). Le moteur Standard sépare l\'identité (tag:user-client) des capacités (tag:user-exit-node) pour une meilleure gestion.'
                    : 'Legacy engine uses "merged" tags (e.g. tag:user;exit-node). Standard engine splits identity (tag:user-client) from capabilities (tag:user-exit-node) for better management.',
              ),
              _buildHelpSection(
                context,
                isFr ? '2. Procédure de Migration' : '2. Migration Procedure',
                isFr
                    ? 'A. Activez "Utiliser le moteur ACL standard".\nB. Cliquez sur "Migrer vers Standard".\nC. Redémarrez si nécessaire et vérifiez la connectivité.'
                    : 'A. Enable "Use Standard ACL Engine".\nB. Click "Migrate to Standard".\nC. Restart if needed and check connectivity.',
              ),
              _buildHelpSection(
                context,
                isFr ? '3. Procédure de Rollback' : '3. Rollback Procedure',
                isFr
                    ? 'A. Cliquez sur "Rollback vers Legacy".\nB. Désactivez "Utiliser le moteur ACL standard".\nC. Vérifiez que vos anciens tags sont revenus.'
                    : 'A. Click "Rollback to Legacy".\nB. Disable "Use Standard ACL Engine".\nC. Verify your old tags are back.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  Widget _buildHelpSection(BuildContext context, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(content),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/screens/help_screen.dart';
import 'package:headscalemanager/screens/help_screen_en.dart';
import 'package:headscalemanager/screens/api_keys_screen.dart';
import 'package:headscalemanager/screens/security_settings_screen.dart';
import 'package:headscalemanager/services/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:headscalemanager/screens/add_edit_server_screen.dart';
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
        title: Text(isFr ? 'Paramètres' : 'Settings', style: theme.appBarTheme.titleTextStyle),
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
              Text(isFr ? 'Serveurs' : 'Servers', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 16),
              Expanded(child: _buildServerList(context)),
              const Divider(height: 32),
              SwitchListTile(
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
              const Divider(height: 32),
              ListTile(
                title: Text(isFr ? 'Sécurité' : 'Security',
                    style: theme.textTheme.titleMedium),
                subtitle: Text(
                    isFr
                        ? 'Configurer le verrouillage de l\'application'
                        : 'Configure app lock',
                    style: theme.textTheme.bodySmall),
                leading: const Icon(Icons.security),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const SecuritySettingsScreen()),
                  );
                },
              ),
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLanguageButton(context, 'fr'),
                  const SizedBox(width: 16),
                  _buildLanguageButton(context, 'en'),
                ],
              ),
              const Spacer(),
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
                  backgroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                child: Text(isFr ? 'Fermer' : 'Close',
                    style: theme.textTheme.labelLarge?.copyWith(
                        fontSize: 16, color: theme.colorScheme.onPrimary)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddEditServerScreen()),
          );
        },
        child: const Icon(Icons.add),
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

  Widget _buildLanguageButton(BuildContext context, String languageCode) {
    final appProvider = Provider.of<AppProvider>(context);
    final isSelected = appProvider.locale.languageCode == languageCode;

    return GestureDetector(
      onTap: () {
        appProvider.setLocale(Locale(languageCode));
      },
      child: Opacity(
        opacity: isSelected ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: isSelected
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary, width: 2)
                : null,
          ),
          child: Text(
            languageCode.toUpperCase(),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
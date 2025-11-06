import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/screens/home_screen.dart';
import 'package:headscalemanager/screens/help_screen.dart';
import 'package:headscalemanager/screens/help_screen_en.dart';
import 'package:provider/provider.dart';

/// Écran des paramètres de l'application.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _serverUrlController;
  late TextEditingController _apiKeyController;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    _serverUrlController = TextEditingController();
    _apiKeyController = TextEditingController();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    final storage = context.read<AppProvider>().storageService;
    final serverUrl = await storage.getServerUrl();
    final apiKey = await storage.getApiKey();
    setState(() {
      _serverUrlController.text = serverUrl ?? '';
      _apiKeyController.text = apiKey ?? '';
    });
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

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
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                TextFormField(
                  controller: _serverUrlController,
                  decoration: _buildInputDecoration(
                      context,
                      isFr ? 'URL du serveur' : 'Server URL',
                      'https://headscale.example.com'),
                  style: theme.textTheme.bodyMedium,
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty ||
                        !Uri.parse(value).isAbsolute) {
                      return isFr
                          ? 'Veuillez entrer une URL valide'
                          : 'Please enter a valid URL';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _apiKeyController,
                  obscureText: _obscureApiKey,
                  style: theme.textTheme.bodyMedium,
                  decoration: _buildInputDecoration(
                          context,
                          isFr ? 'Clé API' : 'API Key',
                          isFr ? 'Votre clé secrète' : 'Your secret key')
                      .copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscureApiKey
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: theme.iconTheme.color),
                      onPressed: () {
                        setState(() {
                          _obscureApiKey = !_obscureApiKey;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return isFr
                          ? 'Veuillez entrer une clé API'
                          : 'Please enter an API key';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Text(isFr ? 'Langue' : 'Language',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLanguageButton(context, 'fr'),
                    const SizedBox(width: 16),
                    _buildLanguageButton(context, 'en'),
                  ],
                ),
                const SizedBox(height: 24),
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
                const Spacer(),
                ElevatedButton(
                  onPressed: _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  child: Text(isFr ? 'Enregistrer' : 'Save',
                      style: theme.textTheme.labelLarge?.copyWith(
                          fontSize: 16, color: theme.colorScheme.onPrimary)),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(BuildContext context, String label, String hint) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: theme.inputDecorationTheme.fillColor ?? (theme.brightness == Brightness.dark ? Colors.grey[800] : Colors.white),
      labelStyle: theme.inputDecorationTheme.labelStyle ?? theme.textTheme.titleMedium,
      hintStyle: theme.inputDecorationTheme.hintStyle ?? theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
      ),
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
                ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
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

  void _saveSettings() async {
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    if (_formKey.currentState!.validate()) {
      await context.read<AppProvider>().storageService.saveCredentials(
            serverUrl: _serverUrlController.text.trim(),
            apiKey: _apiKeyController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(isFr ? 'Paramètres enregistrés' : 'Settings saved')),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    }
  }
}

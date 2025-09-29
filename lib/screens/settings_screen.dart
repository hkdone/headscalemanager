import 'package:flutter/material.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/screens/home_screen.dart';
import 'package:headscalemanager/screens/help_screen.dart';
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Paramètres', style: theme.appBarTheme.titleTextStyle),
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
                  decoration: _buildInputDecoration(context, 'URL du serveur', 'https://headscale.example.com'),
                  style: theme.textTheme.bodyMedium,
                  validator: (value) {
                    if (value == null || value.isEmpty || !Uri.parse(value).isAbsolute) {
                      return 'Veuillez entrer une URL valide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _apiKeyController,
                  obscureText: _obscureApiKey,
                  style: theme.textTheme.bodyMedium,
                  decoration: _buildInputDecoration(context, 'Clé API', 'Votre clé secrète').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscureApiKey ? Icons.visibility_off : Icons.visibility, color: theme.iconTheme.color),
                      onPressed: () {
                        setState(() {
                          _obscureApiKey = !_obscureApiKey;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer une clé API';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24), // Added space for help button
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const HelpScreen()),
                    );
                  },
                  child: Text('Besoin d\'aide ?', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
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
                  child: Text('Enregistrer', style: theme.textTheme.labelLarge?.copyWith(fontSize: 16, color: theme.colorScheme.onPrimary)),
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

  void _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      await context.read<AppProvider>().storageService.saveCredentials(
            serverUrl: _serverUrlController.text.trim(),
            apiKey: _apiKeyController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paramètres enregistrés')),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }
    }
  }
}

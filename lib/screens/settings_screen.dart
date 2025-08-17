import 'package:flutter/material.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/screens/home_screen.dart';
import 'package:provider/provider.dart';

/// Écran des paramètres de l'application.
///
/// Permet à l'utilisateur de configurer l'URL du serveur Headscale et la clé API
/// nécessaires pour la connexion et l'interaction avec le serveur.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Clé globale pour le formulaire, utilisée pour la validation.
  final _formKey = GlobalKey<FormState>();

  /// Contrôleur pour le champ de texte de l'URL du serveur.
  late TextEditingController _serverUrlController;

  /// Contrôleur pour le champ de texte de la clé API.
  late TextEditingController _apiKeyController;

  @override
  void initState() {
    super.initState();
    _serverUrlController = TextEditingController();
    _apiKeyController = TextEditingController();
    _loadCredentials(); // Charge les identifiants sauvegardés au démarrage.
  }

  /// Charge les identifiants (URL du serveur et clé API) depuis le service de stockage.
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: Form(
        key: _formKey, // Associe la clé du formulaire pour la validation.
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Champ de texte pour l'URL du serveur Headscale.
              TextFormField(
                controller: _serverUrlController,
                decoration: const InputDecoration(
                  labelText: 'URL du serveur',
                  hintText: 'https://headscale.example.com',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer une URL de serveur';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Champ de texte pour la clé API Headscale.
              TextFormField(
                controller: _apiKeyController,
                obscureText: true, // Masque le texte pour la sécurité.
                decoration: const InputDecoration(
                  labelText: 'Clé API',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer une clé API';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              // Bouton pour enregistrer les paramètres.
              ElevatedButton(
                onPressed: () async {
                  // Valide le formulaire avant de sauvegarder.
                  if (_formKey.currentState!.validate()) {
                    await context.read<AppProvider>().storageService.saveCredentials(
                          serverUrl: _serverUrlController.text,
                          apiKey: _apiKeyController.text,
                        );
                    // Vérifie si le widget est toujours monté avant d'afficher le SnackBar et de naviguer.
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Paramètres enregistrés')),
                      );
                      // Navigue vers l'écran d'accueil et remplace l'écran actuel.
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                      );
                    }
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
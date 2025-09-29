import 'package:flutter/material.dart';
import 'package:headscalemanager/screens/home_screen.dart';
import 'package:headscalemanager/screens/settings_screen.dart';
import 'package:headscalemanager/services/storage_service.dart';

/// Écran de démarrage (Splash Screen) de l'application.
///
/// Cet écran est le premier affiché au lancement de l'application. Il est
/// responsable de vérifier la présence des identifiants de connexion (URL du
/// serveur et clé API) et de naviguer vers l'écran approprié ([HomeScreen]
/// ou [SettingsScreen]).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkCredentials(); // Lance la vérification des identifiants au démarrage.
  }

  /// Vérifie si les identifiants de connexion (URL du serveur et clé API)
  /// sont déjà configurés dans le service de stockage.
  ///
  /// Navigue vers l'écran d'accueil si les identifiants sont présents,
  /// sinon vers l'écran des paramètres pour la configuration initiale.
  Future<void> _checkCredentials() async {
    // Instancie le service de stockage pour accéder aux identifiants.
    final storage = StorageService();
    // Vérifie si des identifiants sont déjà sauvegardés.
    final hasCreds = await storage.hasCredentials();

    // Introduit un délai pour que l'écran de démarrage soit visible.
    await Future.delayed(const Duration(seconds: 1));

    // S'assure que le widget est toujours monté avant d'effectuer la navigation.
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => hasCreds ? const HomeScreen() : const SettingsScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Affiche un indicateur de chargement pendant la vérification des identifiants.
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.primary), // Indicateur visuel de chargement.
            const SizedBox(height: 20),
            Text('Chargement...', style: theme.textTheme.titleMedium), // Texte indiquant le chargement.
          ],
        ),
      ),
    );
  }
}

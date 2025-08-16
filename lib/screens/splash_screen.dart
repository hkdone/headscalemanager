import 'package:flutter/material.dart';
import 'package:headscalemanager/screens/home_screen.dart';
import 'package:headscalemanager/screens/settings_screen.dart';
import 'package:headscalemanager/services/storage_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkCredentials();
  }

  Future<void> _checkCredentials() async {
    final storage = StorageService();
    final hasCreds = await storage.hasCredentials();

    // Attendre un peu pour afficher l'écran de démarrage
    await Future.delayed(const Duration(seconds: 1));

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
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Chargement...'),
          ],
        ),
      ),
    );
  }
}
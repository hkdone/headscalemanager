import 'package:flutter/material.dart';
import 'package:headscalemanager/screens/acl_screen.dart';
import 'package:headscalemanager/screens/dashboard_screen.dart';
import 'package:headscalemanager/screens/settings_screen.dart';
import 'package:headscalemanager/screens/users_screen.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:headscalemanager/screens/help_screen.dart'; // Import pour l'écran d'aide

/// Écran d'accueil principal de l'application.
///
/// Gère la navigation entre les différents écrans de l'application
/// via une barre de navigation inférieure.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Index de l'élément actuellement sélectionné dans la barre de navigation inférieure.
  int _selectedIndex = 0;

  /// Liste des widgets (écrans) correspondant aux éléments de la barre de navigation.
  /// L'ordre doit correspondre à l'ordre des `BottomNavigationBarItem`.
  static const List<Widget> _widgetOptions = <Widget>[
    DashboardScreen(),
    UsersScreen(),
    AclScreen(),
  ];

  /// Gère le changement d'élément sélectionné dans la barre de navigation.
  ///
  /// Met à jour l'index sélectionné et reconstruit le widget pour afficher le nouvel écran.
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /// Barre d'application en haut de l'écran.
      appBar: AppBar(
        title: const Text('Gestionnaire Headscale'), // Titre de l'application
        actions: [
          // Bouton d'aide : navigue vers l'écran d'aide.
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpScreen()));
            },
          ),
          // Bouton des paramètres : navigue vers l'écran des paramètres.
          IconButton(
            icon: const Icon(EvaIcons.settings),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      /// Corps de l'écran, affichant le widget correspondant à l'élément sélectionné.
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      /// Barre de navigation inférieure.
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          // Élément pour le Tableau de Bord.
          BottomNavigationBarItem(
            icon: Icon(EvaIcons.layout),
            label: 'Tableau de bord',
          ),
          // Élément pour les Utilisateurs.
          BottomNavigationBarItem(
            icon: Icon(EvaIcons.people),
            label: 'Utilisateurs',
          ),
          // Élément pour les ACLs.
          BottomNavigationBarItem(
            icon: Icon(EvaIcons.shield),
            label: 'ACLs',
          ),
        ],
        currentIndex: _selectedIndex, // Index de l'élément actuellement actif.
        onTap: _onItemTapped, // Fonction appelée lors du tap sur un élément.
      ),
    );
  }
}
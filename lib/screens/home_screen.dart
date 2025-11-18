import 'package:flutter/material.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/screens/acl_screen.dart';
import 'package:headscalemanager/screens/dashboard_screen.dart';
import 'package:headscalemanager/screens/acl_manager_screen.dart';
import 'package:headscalemanager/screens/network_overview_screen.dart';
import 'package:headscalemanager/screens/settings_screen.dart';
import 'package:headscalemanager/screens/users_screen.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:headscalemanager/screens/help_screen.dart';
import 'package:provider/provider.dart'; // Import pour l'écran d'aide

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
    NetworkOverviewScreen(),
    AclManagerScreen(),
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
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return Scaffold(
      /// Barre d'application en haut de l'écran.
      appBar: AppBar(
        title: Text(isFr ? 'Gestionnaire Headscale' : 'Headscale Manager'),
        actions: [
          // Bouton d'aide : navigue vers l'écran d'aide.
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const HelpScreen()));
            },
          ),
          // Bouton des paramètres : navigue vers l'écran des paramètres.
          IconButton(
            icon: const Icon(EvaIcons.settings),
            onPressed: () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
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
        type: BottomNavigationBarType.fixed, // Force le style fixe
        backgroundColor: Theme.of(context).bottomAppBarTheme.color,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: <BottomNavigationBarItem>[
          // Élément pour le Tableau de Bord.
          BottomNavigationBarItem(
            icon: const Icon(EvaIcons.layout),
            label: isFr ? 'Tableau de bord' : 'Dashboard',
          ),
          // Élément pour les Utilisateurs.
          BottomNavigationBarItem(
            icon: const Icon(EvaIcons.people),
            label: isFr ? 'Utilisateurs' : 'Users',
          ),
          // Élément pour les ACLs.
          const BottomNavigationBarItem(
            icon: Icon(EvaIcons.shield),
            label: 'ACLs',
          ),
          // Élément pour la vue d'ensemble du réseau.
          BottomNavigationBarItem(
            icon: const Icon(EvaIcons.globe2Outline),
            label: isFr ? 'Réseau' : 'Network',
          ),
          // Élément pour le Gestionnaire d'ACL.
          BottomNavigationBarItem(
            icon: const Icon(EvaIcons.lockOutline),
            label: isFr ? 'Gestion ACL' : 'ACL Manager',
          ),
        ],
        currentIndex: _selectedIndex, // Index de l'élément actuellement actif.
        onTap: _onItemTapped, // Fonction appelée lors du tap sur un élément.
      ),
    );
  }
}

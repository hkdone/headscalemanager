import 'package:flutter/material.dart';
import 'package:headscalemanager/screens/acl_screen.dart';
import 'package:headscalemanager/screens/dashboard_screen.dart';
import 'package:headscalemanager/screens/settings_screen.dart';
import 'package:headscalemanager/screens/users_screen.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:headscalemanager/screens/help_screen.dart'; // New import for HelpScreen

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    DashboardScreen(),
    UsersScreen(),
    AclScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionnaire Headscale'),
        actions: [
          // Bouton d'aide
          IconButton(
            icon: const Icon(Icons.help_outline), // Using Material Icons for simplicity
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpScreen()));
            },
          ),
          // Bouton des paramètres
          IconButton(
            icon: const Icon(EvaIcons.settings),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(EvaIcons.layout),
            label: 'Tableau de bord',
          ),
          BottomNavigationBarItem(
            icon: Icon(EvaIcons.people),
            label: 'Utilisateurs',
          ),
          BottomNavigationBarItem(
            icon: Icon(EvaIcons.shield),
            label: 'ACLs',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
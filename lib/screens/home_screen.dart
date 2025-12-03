import 'package:flutter/material.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/screens/acl_screen.dart';
import 'package:headscalemanager/screens/dashboard_screen.dart';
import 'package:headscalemanager/screens/network_overview_screen.dart';
import 'package:headscalemanager/screens/settings_screen.dart';
import 'package:headscalemanager/screens/users_screen.dart';
import 'package:headscalemanager/screens/dns_screen.dart';
import 'package:eva_icons_flutter/eva_icons_flutter.dart';
import 'package:headscalemanager/screens/help_screen.dart';
import 'package:headscalemanager/screens/help_screen_en.dart';
import 'package:provider/provider.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';

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
    NetworkOverviewScreen(),
    DnsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    final titles = [
      isFr ? 'Tableau de bord' : 'Dashboard',
      isFr ? 'Utilisateurs' : 'Users',
      'ACLs',
      isFr ? 'Réseau' : 'Network',
      'DNS',
    ];

    final items = <Widget>[
      Icon(EvaIcons.layout, size: 30, color: theme.colorScheme.onPrimary),
      Icon(EvaIcons.people, size: 30, color: theme.colorScheme.onPrimary),
      Icon(EvaIcons.shield, size: 30, color: theme.colorScheme.onPrimary),
      Icon(EvaIcons.globe2Outline,
          size: 30, color: theme.colorScheme.onPrimary),
      Icon(Icons.dns_rounded, size: 30, color: theme.colorScheme.onPrimary),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline, color: theme.colorScheme.primary),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      isFr ? const HelpScreen() : const HelpScreenEn()));
            },
          ),
          IconButton(
            icon: Icon(EvaIcons.settings, color: theme.colorScheme.primary),
            onPressed: () {
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: SafeArea(
        top: false,
        child: CurvedNavigationBar(
          index: _selectedIndex,
          height: 60.0,
          items: items,
          color: theme.colorScheme.primary,
          buttonBackgroundColor: theme.colorScheme.primary,
          backgroundColor: theme.scaffoldBackgroundColor,
          animationCurve: Curves.easeInOut,
          animationDuration: const Duration(milliseconds: 400),
          onTap: _onItemTapped,
          letIndexChange: (index) => true,
        ),
      ),
    );
  }
}

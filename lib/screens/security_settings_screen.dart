import 'package:flutter/material.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/security_service.dart';
import 'package:headscalemanager/screens/setup_pin_screen.dart';
import 'package:provider/provider.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  _SecuritySettingsScreenState createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final _securityService = SecurityService();
  bool _isPinConfigured = false;
  bool _biometricsEnabled = false;
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final isPinConfigured = await _securityService.isPinConfigured();
    final biometricsEnabled = await _securityService.isBiometricsEnabled();
    final canCheckBiometrics = await _securityService.canCheckBiometrics();
    if (mounted) {
      setState(() {
        _isPinConfigured = isPinConfigured;
        _biometricsEnabled = biometricsEnabled;
        _canCheckBiometrics = canCheckBiometrics;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return Scaffold(
      appBar: AppBar(
        title: Text(isFr ? 'Sécurité de l\'application' : 'App Security'),
        backgroundColor: theme.appBarTheme.backgroundColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            title: Text(isFr ? 'Gérer le code PIN' : 'Manage PIN Code'),
            subtitle: Text(_isPinConfigured
                ? (isFr
                    ? 'Un code PIN est configuré.'
                    : 'A PIN code is configured.')
                : (isFr
                    ? 'Aucun code PIN configuré.'
                    : 'No PIN code configured.')),
            leading: const Icon(Icons.pin),
            onTap: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SetupPinScreen()),
              );
              if (result == true) {
                _loadSettings();
              }
            },
          ),
          const Divider(),
          SwitchListTile(
            title: Text(isFr
                ? 'Activer l\'authentification biométrique'
                : 'Enable Biometric Authentication'),
            subtitle: Text(_canCheckBiometrics
                ? (isFr
                    ? 'Utiliser l\'empreinte digitale ou la reconnaissance faciale.'
                    : 'Use fingerprint or face recognition.')
                : (isFr
                    ? 'Aucun capteur biométrique compatible trouvé.'
                    : 'No compatible biometric sensor found.')),
            value: _biometricsEnabled,
            secondary: const Icon(Icons.fingerprint),
            onChanged: (_isPinConfigured && _canCheckBiometrics)
                ? (bool value) async {
                    await _securityService.saveBiometricsEnabled(value);
                    setState(() {
                      _biometricsEnabled = value;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(isFr
                              ? 'Authentification biométrique ${value ? "activée" : "désactivée"}.'
                              : 'Biometric authentication ${value ? "enabled" : "disabled"}.')),
                    );
                  }
                : null,
          ),
          if (!_isPinConfigured)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 16.0, right: 16.0),
              child: Text(
                isFr
                    ? 'Vous devez configurer un code PIN avant de pouvoir activer l\'authentification biométrique.'
                    : 'You must set up a PIN before you can enable biometric authentication.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: theme.disabledColor),
              ),
            ),
        ],
      ),
    );
  }
}

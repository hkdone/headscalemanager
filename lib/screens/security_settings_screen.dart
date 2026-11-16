import 'package:flutter/material.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/security_service.dart';
import 'package:headscalemanager/screens/setup_pin_screen.dart';
import 'package:provider/provider.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final _securityService = SecurityService();
  bool _isPinConfigured = false;
  bool _biometricsEnabled = false;
  bool _canCheckBiometrics = false;
  int _autoLockMinutes = SecurityService.defaultAutoLockMinutes;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final isPinConfigured = await _securityService.isPinConfigured();
    final biometricsEnabled = await _securityService.isBiometricsEnabled();
    final canCheckBiometrics = await _securityService.canCheckBiometrics();
    final autoLockMinutes = await _securityService.getAutoLockMinutes();
    if (mounted) {
      setState(() {
        _isPinConfigured = isPinConfigured;
        _biometricsEnabled = biometricsEnabled;
        _canCheckBiometrics = canCheckBiometrics;
        _autoLockMinutes = autoLockMinutes;
      });
    }
  }

  String _autoLockLabel(int minutes, bool isFr) {
    switch (minutes) {
      case 0:
        return isFr ? 'Immédiat' : 'Immediate';
      case 1:
        return isFr ? 'Après 1 minute' : 'After 1 minute';
      case 5:
        return isFr ? 'Après 5 minutes' : 'After 5 minutes';
      case -1:
        return isFr ? 'Au démarrage uniquement' : 'On app restart only';
      default:
        return isFr ? 'Après $minutes minutes' : 'After $minutes minutes';
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
                    ? 'Un code PIN est configuré (PBKDF2 sécurisé).'
                    : 'A PIN code is configured (PBKDF2 secured).')
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
                    try {
                      await _securityService.saveBiometricsEnabled(value);
                      if (!context.mounted) return;
                      setState(() {
                        _biometricsEnabled = value;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(isFr
                                ? 'Authentification biométrique ${value ? "activée" : "désactivée"}.'
                                : 'Biometric authentication ${value ? "enabled" : "disabled"}.')),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isFr ? 'Erreur : $e' : 'Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                : null,
          ),
          const Divider(),
          ListTile(
            enabled: _isPinConfigured,
            leading: const Icon(Icons.lock_clock),
            title: Text(isFr
                ? 'Verrouillage automatique (arrière-plan)'
                : 'Auto-lock (background)'),
            subtitle: Text(_autoLockLabel(_autoLockMinutes, isFr)),
            trailing: DropdownButton<int>(
              value: const [0, 1, 5, -1].contains(_autoLockMinutes)
                  ? _autoLockMinutes
                  : 5,
              onChanged: _isPinConfigured
                  ? (int? newValue) async {
                      if (newValue == null) return;
                      await _securityService.saveAutoLockMinutes(newValue);
                      if (!mounted) return;
                      setState(() {
                        _autoLockMinutes = newValue;
                      });
                    }
                  : null,
              items: [
                DropdownMenuItem(
                    value: 0, child: Text(_autoLockLabel(0, isFr))),
                DropdownMenuItem(
                    value: 1, child: Text(_autoLockLabel(1, isFr))),
                DropdownMenuItem(
                    value: 5, child: Text(_autoLockLabel(5, isFr))),
                DropdownMenuItem(
                    value: -1, child: Text(_autoLockLabel(-1, isFr))),
              ],
            ),
          ),
          if (!_isPinConfigured)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 16.0, right: 16.0),
              child: Text(
                isFr
                    ? 'Vous devez configurer un code PIN avant de pouvoir activer l\'authentification biométrique ou le verrouillage automatique.'
                    : 'You must set up a PIN before you can enable biometric authentication or auto-lock.',
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

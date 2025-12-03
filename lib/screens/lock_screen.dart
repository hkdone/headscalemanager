import 'package:flutter/material.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/screens/home_screen.dart';
import 'package:headscalemanager/services/security_service.dart';
import 'package:headscalemanager/widgets/numpad_widget.dart';
import 'package:provider/provider.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({Key? key}) : super(key: key);

  @override
  _LockScreenState createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _securityService = SecurityService();
  String _enteredPin = '';
  String _message = ''; // Will be set in didChangeDependencies
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    // Wait for the first frame to be rendered before showing biometric prompt
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryBiometricAuth();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set initial message here to access context
    final isFr = context.watch<AppProvider>().locale.languageCode == 'fr';
    if (_message.isEmpty) {
      setState(() {
        _message = isFr ? 'Entrez votre code PIN' : 'Enter your PIN';
      });
    }
  }

  Future<void> _tryBiometricAuth() async {
    final isFr = context.read<AppProvider>().locale.languageCode == 'fr';
    final biometricsEnabled = await _securityService.isBiometricsEnabled();
    if (biometricsEnabled) {
      final isAuthenticated = await _securityService.authenticate(isFr
          ? 'Veuillez vous authentifier pour déverrouiller'
          : 'Please authenticate to unlock');
      if (mounted && isAuthenticated) {
        _unlockApp();
      }
    }
  }

  void _onNumberPressed(String number) {
    if (_isAuthenticating) return;
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += number;
      });
      if (_enteredPin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onDeletePressed() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  void _verifyPin() async {
    setState(() {
      _isAuthenticating = true;
    });
    final isValid = await _securityService.verifyPin(_enteredPin);

    if (!mounted) return;

    if (isValid) {
      _unlockApp();
    } else {
      final isFr = context.read<AppProvider>().locale.languageCode == 'fr';
      setState(() {
        _enteredPin = '';
        _message = isFr ? 'Code PIN incorrect' : 'Incorrect PIN';
        _isAuthenticating = false;
      });
    }
  }

  void _unlockApp() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Icon(Icons.lock_outline, size: 60, color: theme.colorScheme.primary),
          const SizedBox(height: 20),
          Text(_message, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index < _enteredPin.length
                      ? theme.colorScheme.primary
                      : theme.disabledColor,
                ),
              );
            }),
          ),
          if (_isAuthenticating)
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: CircularProgressIndicator(),
            )
          else
            const SizedBox(
                height: 20.0 + 24.0), // Match height of indicator + padding
          const Spacer(),
          NumpadWidget(
            onNumberPressed: _onNumberPressed,
            onDeletePressed: _onDeletePressed,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

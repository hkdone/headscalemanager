import 'dart:async';
import 'package:flutter/material.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/screens/home_screen.dart';
import 'package:headscalemanager/services/security_service.dart';
import 'package:headscalemanager/widgets/numpad_widget.dart';
import 'package:provider/provider.dart';

class LockScreen extends StatefulWidget {
  /// Si `true`, ferme simplement la route modale au déverrouillage (reprise arrière-plan).
  /// Si `false`, remplace toute la pile par [HomeScreen] (démarrage initial).
  final bool popOnUnlock;

  const LockScreen({super.key, this.popOnUnlock = false});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _securityService = SecurityService();
  String _enteredPin = '';
  String _message = '';
  bool _isAuthenticating = false;
  int _pinLength = 4;
  Duration _lockoutRemaining = Duration.zero;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    _initLockState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryBiometricAuth();
    });
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _initLockState() async {
    final len = await _securityService.getPinLength();
    final remaining = await _securityService.getRemainingLockout();
    if (!mounted) return;
    setState(() {
      _pinLength = len;
      _lockoutRemaining = remaining;
    });
    if (remaining > Duration.zero) {
      _startLockoutTimer();
    }
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final remaining = await _securityService.getRemainingLockout();
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _lockoutRemaining = remaining;
      });
      if (remaining <= Duration.zero) {
        timer.cancel();
        final isFr = context.read<AppProvider>().locale.languageCode == 'fr';
        setState(() {
          _message = isFr ? 'Entrez votre code PIN' : 'Enter your PIN';
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isFr = context.watch<AppProvider>().locale.languageCode == 'fr';
    if (_message.isEmpty) {
      _message = isFr ? 'Entrez votre code PIN' : 'Enter your PIN';
    }
  }

  Future<void> _tryBiometricAuth() async {
    if (_lockoutRemaining > Duration.zero) return;
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
    if (_isAuthenticating || _lockoutRemaining > Duration.zero) return;
    if (_enteredPin.length < _pinLength) {
      setState(() {
        _enteredPin += number;
      });
      if (_enteredPin.length == _pinLength) {
        _verifyPin();
      }
    }
  }

  void _onDeletePressed() {
    if (_isAuthenticating || _lockoutRemaining > Duration.zero) return;
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  Future<void> _verifyPin() async {
    setState(() {
      _isAuthenticating = true;
    });
    final isValid = await _securityService.verifyPin(_enteredPin);

    if (!mounted) return;

    if (isValid) {
      _unlockApp();
      return;
    }

    final remaining = await _securityService.getRemainingLockout();
    final attempts = await _securityService.getFailedAttempts();
    if (!mounted) return;

    final isFr = context.read<AppProvider>().locale.languageCode == 'fr';
    setState(() {
      _enteredPin = '';
      _isAuthenticating = false;
      _lockoutRemaining = remaining;
      if (remaining > Duration.zero) {
        _message = isFr
            ? 'Trop de tentatives. Patientez.'
            : 'Too many attempts. Please wait.';
      } else {
        _message = isFr
            ? 'Code PIN incorrect ($attempts)'
            : 'Incorrect PIN ($attempts)';
      }
    });

    if (remaining > Duration.zero) {
      _startLockoutTimer();
    }
  }

  void _unlockApp() {
    if (widget.popOnUnlock) {
      Navigator.of(context).pop(true);
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  String _formatDuration(Duration d) {
    final secs = d.inSeconds;
    final min = secs ~/ 60;
    final rem = secs % 60;
    if (min > 0) {
      return '${min}m ${rem.toString().padLeft(2, '0')}s';
    }
    return '${rem}s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFr = context.watch<AppProvider>().locale.languageCode == 'fr';
    final isLockedOut = _lockoutRemaining > Duration.zero;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Icon(
                isLockedOut ? Icons.timer_outlined : Icons.lock_outline,
                size: 60,
                color: isLockedOut
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                _message,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              if (isLockedOut) ...[
                const SizedBox(height: 8),
                Text(
                  isFr
                      ? 'Nouvel essai dans ${_formatDuration(_lockoutRemaining)}'
                      : 'Retry in ${_formatDuration(_lockoutRemaining)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pinLength, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: _pinLength > 4 ? 18 : 24,
                    height: _pinLength > 4 ? 18 : 24,
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
                const SizedBox(height: 44.0),
              const Spacer(),
              IgnorePointer(
                ignoring: isLockedOut || _isAuthenticating,
                child: Opacity(
                  opacity: isLockedOut ? 0.4 : 1.0,
                  child: NumpadWidget(
                    onNumberPressed: _onNumberPressed,
                    onDeletePressed: _onDeletePressed,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

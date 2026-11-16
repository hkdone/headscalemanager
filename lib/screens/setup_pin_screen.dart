import 'package:flutter/material.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/security_service.dart';
import 'package:headscalemanager/widgets/numpad_widget.dart';
import 'package:provider/provider.dart';

class SetupPinScreen extends StatefulWidget {
  const SetupPinScreen({super.key});

  @override
  State<SetupPinScreen> createState() => _SetupPinScreenState();
}

class _SetupPinScreenState extends State<SetupPinScreen> {
  final _securityService = SecurityService();

  String _enteredPin = '';
  String _firstPin = '';
  bool _isConfirming = false;
  int _pinLength = 4;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _loadCurrentLength();
  }

  Future<void> _loadCurrentLength() async {
    final len = await _securityService.getPinLength();
    if (!mounted) return;
    setState(() {
      _pinLength = len == 6 ? 6 : 4;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isFr = context.watch<AppProvider>().locale.languageCode == 'fr';
    if (_message.isEmpty) {
      _message = isFr ? 'Créez votre code PIN' : 'Create your PIN';
    }
  }

  void _onNumberPressed(String number) {
    if (_enteredPin.length < _pinLength) {
      setState(() {
        _enteredPin += number;
      });
      if (_enteredPin.length == _pinLength) {
        Future.delayed(const Duration(milliseconds: 200), _submitPin);
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

  Future<void> _submitPin() async {
    final isFr = context.read<AppProvider>().locale.languageCode == 'fr';
    if (!_isConfirming) {
      setState(() {
        _firstPin = _enteredPin;
        _enteredPin = '';
        _isConfirming = true;
        _message = isFr ? 'Confirmez votre code PIN' : 'Confirm your PIN';
      });
    } else {
      if (_firstPin == _enteredPin) {
        try {
          await _securityService.savePin(_enteredPin);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isFr
                  ? 'Code PIN enregistré avec succès !'
                  : 'PIN saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isFr
                  ? 'Erreur lors de la sauvegarde du PIN : $e'
                  : 'Error saving PIN: $e'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _enteredPin = '';
            _firstPin = '';
            _isConfirming = false;
            _message = isFr ? 'Créez votre code PIN' : 'Create your PIN';
          });
        }
      } else {
        setState(() {
          _enteredPin = '';
          _firstPin = '';
          _isConfirming = false;
          _message = isFr
              ? 'Les codes ne correspondent pas. Réessayez.'
              : 'PINs do not match. Try again.';
        });
      }
    }
  }

  Future<void> _clearPin() async {
    final isFr = context.read<AppProvider>().locale.languageCode == 'fr';
    try {
      await _securityService.clearPin();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFr ? 'Code PIN supprimé.' : 'PIN deleted.'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isFr
              ? 'Erreur lors de la suppression : $e'
              : 'Error deleting PIN: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFr = context.watch<AppProvider>().locale.languageCode == 'fr';

    return Scaffold(
      appBar: AppBar(
        title: Text(isFr ? 'Configurer le code PIN' : 'Set up PIN Code'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        actions: [
          TextButton(
            onPressed: _clearPin,
            child: Text(isFr ? 'Supprimer' : 'Delete',
                style:
                    TextStyle(color: theme.appBarTheme.titleTextStyle?.color)),
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            if (!_isConfirming)
              SegmentedButton<int>(
                segments: [
                  ButtonSegment<int>(
                    value: 4,
                    label: Text(isFr ? '4 chiffres' : '4 digits'),
                  ),
                  ButtonSegment<int>(
                    value: 6,
                    label: Text(isFr ? '6 chiffres' : '6 digits'),
                  ),
                ],
                selected: {_pinLength},
                onSelectionChanged: (sel) {
                  setState(() {
                    _pinLength = sel.first;
                    _enteredPin = '';
                  });
                },
              ),
            const Spacer(),
            Text(_message, style: theme.textTheme.headlineSmall),
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
            const Spacer(),
            NumpadWidget(
              onNumberPressed: _onNumberPressed,
              onDeletePressed: _onDeletePressed,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

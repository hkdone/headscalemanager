import 'package:flutter/material.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/security_service.dart';
import 'package:headscalemanager/widgets/numpad_widget.dart';
import 'package:provider/provider.dart';

class SetupPinScreen extends StatefulWidget {
  const SetupPinScreen({Key? key}) : super(key: key);

  @override
  _SetupPinScreenState createState() => _SetupPinScreenState();
}

class _SetupPinScreenState extends State<SetupPinScreen> {
  final _securityService = SecurityService();

  String _enteredPin = '';
  String _firstPin = '';
  bool _isConfirming = false;
  String _message = ''; // Will be set in didChangeDependencies

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set initial message here to access context
    final isFr = context.watch<AppProvider>().locale.languageCode == 'fr';
    setState(() {
      _message = isFr ? 'Créez votre code PIN' : 'Create your PIN';
    });
  }

  void _onNumberPressed(String number) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += number;
      });
      if (_enteredPin.length == 4) {
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

  void _submitPin() async {
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
        await _securityService.savePin(_enteredPin);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFr
                ? 'Code PIN enregistré avec succès !'
                : 'PIN saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
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

  void _clearPin() async {
    final isFr = context.read<AppProvider>().locale.languageCode == 'fr';
    await _securityService.clearPin();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isFr ? 'Code PIN supprimé.' : 'PIN deleted.'),
        backgroundColor: Colors.red,
      ),
    );
    Navigator.of(context).pop(true);
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
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
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

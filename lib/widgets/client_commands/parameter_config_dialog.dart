import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headscalemanager/models/client_command.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

// Dialogue de configuration des paramètres
class ParameterConfigDialog extends StatefulWidget {
  final ClientCommand command;
  final String platform;
  final bool isFr;

  const ParameterConfigDialog({
    super.key,
    required this.command,
    required this.platform,
    required this.isFr,
  });

  @override
  State<ParameterConfigDialog> createState() => _ParameterConfigDialogState();
}

class _ParameterConfigDialogState extends State<ParameterConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _parameterValues = {};
  final Map<String, bool> _booleanValues = {};
  String? _generatedCommand;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeParameters();
  }

  void _initializeParameters() async {
    final appProvider = context.read<AppProvider>();
    final serverUrl = await appProvider.storageService.getServerUrl() ?? '';

    if (widget.command.parameters == null) return;

    for (var param in widget.command.parameters!) {
      if (param.type == ParameterType.boolean) {
        _booleanValues[param.id] = param.defaultValue?.toLowerCase() == 'true';
      } else {
        String initialValue = param.defaultValue ?? '';
        if (param.id == 'server_url' && initialValue.isEmpty) {
          initialValue = serverUrl;
        }

        _controllers[param.id] = TextEditingController(text: initialValue);
        _parameterValues[param.id] = initialValue;
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _generateCommand() {
    if (_formKey.currentState?.validate() ?? false) {
      final allValues = <String, String>{};

      _controllers.forEach((key, controller) {
        allValues[key] = controller.text;
      });

      _booleanValues.forEach((key, value) {
        allValues[key] = value.toString();
      });

      // La logique de génération est maintenant dans le modèle
      final generated =
          widget.command.generateCommand(widget.platform, allValues);

      setState(() {
        _generatedCommand = generated;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _copyToClipboard(String command) {
    Clipboard.setData(ClipboardData(text: command));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.isFr
              ? 'Commande copiée dans le presse-papiers'
              : 'Command copied to clipboard',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareCommand(String command) {
    Share.share(command,
        subject: 'Commande Tailscale: ${widget.command.title}');
  }

  Widget _buildParameterField(CommandParameter param) {
    switch (param.type) {
      case ParameterType.boolean:
        return CheckboxListTile(
          title: Text(param.label),
          subtitle: Text(param.description),
          value: _booleanValues[param.id] ?? false,
          onChanged: (value) {
            setState(() {
              _booleanValues[param.id] = value ?? false;
            });
          },
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        );

      case ParameterType.nodeSelect:
      case ParameterType.authKeySelect:
        if (param.options != null && param.options!.isNotEmpty) {
          return DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: param.label,
              hintText: param.placeholder,
              border: const OutlineInputBorder(),
            ),
            value: _controllers[param.id]?.text.isNotEmpty == true
                ? _controllers[param.id]?.text
                : null,
            items: param.options!.map((option) {
              return DropdownMenuItem(
                value: option,
                child: Text(option, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _controllers[param.id]?.text = value ?? '';
                _parameterValues[param.id] = value ?? '';
              });
            },
            isExpanded: true,
          );
        }
        return _buildTextField(param);

      default:
        return _buildTextField(param);
    }
  }

  Widget _buildTextField(CommandParameter param) {
    return TextFormField(
      controller: _controllers[param.id],
      decoration: InputDecoration(
        labelText: param.label,
        hintText: param.placeholder,
        helperText: param.description,
        border: const OutlineInputBorder(),
        suffixIcon: param.required
            ? const Icon(Icons.star, color: Colors.red, size: 12)
            : null,
      ),
      keyboardType: param.type == ParameterType.number
          ? TextInputType.number
          : param.type == ParameterType.ipAddress
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
      validator: (value) {
        if (param.required && (value == null || value.isEmpty)) {
          return widget.isFr ? 'Ce champ est requis' : 'This field is required';
        }

        if (value != null && value.isNotEmpty && param.validation != null) {
          final regex = RegExp(param.validation!);
          if (!regex.hasMatch(value)) {
            return widget.isFr ? 'Format invalide' : 'Invalid format';
          }
        }

        return null;
      },
      onChanged: (value) {
        _parameterValues[param.id] = value;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.isFr ? 'Configurer les paramètres' : 'Configure Parameters',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.command.title,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.command.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (widget.command.parameters != null)
                  ...widget.command.parameters!.map((param) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildParameterField(param),
                      )),
                if (_generatedCommand != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    widget.isFr ? 'Commande Générée' : 'Generated Command',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      _generatedCommand!,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _shareCommand(_generatedCommand!),
                        icon: const Icon(Icons.share, size: 16),
                        label: Text(widget.isFr ? 'Partager' : 'Share'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _copyToClipboard(_generatedCommand!),
                        icon: const Icon(Icons.copy, size: 16),
                        label: Text(widget.isFr ? 'Copier' : 'Copy'),
                      ),
                    ],
                  )
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.isFr ? 'Fermer' : 'Close'),
        ),
        ElevatedButton.icon(
          onPressed: _generateCommand,
          icon: const Icon(Icons.build_circle_outlined),
          label: Text(widget.isFr ? 'Générer' : 'Generate'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

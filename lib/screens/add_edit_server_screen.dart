import 'package:flutter/material.dart';
import 'package:headscalemanager/models/server.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:provider/provider.dart';

class AddEditServerScreen extends StatefulWidget {
  final Server? server;

  const AddEditServerScreen({super.key, this.server});

  @override
  State<AddEditServerScreen> createState() => _AddEditServerScreenState();
}

class _AddEditServerScreenState extends State<AddEditServerScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _urlController;
  late TextEditingController _apiKeyController;
  bool _obscureApiKey = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.server?.name ?? '');
    _urlController = TextEditingController(text: widget.server?.url ?? '');
    _apiKeyController =
        TextEditingController(text: widget.server?.apiKey ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFr = context.watch<AppProvider>().locale.languageCode == 'fr';
    final isEditing = widget.server != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? (isFr ? 'Modifier le serveur' : 'Edit Server')
              : (isFr ? 'Ajouter un serveur' : 'Add Server'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: isFr ? 'Nom du serveur' : 'Server Name',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return isFr
                        ? 'Veuillez entrer un nom'
                        : 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: isFr ? 'URL du serveur' : 'Server URL',
                ),
                validator: (value) {
                  if (value == null ||
                      value.isEmpty ||
                      !Uri.parse(value).isAbsolute) {
                    return isFr
                        ? 'Veuillez entrer une URL valide'
                        : 'Please enter a valid URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _apiKeyController,
                obscureText: _obscureApiKey,
                decoration: InputDecoration(
                  labelText: isFr ? 'Clé API' : 'API Key',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureApiKey ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureApiKey = !_obscureApiKey;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return isFr
                        ? 'Veuillez entrer une clé API'
                        : 'Please enter an API key';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveServer,
                child: Text(isFr ? 'Enregistrer' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveServer() {
    if (_formKey.currentState!.validate()) {
      final appProvider = context.read<AppProvider>();
      final name = _nameController.text.trim();
      final url = _urlController.text.trim();
      final apiKey = _apiKeyController.text.trim();

      if (widget.server == null) {
        final newServer = Server(name: name, url: url, apiKey: apiKey);
        appProvider.addServer(newServer);
      } else {
        final updatedServer = Server(
          id: widget.server!.id,
          name: name,
          url: url,
          apiKey: apiKey,
        );
        appProvider.updateServer(updatedServer);
      }
      Navigator.of(context).pop();
    }
  }
}

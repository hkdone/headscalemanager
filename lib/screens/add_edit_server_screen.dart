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

  bool _isCleartextRemoteHttp(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || uri.scheme.toLowerCase() != 'http') return false;
    final host = uri.host.toLowerCase();
    if (host.isEmpty) return false;
    if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
      return false;
    }
    if (host.endsWith('.local') || host.endsWith('.internal')) {
      return false;
    }
    // IP privées RFC1918 & CGNAT Tailscale (100.64.0.0/10)
    final parts = host.split('.');
    if (parts.length == 4) {
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      if (a != null && b != null) {
        if (a == 10) return false;
        if (a == 192 && b == 168) return false;
        if (a == 172 && b >= 16 && b <= 31) return false;
        if (a == 100 && b >= 64 && b <= 127) return false;
      }
    }
    return true;
  }

  Future<bool> _confirmCleartextHttp(bool isFr, String url) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(isFr
                      ? 'Connexion HTTP non chiffrée'
                      : 'Unencrypted HTTP Connection'),
                ),
              ],
            ),
            content: Text(
              isFr
                  ? 'L\'URL "$url" utilise HTTP sans chiffrement TLS sur un hôte public.\n\nVotre clé API Headscale sera transmise en clair sur le réseau. Il est fortement recommandé d\'utiliser HTTPS.\n\nVoulez-vous vraiment continuer ?'
                  : 'The URL "$url" uses HTTP without TLS encryption on a public host.\n\nYour Headscale API key will be transmitted in cleartext over the network. HTTPS is strongly recommended.\n\nDo you really want to continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(isFr ? 'Annuler' : 'Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(isFr ? 'Continuer quand même' : 'Continue anyway'),
              ),
            ],
          ),
        ) ??
        false;
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
                  hintText: 'https://headscale.example.com',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return isFr
                        ? 'Veuillez entrer une URL valide'
                        : 'Please enter a valid URL';
                  }
                  final uri = Uri.tryParse(value.trim());
                  if (uri == null ||
                      !uri.isAbsolute ||
                      (uri.scheme != 'https' && uri.scheme != 'http')) {
                    return isFr
                        ? 'Veuillez entrer une URL HTTP(S) valide'
                        : 'Please enter a valid HTTP(S) URL';
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

  Future<void> _saveServer() async {
    if (!_formKey.currentState!.validate()) return;

    final appProvider = context.read<AppProvider>();
    final isFr = appProvider.locale.languageCode == 'fr';
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (_isCleartextRemoteHttp(url)) {
      final confirmed = await _confirmCleartextHttp(isFr, url);
      if (!confirmed || !mounted) return;
    }

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
    if (mounted) Navigator.of(context).pop();
  }
}

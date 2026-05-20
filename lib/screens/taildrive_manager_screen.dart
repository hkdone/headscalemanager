import 'package:flutter/material.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/taildrive_share.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:provider/provider.dart';

class TaildriveManagerScreen extends StatefulWidget {
  const TaildriveManagerScreen({super.key});

  @override
  State<TaildriveManagerScreen> createState() => _TaildriveManagerScreenState();
}

class _TaildriveManagerScreenState extends State<TaildriveManagerScreen> {
  bool _isLoading = true;
  List<Node> _allNodes = [];
  List<User> _allUsers = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final appProvider = context.read<AppProvider>();
      final apiService = appProvider.apiService;
      _allNodes = await apiService.getNodes();
      _allUsers = await apiService.getUsers();
    } catch (e) {
      debugPrint('Error fetching data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final isFr = appProvider.locale.languageCode == 'fr';
    final shares = appProvider.taildriveShares;

    return Scaffold(
      appBar: AppBar(
        title: Text(isFr ? 'Partages Taildrive' : 'Taildrive Shares'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : shares.isEmpty
              ? _buildEmptyState(isFr)
              : ListView.builder(
                  itemCount: shares.length,
                  itemBuilder: (context, index) {
                    final share = shares[index];
                    final sourceNode = _allNodes.firstWhere(
                      (n) => n.id == share.sourceNodeId,
                      orElse: () => Node(
                        id: '',
                        machineKey: '',
                        hostname: '',
                        name: isFr ? 'Nœud inconnu' : 'Unknown Node',
                        user: '',
                        userId: '',
                        ipAddresses: [],
                        online: false,
                        lastSeen: DateTime.now(),
                        sharedRoutes: [],
                        availableRoutes: [],
                        isExitNode: false,
                        isLanSharer: false,
                        tags: [],
                        baseDomain: '',
                        endpoint: '',
                      ),
                    );

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.folder, color: Colors.orange),
                        title: Text(share.shareName,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '${isFr ? 'Source' : 'Source'}: ${sourceNode.name}'),
                            Text(
                                '${isFr ? 'Bénéficiaire' : 'Recipient'}: ${share.recipient}'),
                            Text(
                                '${isFr ? 'Mode' : 'Mode'}: ${share.accessMode == TaildriveAccessMode.rw ? (isFr ? 'Lecture/Écriture' : 'Read/Write') : (isFr ? 'Lecture seule' : 'Read-only')}'),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDelete(share.id, isFr),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddShareDialog(isFr),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(bool isFr) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.folder_off_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            isFr ? 'Aucun partage configuré' : 'No shares configured',
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              isFr
                  ? 'Cliquez sur + pour créer votre premier partage de dossiers sécurisé.'
                  : 'Click + to create your first secure folder share.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(String shareId, bool isFr) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isFr ? 'Supprimer le partage' : 'Delete Share'),
        content: Text(isFr
            ? 'Êtes-vous sûr de vouloir supprimer ce partage ?'
            : 'Are you sure you want to delete this share?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isFr ? 'Annuler' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isFr ? 'Supprimer' : 'Delete',
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<AppProvider>().deleteTaildriveShare(shareId);
    }
  }

  void _showAddShareDialog(bool isFr) {
    showDialog(
      context: context,
      builder: (context) => _AddTaildriveShareDialog(
        allNodes: _allNodes,
        allUsers: _allUsers,
        isFr: isFr,
      ),
    );
  }
}

class _AddTaildriveShareDialog extends StatefulWidget {
  final List<Node> allNodes;
  final List<User> allUsers;
  final bool isFr;

  const _AddTaildriveShareDialog({
    required this.allNodes,
    required this.allUsers,
    required this.isFr,
  });

  @override
  State<_AddTaildriveShareDialog> createState() =>
      __AddTaildriveShareDialogState();
}

class __AddTaildriveShareDialogState extends State<_AddTaildriveShareDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _pathController = TextEditingController();
  Node? _selectedSourceNode;
  String? _selectedRecipient;
  TaildriveAccessMode _accessMode = TaildriveAccessMode.ro;

  List<String> _getAccessibleRecipients(Node sourceNode) {
    final recipients = <String>{};

    // 1. Same user (owner)
    recipients.add(sourceNode.user);

    // 2. Nodes/Users with explicit ACL rules (temporaryRules)
    // We can't easily parse all ACLs from here, but we can check the temporaryRules stored in Storage
    // However, Tailscale's standard is often to share with groups or specific users.
    // For simplicity and following user request: same user + manual check.

    // Let's also add all other users but we could mark them or filter them.
    // The user specifically asked to filter.
    // To filter perfectly, we'd need to simulate the ACL generator.

    // For now, let's include the source node's user and any other user that has a node
    // that the source node can see according to temporaryRules.
    // BUT temporaryRules are src/dst pairs.
    final appProvider = context.read<AppProvider>();
    // We need temporary rules. Let's assume we can get them or they are global.
    // Actually, they are in AclScreen state. This is tricky.
    // Let's load them from storage again.

    return recipients.toList();
  }

  // To properly implement the filter, I need the temporary rules.
  List<String> _filteredRecipients = [];

  @override
  void initState() {
    super.initState();
    _loadFilteredRecipients();
  }

  Future<void> _loadFilteredRecipients() async {
    final appProvider = context.read<AppProvider>();
    final serverId = appProvider.activeServer?.id;
    if (serverId == null) return;

    final rules = await appProvider.storageService.getTemporaryRules(serverId);

    setState(() {
      _updateRecipients(rules);
    });
  }

  void _updateRecipients(List<Map<String, dynamic>> rules) {
    if (_selectedSourceNode == null) {
      _filteredRecipients = [];
      return;
    }

    final accessibleUsers = <String>{};
    // 1. Toujours accessible pour soi-même (même utilisateur)
    accessibleUsers.add(_selectedSourceNode!.user);

    // 2. Analyser les règles spécifiques pour trouver d'autres bénéficiaires valides
    for (var rule in rules) {
      final src = rule['src'] as String;
      final dst = rule['dst'] as String;

      // On vérifie si la source du partage (notre nœud sélectionné) est concernée par cette règle
      bool isSourceInRule = false;
      
      // Match par utilisateur/groupe
      if (src == 'group:${_selectedSourceNode!.user}' || src == _selectedSourceNode!.user) {
        isSourceInRule = true;
      }
      // Match par IP
      for (var ip in _selectedSourceNode!.ipAddresses) {
        if (src.contains(ip)) {
          isSourceInRule = true;
          break;
        }
      }
      // Match par tag
      for (var tag in _selectedSourceNode!.tags) {
        if (src == tag) {
          isSourceInRule = true;
          break;
        }
      }

      if (isSourceInRule) {
        // Si notre nœud est la source de la règle, la destination est un bénéficiaire potentiel
        _addRecipientFromRuleTarget(dst, accessibleUsers);
      }

      // Comme les règles de tags sont bidirectionnelles dans notre générateur, 
      // on vérifie aussi si notre nœud est la destination de la règle
      bool isDestInRule = false;
      if (dst == 'group:${_selectedSourceNode!.user}' || dst == _selectedSourceNode!.user) {
        isDestInRule = true;
      }
      for (var ip in _selectedSourceNode!.ipAddresses) {
        if (dst.contains(ip)) {
          isDestInRule = true;
          break;
        }
      }
      for (var tag in _selectedSourceNode!.tags) {
        if (dst == tag) {
          isDestInRule = true;
          break;
        }
      }

      if (isDestInRule) {
        _addRecipientFromRuleTarget(src, accessibleUsers);
      }
    }

    // On transforme les noms d'utilisateurs en liste triée
    _filteredRecipients = accessibleUsers.toList();
    _filteredRecipients.sort((a, b) {
      if (a == _selectedSourceNode!.user) return -1;
      if (b == _selectedSourceNode!.user) return 1;
      return a.compareTo(b);
    });
  }

  void _addRecipientFromRuleTarget(String target, Set<String> recipients) {
    if (target.startsWith('group:')) {
      recipients.add(target.replaceFirst('group:', ''));
    } else if (target.startsWith('tag:')) {
      // Pour les tags, on cherche l'utilisateur propriétaire du tag
      for (var node in widget.allNodes) {
        if (node.tags.contains(target)) {
          recipients.add(node.user);
        }
      }
    } else {
      // Pour les IPs, on cherche le nœud correspondant
      for (var node in widget.allNodes) {
        for (var ip in node.ipAddresses) {
          if (target.contains(ip)) {
            recipients.add(node.user);
            break;
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isFr ? 'Ajouter un partage' : 'Add Share'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Node>(
                value: _selectedSourceNode,
                decoration: InputDecoration(
                  labelText: widget.isFr ? 'Nœud Source' : 'Source Node',
                ),
                items: widget.allNodes.map((n) {
                  return DropdownMenuItem(value: n, child: Text(n.name));
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedSourceNode = val;
                    _selectedRecipient = null;
                    _loadFilteredRecipients();
                  });
                },
                validator: (val) => val == null
                    ? (widget.isFr ? 'Obligatoire' : 'Required')
                    : null,
              ),
              const SizedBox(height: 16),
              if (_selectedSourceNode != null) ...[
                DropdownButtonFormField<String>(
                  value: _selectedRecipient,
                  decoration: InputDecoration(
                    labelText: widget.isFr ? 'Bénéficiaire' : 'Recipient',
                    helperText: widget.isFr
                        ? 'Utilisateurs autorisés à voir le partage'
                        : 'Users allowed to see the share',
                  ),
                  items: _filteredRecipients.map((u) {
                    final isSameUser = u == _selectedSourceNode!.user;
                    return DropdownMenuItem(
                      value: u,
                      child: Text(isSameUser ? '$u (${widget.isFr ? 'Propriétaire' : 'Owner'})' : u),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedRecipient = val),
                  validator: (val) => val == null
                      ? (widget.isFr ? 'Obligatoire' : 'Required')
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: widget.isFr ? 'Nom du partage' : 'Share Name',
                    hintText: 'ex: Documents',
                  ),
                  validator: (val) => val == null || val.isEmpty
                      ? (widget.isFr ? 'Obligatoire' : 'Required')
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _pathController,
                  decoration: InputDecoration(
                    labelText: widget.isFr ? 'Chemin local' : 'Local Path',
                    hintText: 'ex: /home/user/docs or C:\\Data',
                  ),
                  validator: (val) => val == null || val.isEmpty
                      ? (widget.isFr ? 'Obligatoire' : 'Required')
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<TaildriveAccessMode>(
                  value: _accessMode,
                  decoration: InputDecoration(
                    labelText: widget.isFr ? 'Permissions' : 'Permissions',
                  ),
                  items: [
                    DropdownMenuItem(
                      value: TaildriveAccessMode.ro,
                      child: Text(widget.isFr ? 'Lecture seule' : 'Read-only'),
                    ),
                    DropdownMenuItem(
                      value: TaildriveAccessMode.rw,
                      child: Text(widget.isFr ? 'Lecture/Écriture' : 'Read/Write'),
                    ),
                  ],
                  onChanged: (val) => setState(() => _accessMode = val!),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.isFr ? 'Annuler' : 'Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedSourceNode == null ? null : _handleSave,
          child: Text(widget.isFr ? 'Ajouter' : 'Add'),
        ),
      ],
    );
  }

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      final share = TaildriveShare(
        sourceNodeId: _selectedSourceNode!.id,
        shareName: _nameController.text.trim(),
        localPath: _pathController.text.trim(),
        recipient: _selectedRecipient!,
        accessMode: _accessMode,
      );

      context.read<AppProvider>().addTaildriveShare(share);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isFr
              ? 'Partage ajouté. N\'oubliez pas de régénérer la politique ACL.'
              : 'Share added. Don\'t forget to regenerate the ACL policy.'),
          action: SnackBarAction(
            label: widget.isFr ? 'ACL' : 'ACL',
            onPressed: () {
              // Navigation already handled by stack
            },
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pathController.dispose();
    super.dispose();
  }
}

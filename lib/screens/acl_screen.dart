import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:headscalemanager/models/acl_engine_mode.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/screens/acl_manager_screen.dart';
import 'package:headscalemanager/screens/taildrive_manager_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:headscalemanager/services/acl/acl_policy_orchestrator.dart';
import 'package:headscalemanager/widgets/shared_routes_access_dialog.dart';
import 'package:headscalemanager/utils/ip_utils.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/widgets/acl/acl_engine_banner.dart';
import 'package:headscalemanager/widgets/acl/acls_list_view.dart';
import 'package:headscalemanager/widgets/acl/grants_list_view.dart';
import 'package:headscalemanager/widgets/acl/policy_diff_dialog.dart';
import 'package:headscalemanager/services/acl/grant_composer_service.dart';
import 'package:headscalemanager/utils/grants_v29_gate.dart';
import 'package:headscalemanager/widgets/acl/grant_composer_sheet.dart';
import 'package:headscalemanager/widgets/acl/grant_edit_sheet.dart';
import 'package:headscalemanager/widgets/acl/grants_migration_banner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:headscalemanager/services/acl/policy_file_service.dart';
import 'package:headscalemanager/widgets/acl/acl_workflow_guide.dart';
import 'package:headscalemanager/screens/acl_puzzle_screen.dart';
import 'package:headscalemanager/services/acl/hujson_comment_service.dart';
import 'package:headscalemanager/services/acl/policy_orphan_cleaner.dart';
import 'package:headscalemanager/services/acl/policy_preserver.dart';
import 'package:headscalemanager/services/acl_parser_service.dart';
import 'package:headscalemanager/services/security_service.dart';
import 'package:headscalemanager/utils/json_utils.dart';
import 'package:headscalemanager/utils/tag_capability_helper.dart';
import 'package:headscalemanager/models/version_info.dart';
import 'package:headscalemanager/widgets/acl/acl_simulator_sheet.dart';
import 'package:headscalemanager/widgets/acl/alignment_assistant_dialog.dart';
import 'package:headscalemanager/widgets/acl/ssh_rules_list_view.dart';

class AclScreen extends StatefulWidget {
  const AclScreen({super.key});

  @override
  State<AclScreen> createState() => _AclScreenState();
}

class _AclScreenState extends State<AclScreen> {
  final TextEditingController _aclController = TextEditingController();
  bool _isLoading = true;
  Map<String, dynamic> _currentAclPolicy = {};
  final AclPolicyOrchestrator _aclOrchestrator = AclPolicyOrchestrator();

  List<Node> _allNodes = [];
  List<User> _users = [];
  Map<String, dynamic> _serverPolicySnapshot = {};
  String _serverRawPolicyText = '';
  Map<String, String> _knownRuleComments = {};
  String? _leadingComments;
  List<Node> _destinationNodes = [];
  Node? _selectedSourceNode;
  Node? _selectedDestinationNode;
  final TextEditingController _portController = TextEditingController();
  final List<Map<String, dynamic>> _temporaryRules = [];
  final List<Map<String, dynamic>> _pendingRemovedTempRules = [];
  String _selectedProtocol = 'any'; // 'any', 'tcp', 'udp'
  String? _activeServerId;
  AclEngineMode? _lastAclEngineMode;
  bool _isLocalDraft = false;
  String? _jsonParseError;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appProvider = context.watch<AppProvider>();
    bool shouldReload = false;

    if (_activeServerId != appProvider.activeServer?.id) {
      _activeServerId = appProvider.activeServer?.id;
      shouldReload = true;
    }

    if (_lastAclEngineMode != appProvider.aclEngineMode) {
      _lastAclEngineMode = appProvider.aclEngineMode;
      shouldReload = true;
    }

    if (shouldReload) {
      _loadInitialData();
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final appProvider = context.read<AppProvider>();
    final storage = appProvider.storageService;
    final serverId = appProvider.activeServer?.id;

    if (serverId == null) {
      setState(() {
        _isLoading = false;
        // Handle error: no active server
      });
      return;
    }

    await _fetchNodes();
    final loadedRules = await storage.getTemporaryRules(serverId);
    if (!mounted) return;
    setState(() {
      _temporaryRules.clear();
      _temporaryRules.addAll(loadedRules);
    });

    // Charger la politique réellement active sur le serveur pour éviter toute
    // désynchronisation entre l'onglet Grants, ACLs, JSON et Headscale.
    try {
      final apiService = appProvider.apiService;
      if (_users.isEmpty) {
        _users = await apiService.getUsers();
      }
      final bundle =
          await PolicyPreserver.fetchServerPolicyBundleSafely(apiService);
      if (!mounted) return;
      final serverPolicy = bundle.policy;
      if (serverPolicy != null && serverPolicy.isNotEmpty) {
        _serverPolicySnapshot = PolicyPreserver.deepCopyMap(serverPolicy);
        _currentAclPolicy = PolicyPreserver.deepCopyMap(serverPolicy);
        _serverRawPolicyText = bundle.rawText;
        _knownRuleComments = Map<String, String>.from(bundle.ruleComments);
        _leadingComments = bundle.leadingComments;
        _jsonParseError = null;
        _isLocalDraft = false;
        _setRawPolicyControllerText(bundle.rawText);
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    } catch (e) {
      debugPrint('AclScreen._loadInitialData fetch server policy fallback: $e');
    }

    if (!mounted) return;
    await _generateNewAclPolicy(showSnackbar: false);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchNodes() async {
    try {
      final apiService = context.read<AppProvider>().apiService;
      _allNodes = await apiService.getNodes();
      _destinationNodes = List.from(_allNodes);
    } catch (e) {
      debugPrint('Error fetching nodes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch nodes: $e')),
        );
      }
    }
  }

  void _updateAclControllerText() {
    _aclController.text = HuJsonCommentService.formatPolicyWithComments(
      _currentAclPolicy,
      ruleComments: _knownRuleComments,
      leadingComments: _leadingComments,
    );
    if (mounted) {
      setState(() {});
    }
  }

  void _setRawPolicyControllerText(String rawText) {
    if (rawText.trim().isNotEmpty) {
      _aclController.text = rawText;
      if (mounted) {
        setState(() {});
      }
    } else {
      _updateAclControllerText();
    }
  }

  bool _isComposerAvailable(AppProvider provider) {
    return GrantsV29Gate.isAvailable(
      engineMode: provider.aclEngineMode,
      serverVersion: provider.serverVersion,
    );
  }

  Future<void> _openGrantComposer({Node? prefilledRouter}) async {
    final provider = context.read<AppProvider>();
    final locale = provider.locale;
    final isFr = locale.languageCode == 'fr';

    if (!_isComposerAvailable(provider)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isFr
            ? 'Composeur disponible uniquement en mode Grants V29 (Headscale ≥ 0.29).'
            : 'Composer available only in Grants V29 mode (Headscale ≥ 0.29).'),
      ));
      return;
    }

    if (_users.isEmpty) {
      try {
        _users = await provider.apiService.getUsers();
      } catch (e) {
        debugPrint('AclScreen._openGrantComposer getUsers error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isFr
                ? 'Impossible de charger les utilisateurs : $e'
                : 'Failed to load users: $e'),
          ));
        }
        return;
      }
    }

    if (!mounted) return;

    final result = await GrantComposerSheet.show(
      context,
      users: _users,
      nodes: _allNodes,
      isFr: isFr,
      prefilledRouterNode: prefilledRouter,
    );

    if (result == null || !mounted) return;

    setState(() {
      if (result.containsKey('action')) {
        _currentAclPolicy =
            GrantComposerService.appendExceptionAcl(_currentAclPolicy, result);
      } else {
        _currentAclPolicy =
            GrantComposerService.appendNetworkGrant(_currentAclPolicy, result);
      }
      _jsonParseError = null;
      _isLocalDraft = true;
      _updateAclControllerText();
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isFr
          ? 'Règle ajoutée à la policy locale. Exportez pour appliquer au serveur.'
          : 'Rule added to local policy. Export to apply to server.'),
    ));
  }

  Future<void> _onEditGrant(
      int networkIndex, Map<String, dynamic> grant) async {
    final provider = context.read<AppProvider>();
    final isFr = provider.locale.languageCode == 'fr';

    if (!_isComposerAvailable(provider)) return;

    final updated = await GrantEditSheet.show(
      context,
      grant: grant,
      users: _users,
      nodes: _allNodes,
      isFr: isFr,
    );

    if (updated == null || !mounted) return;

    setState(() {
      _currentAclPolicy = GrantComposerService.updateNetworkGrantAt(
        _currentAclPolicy,
        networkIndex,
        updated,
      );
      _jsonParseError = null;
      _isLocalDraft = true;
      _updateAclControllerText();
    });
  }

  void _onDeleteGrant(int networkIndex) {
    setState(() {
      var updated = GrantComposerService.removeNetworkGrantAt(
        _currentAclPolicy,
        networkIndex,
      );
      if (_users.isNotEmpty || _allNodes.isNotEmpty) {
        updated = PolicyOrphanCleaner.cleanOrphans(
          updated,
          users: _users,
          nodes: _allNodes,
        );
      }
      _currentAclPolicy = updated;
      _jsonParseError = null;
      _isLocalDraft = true;
      _updateAclControllerText();
    });
  }

  void _cleanOrphansFromPolicy() {
    setState(() {
      _currentAclPolicy = PolicyOrphanCleaner.cleanOrphans(
        _currentAclPolicy,
        users: _users,
        nodes: _allNodes,
      );
      _jsonParseError = null;
      _isLocalDraft = true;
      _updateAclControllerText();
    });
  }

  void _resetToServerSnapshot() {
    if (_serverPolicySnapshot.isEmpty && _serverRawPolicyText.trim().isEmpty) {
      return;
    }
    setState(() {
      _currentAclPolicy = PolicyPreserver.deepCopyMap(_serverPolicySnapshot);
      _knownRuleComments =
          HuJsonCommentService.extractRuleComments(_serverRawPolicyText);
      _leadingComments =
          HuJsonCommentService.extractLeadingComments(_serverRawPolicyText);
      _jsonParseError = null;
      _isLocalDraft = false;
      _setRawPolicyControllerText(_serverRawPolicyText);
    });
  }

  Widget _buildScrollHeader({
    required bool isFr,
    required AppProvider appProvider,
    required int grantCount,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: AclEngineBanner(
                engineMode: appProvider.aclEngineMode,
                serverVersion: appProvider.serverVersion,
                users: _users,
                nodes: _allNodes,
                isFr: isFr,
                compact: true,
                onOpenDiagnostic: _openAlignmentDiagnostic,
              ),
            ),
            if (_isLocalDraft) AclWorkflowGuide(isFr: isFr),
          ],
        ),
        if (!_isLocalDraft)
          GrantsMigrationBanner(
            isFr: isFr,
            grantCount: grantCount,
          ),
      ],
    );
  }

  Widget _buildOrphanBanner(bool isFr) {
    if (_users.isEmpty) return const SizedBox.shrink();
    final info = PolicyOrphanCleaner.inspectOrphans(
      _currentAclPolicy,
      users: _users,
      nodes: _allNodes,
    );
    if (!info.hasOrphanReferences) return const SizedBox.shrink();

    final count = info.orphanGroups.length +
        info.orphanTags.length +
        info.orphanHosts.length;
    final sample = [
      ...info.orphanGroups,
      ...info.orphanTags,
      ...info.orphanHosts,
    ].take(3).join(', ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.deepOrange.withValues(alpha: 0.14),
      child: Row(
        children: [
          const Icon(Icons.cleaning_services_outlined,
              size: 18, color: Colors.deepOrange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isFr
                  ? '$count entrée(s) orpheline(s) détectée(s) ($sample) — utilisateur/nœud supprimé.'
                  : '$count orphan entry(ies) detected ($sample) — deleted user/node.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          TextButton(
            onPressed: _cleanOrphansFromPolicy,
            child: Text(isFr ? 'Nettoyer' : 'Clean up'),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingChangesBanner(bool isFr) {
    if (!_isLocalDraft && _jsonParseError == null) {
      return const SizedBox.shrink();
    }
    final hasError = _jsonParseError != null;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: hasError
          ? colorScheme.errorContainer
          : Colors.amber.withValues(alpha: 0.18),
      child: Row(
        children: [
          Icon(
            hasError ? Icons.error_outline : Icons.cloud_upload_outlined,
            size: 18,
            color:
                hasError ? colorScheme.onErrorContainer : Colors.amber.shade900,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasError
                  ? (isFr
                      ? 'JSON/HuJSON invalide — export bloqué'
                      : 'Invalid JSON/HuJSON — export blocked')
                  : (isFr
                      ? 'Modifications locales non publiées'
                      : 'Unpublished local changes'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hasError ? colorScheme.onErrorContainer : null,
                  ),
            ),
          ),
          if (_serverPolicySnapshot.isNotEmpty)
            TextButton(
              onPressed: _resetToServerSnapshot,
              child: Text(isFr ? 'Annuler' : 'Reset'),
            ),
          FilledButton(
            onPressed: hasError
                ? null
                : () => _exportAclPolicyToServer(showConfirmation: true),
            child: Text(isFr ? 'Appliquer' : 'Apply'),
          ),
        ],
      ),
    );
  }

  Widget _buildGrantsTab({
    required bool isFr,
    required AppProvider appProvider,
    required bool composerAvailable,
  }) {
    final grantCount =
        GrantComposerService.countNetworkGrants(_currentAclPolicy);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildScrollHeader(
              isFr: isFr,
              appProvider: appProvider,
              grantCount: grantCount,
            ),
            _buildComposerButton(isFr, appProvider),
            if (composerAvailable)
              _buildAdvancedExceptionsSection(isFr)
            else
              _buildTemporaryRulesSection(),
            const SizedBox(height: 8),
            GrantsListView(
              grants: (_currentAclPolicy['grants'] as List?) ?? const [],
              isFr: isFr,
              onEditGrant: composerAvailable ? _onEditGrant : null,
              onDeleteGrant: composerAvailable ? _onDeleteGrant : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAclsTab({
    required bool isFr,
    required AppProvider appProvider,
  }) {
    final grantCount =
        GrantComposerService.countNetworkGrants(_currentAclPolicy);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildScrollHeader(
            isFr: isFr,
            appProvider: appProvider,
            grantCount: grantCount,
          ),
          AclsListView(
            acls: (_currentAclPolicy['acls'] as List?) ?? const [],
            isFr: isFr,
          ),
        ],
      ),
    );
  }

  Widget _buildSshTab({
    required bool isFr,
    required AppProvider appProvider,
  }) {
    final grantCount =
        GrantComposerService.countNetworkGrants(_currentAclPolicy);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildScrollHeader(
            isFr: isFr,
            appProvider: appProvider,
            grantCount: grantCount,
          ),
          SshRulesListView(
            sshRules: (_currentAclPolicy['ssh'] as List?) ?? const [],
            allNodes: _allNodes,
            allUsers: _users,
            policy: _currentAclPolicy,
            isFr: isFr,
            onAddRule: (rule) => _mutateSshRules((list) => list.add(rule)),
            onEditRule: (index, updated) => _mutateSshRules((list) {
              if (index >= 0 && index < list.length) {
                list[index] = updated;
              }
            }),
            onDeleteRule: (index) => _mutateSshRules((list) {
              if (index >= 0 && index < list.length) {
                list.removeAt(index);
              }
            }),
          ),
        ],
      ),
    );
  }

  void _mutateSshRules(void Function(List<dynamic> sshList) mutator) {
    final updated = PolicyPreserver.deepCopyMap(_currentAclPolicy);
    final list = List<dynamic>.from((updated['ssh'] as List?) ?? const []);
    mutator(list);
    if (list.isEmpty) {
      updated.remove('ssh');
    } else {
      updated['ssh'] = list;
    }
    setState(() {
      _currentAclPolicy = updated;
      _isLocalDraft = true;
      _jsonParseError = null;
      _updateAclControllerText();
    });
  }

  Future<void> _openAlignmentDiagnostic() async {
    final changed = await AlignmentAssistantDialog.show(context);
    if (changed && mounted) {
      await _loadInitialData();
    }
  }

  Future<void> _openAclSimulator() async {
    final provider = context.read<AppProvider>();
    final isFr = provider.locale.languageCode == 'fr';
    if (_users.isEmpty) {
      try {
        _users = await provider.apiService.getUsers();
      } catch (e) {
        debugPrint('AclScreen._openAclSimulator getUsers error: $e');
      }
    }
    if (!mounted) return;

    final supportsTests = VersionInfo.checkVersionAtLeast(
      provider.serverVersion,
      '0.29.0',
    );
    await AclSimulatorSheet.show(
      context,
      policy: _currentAclPolicy,
      nodes: _allNodes,
      users: _users,
      isFr: isFr,
      composerAvailable: _isComposerAvailable(provider),
      supportsTestsBlock: supportsTests,
      onPinTest: _handlePinTest,
      onRemoveTest: _handleRemoveTest,
      onAuthorizeWithComposer: (_, __) => _openGrantComposer(),
    );
  }

  void _handlePinTest(Map<String, dynamic> entry) {
    final updated = PolicyPreserver.deepCopyMap(_currentAclPolicy);
    final tests = List<dynamic>.from((updated['tests'] as List?) ?? const []);
    tests.add(entry);
    updated['tests'] = tests;
    setState(() {
      _currentAclPolicy = updated;
      _isLocalDraft = true;
      _jsonParseError = null;
      _updateAclControllerText();
    });
  }

  void _handleRemoveTest(int index) {
    final updated = PolicyPreserver.deepCopyMap(_currentAclPolicy);
    final tests = List<dynamic>.from((updated['tests'] as List?) ?? const []);
    if (index >= 0 && index < tests.length) {
      tests.removeAt(index);
    }
    if (tests.isEmpty) {
      updated.remove('tests');
    } else {
      updated['tests'] = tests;
    }
    setState(() {
      _currentAclPolicy = updated;
      _isLocalDraft = true;
      _jsonParseError = null;
      _updateAclControllerText();
    });
  }

  Widget _buildJsonTab({required bool isFr}) {
    final appProvider = context.read<AppProvider>();
    final grantCount =
        GrantComposerService.countNetworkGrants(_currentAclPolicy);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildScrollHeader(
              isFr: isFr,
              appProvider: appProvider,
              grantCount: grantCount,
            ),
            if (_jsonParseError != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
                        color: Theme.of(context).colorScheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isFr
                            ? 'Syntaxe JSON/HuJSON invalide : corrigez avant d\'appliquer.'
                            : 'Invalid JSON/HuJSON syntax: fix before applying.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            TextField(
              controller: _aclController,
              maxLines: null,
              minLines: 16,
              onChanged: (value) {
                final normalizedNew = value.replaceAll('\r\n', '\n').trim();
                final normalizedServer =
                    _serverRawPolicyText.replaceAll('\r\n', '\n').trim();
                final textChanged = _serverRawPolicyText.isNotEmpty
                    ? normalizedNew != normalizedServer
                    : true;
                try {
                  final decoded = JsonUtils.decodeHuJson(value);
                  if (decoded is Map) {
                    final parsedMap = Map<String, dynamic>.from(decoded);
                    setState(() {
                      _currentAclPolicy = parsedMap;
                      _knownRuleComments =
                          HuJsonCommentService.extractRuleComments(value);
                      _leadingComments =
                          HuJsonCommentService.extractLeadingComments(value);
                      _jsonParseError = null;
                      _isLocalDraft = textChanged;
                    });
                  } else {
                    setState(() {
                      _jsonParseError = 'Root JSON value must be an object';
                      _isLocalDraft = true;
                    });
                  }
                } catch (e) {
                  setState(() {
                    _jsonParseError = e.toString();
                    _isLocalDraft = true;
                  });
                }
              },
              decoration: _buildInputDecoration('Politique ACL', '').copyWith(
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedExceptionsSection(bool isFr) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        isFr
            ? 'Mode avancé : exceptions manuelles'
            : 'Advanced: manual exceptions',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      subtitle: Text(
        isFr
            ? 'Ancien formulaire nœud à nœud — le composeur suffit en général'
            : 'Legacy node-to-node form — composer is usually enough',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      children: [
        _buildTemporaryRulesSection(),
      ],
    );
  }

  Widget _buildComposerButton(bool isFr, AppProvider provider) {
    if (!_isComposerAvailable(provider)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FilledButton.icon(
        onPressed: () => _openGrantComposer(),
        icon: const Icon(Icons.auto_fix_high),
        label: Text(isFr ? 'Composer une règle' : 'Compose a rule'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final locale = appProvider.locale;
    final isFr = locale.languageCode == 'fr';
    final composerAvailable = _isComposerAvailable(appProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(isFr ? 'Gestion des ACLs' : 'ACL Management',
            style: Theme.of(context).appBarTheme.titleTextStyle),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: Theme.of(context).appBarTheme.iconTheme,
        actions: [
          _buildActionsMenu(),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
              length: 4,
              child: Column(
                children: [
                  TabBar(
                    tabs: [
                      Tab(text: isFr ? 'Grants' : 'Grants'),
                      Tab(text: isFr ? 'ACLs' : 'ACLs'),
                      const Tab(text: 'SSH'),
                      Tab(text: isFr ? 'JSON' : 'JSON'),
                    ],
                  ),
                  _buildOrphanBanner(isFr),
                  _buildPendingChangesBanner(isFr),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildGrantsTab(
                          isFr: isFr,
                          appProvider: appProvider,
                          composerAvailable: composerAvailable,
                        ),
                        _buildAclsTab(isFr: isFr, appProvider: appProvider),
                        _buildSshTab(isFr: isFr, appProvider: appProvider),
                        _buildJsonTab(isFr: isFr),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: SpeedDial(
        animatedIcon: AnimatedIcons.menu_close,
        backgroundColor: Theme.of(context).colorScheme.primary,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.radar),
            label: isFr ? 'Simulateur de flux ACL' : 'ACL Flow Simulator',
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            onTap: _openAclSimulator,
          ),
          if (composerAvailable)
            SpeedDialChild(
              child: const Icon(Icons.auto_fix_high),
              label: isFr ? 'Composeur de grants' : 'Grant composer',
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              onTap: () => _openGrantComposer(),
            ),
          SpeedDialChild(
            child: const Icon(Icons.account_tree_outlined),
            label: isFr ? 'Vue Graphe' : 'Graph View',
            backgroundColor: Theme.of(context).colorScheme.secondary,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AclManagerScreen()),
              );
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.extension),
            label: isFr ? 'Vue Puzzle (Builder)' : 'Puzzle View (Builder)',
            backgroundColor: Colors.purple,
            labelBackgroundColor: Colors.purple,
            labelStyle: const TextStyle(color: Colors.white),
            foregroundColor: Colors.white,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AclPuzzleScreen()),
              );
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.folder_shared),
            label: isFr ? 'Partages Taildrive' : 'Taildrive Shares',
            backgroundColor: Theme.of(context).colorScheme.tertiary,
            labelBackgroundColor:
                Theme.of(context).colorScheme.tertiaryContainer,
            labelStyle: TextStyle(
                color: Theme.of(context).colorScheme.onTertiaryContainer),
            foregroundColor: Theme.of(context).colorScheme.onTertiary,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const TaildriveManagerScreen()),
              );
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.settings_backup_restore),
            label: isFr ? 'Générer Politique' : 'Generate Policy',
            backgroundColor: Theme.of(context).colorScheme.secondary,
            onTap: () => _generateNewAclPolicy(showSnackbar: true),
          ),
        ],
      ),
    );
  }

  PopupMenuButton<String> _buildActionsMenu() {
    // This is inside build, so watch is fine. The onSelected callback is the issue.
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return PopupMenuButton<String>(
      onSelected: (value) {
        // We use context.read inside the callbacks
        switch (value) {
          case 'export':
            _exportAclPolicyToServer();
            break;
          case 'fetch':
            _fetchAclPolicyFromServer();
            break;
          case 'simulate':
            _openAclSimulator();
            break;
          case 'diagnostic':
            _openAlignmentDiagnostic();
            break;
          case 'backup':
            _exportPolicyBackup();
            break;
          case 'import':
            _importPolicyFromFile();
            break;
          case 'share':
            _shareAclFile();
            break;
          case 'staging':
            _showPolicyStagingDialog();
            break;
        }
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'export',
          child: ListTile(
              leading: const Icon(Icons.cloud_upload),
              title:
                  Text(isFr ? 'Exporter vers le serveur' : 'Export to Server')),
        ),
        PopupMenuItem<String>(
          value: 'fetch',
          child: ListTile(
              leading: const Icon(Icons.cloud_download),
              title: Text(isFr ? 'Récupérer du serveur' : 'Fetch from Server')),
        ),
        PopupMenuItem<String>(
          value: 'simulate',
          child: ListTile(
              leading: const Icon(Icons.radar),
              title: Text(
                  isFr ? 'Simulateur de flux ACL' : 'ACL Flow Simulator')),
        ),
        PopupMenuItem<String>(
          value: 'diagnostic',
          child: ListTile(
              leading: const Icon(Icons.health_and_safety_outlined),
              title: Text(isFr
                  ? 'Diagnostic & Alignement ACL'
                  : 'ACL Alignment Diagnostic')),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'backup',
          child: ListTile(
            leading: const Icon(Icons.save_alt),
            title: Text(isFr ? 'Exporter backup JSON' : 'Export JSON Backup'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'import',
          child: ListTile(
            leading: const Icon(Icons.upload_file),
            title: Text(isFr ? 'Importer depuis JSON' : 'Import from JSON'),
          ),
        ),
        PopupMenuItem<String>(
          value: 'share',
          child: ListTile(
              leading: const Icon(Icons.share),
              title: Text(isFr ? 'Partager en fichier' : 'Share as File')),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'staging',
          child: ListTile(
            leading: const Icon(Icons.lock_open, color: Colors.orange),
            title: Text(
                isFr ? 'Repartir : tout autoriser…' : 'Start over: allow all…',
                style: const TextStyle(color: Colors.orange)),
          ),
        ),
      ],
    );
  }

  Widget _buildRuleItem(Map<String, dynamic> rule, int index) {
    final src = rule['src'] as String;
    final dst = rule['dst'] as String;
    final port = rule['port'] as String?;
    final proto = rule['proto'] as String? ?? 'any';
    final portDisplay =
        (port == null || port.isEmpty || port == '*') ? 'All ports' : port;
    final protoDisplay = proto.toUpperCase();

    return ListTile(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.outbound, size: 16, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Src: $src',
                      style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.login, size: 16, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Dst: $dst',
                      style: const TextStyle(fontWeight: FontWeight.bold))),
            ],
          ),
        ],
      ),
      subtitle: Text('Port: $portDisplay | Proto: $protoDisplay'),
      trailing: IconButton(
        icon: const Icon(Icons.delete, color: Colors.red),
        onPressed: () async {
          setState(() {
            _pendingRemovedTempRules.add(_temporaryRules[index]);
            _temporaryRules.removeAt(index);
          });

          final appProvider = context.read<AppProvider>();
          final storage = appProvider.storageService;
          final serverId = appProvider.activeServer?.id;
          if (serverId != null) {
            await storage.saveTemporaryRules(serverId, _temporaryRules);
          }

          final locale = appProvider.locale;
          final isFr = locale.languageCode == 'fr';
          await _generateAndExportPolicy(
              message: isFr
                  ? 'Règle supprimée et politique mise à jour.'
                  : 'Rule deleted and policy updated.');
        },
      ),
    );
  }

  Widget _buildTemporaryRulesSection() {
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isFr ? 'Autorisations Spécifiques' : 'Specific Permissions',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontSize: 20)),
            const SizedBox(height: 8),
            Text(
              isFr
                  ? 'Créez ici des exceptions pour autoriser la communication entre les appareils de différents utilisateurs.'
                  : 'Create exceptions here to allow communication between devices of different users.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildNodeDropdown(
                    'Source (Node)',
                    _selectedSourceNode,
                    _allNodes,
                    (node) {
                      setState(() {
                        _selectedSourceNode = node;
                        _selectedDestinationNode = null;
                        if (node != null) {
                          _destinationNodes = _allNodes
                              .where((n) =>
                                  n.getNormalizedOwner() !=
                                  node.getNormalizedOwner())
                              .toList();
                        } else {
                          _destinationNodes = List.from(_allNodes);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildNodeDropdown(
                    'Destination (Node)',
                    _selectedDestinationNode,
                    _destinationNodes,
                    (node) => setState(() => _selectedDestinationNode = node),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _portController,
                    decoration: InputDecoration(
                      labelText: isFr ? 'Port (Optionnel)' : 'Port (Optional)',
                      hintText: 'ex: 80, 443',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedProtocol,
                    decoration: InputDecoration(
                      labelText: isFr ? 'Protocole' : 'Protocol',
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                          value: 'any',
                          child: Text(isFr ? 'Tous (Any)' : 'Any')),
                      const DropdownMenuItem(value: 'tcp', child: Text('TCP')),
                      const DropdownMenuItem(value: 'udp', child: Text('UDP')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedProtocol = val;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: _addTemporaryRule,
                icon: const Icon(Icons.add_link, color: Colors.white),
                label: Text(isFr ? 'Ajouter et Appliquer' : 'Add and Apply',
                    style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(isFr ? 'Règles actives:' : 'Active Rules:',
                    style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: Icon(Icons.delete_sweep,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6)),
                  tooltip:
                      isFr ? 'Effacer toutes les règles' : 'Clear All Rules',
                  onPressed: _clearTemporaryRules,
                )
              ],
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _temporaryRules.length,
              itemBuilder: (context, index) {
                return _buildRuleItem(_temporaryRules[index], index);
              },
            ),
          ],
        ),
      ),
    );
  }

  DropdownButtonFormField<Node> _buildNodeDropdown(String label,
      Node? selectedNode, List<Node> nodes, ValueChanged<Node?> onChanged) {
    final locale = context.watch<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    return DropdownButtonFormField<Node>(
      initialValue: selectedNode,
      decoration: _buildInputDecoration(
          label, isFr ? 'Choisir un nœud' : 'Choose a node'),
      items: nodes.map((Node node) {
        return DropdownMenuItem<Node>(
          value: node,
          child: Text(node.name, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
      onChanged: onChanged,
      isExpanded: true,
    );
  }

  InputDecoration _buildInputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Theme.of(context).inputDecorationTheme.fillColor ??
          Theme.of(context).colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: BorderSide.none,
      ),
    );
  }

  String? _getMatchingSourceIp(Node sourceNode, String destinationIp) {
    try {
      // Determine destination type (IPv4 or IPv6)
      // Check if it's a CIDR or plain IP
      final cleanDest = destinationIp.split('/')[0];
      final destAddress = InternetAddress(cleanDest);
      final isDestIPv6 = destAddress.type == InternetAddressType.IPv6;

      // Find matching source
      return sourceNode.ipAddresses.firstWhere((ip) {
        // Remove CIDR if present (shouldn't be for source IPs usually but safe to check)
        final cleanIp = ip.split('/')[0];
        try {
          final address = InternetAddress(cleanIp);
          return (address.type == InternetAddressType.IPv6) == isDestIPv6;
        } catch (_) {
          return false;
        }
      }, orElse: () => '');
    } catch (_) {
      // Fallback: if destination is invalid or parsing fails, return first IP (legacy behavior) or null?
      // Let's assume default behavior if check fails
      return sourceNode.ipAddresses.isNotEmpty
          ? sourceNode.ipAddresses.first
          : null;
    }
  }

  void _showIpMismatchError(BuildContext context, bool isFr, String dest) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            isFr
                ? 'Impossible de trouver une IP source compatible (IPv4/IPv6) pour la destination: $dest'
                : 'Could not find a compatible source IP (IPv4/IPv6) for destination: $dest',
            style: TextStyle(color: Theme.of(context).colorScheme.onError)),
        backgroundColor: Theme.of(context).colorScheme.error));
  }

  bool _ruleExists(Map<String, dynamic> newRule) {
    return _temporaryRules.any((rule) {
      final bool srcMatch = rule['src'] == newRule['src'];
      final bool dstMatch = rule['dst'] == newRule['dst'];
      final bool portMatch = (rule['port'] ?? '') == (newRule['port'] ?? '');
      final bool protoMatch =
          (rule['proto'] ?? 'any') == (newRule['proto'] ?? 'any');
      return srcMatch && dstMatch && portMatch && protoMatch;
    });
  }

  Future<void> _addTemporaryRule() async {
    if (!mounted) return;
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    if (_selectedSourceNode == null || _selectedDestinationNode == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              isFr
                  ? 'Veuillez sélectionner un nœud source et un nœud destination.'
                  : 'Please select a source and a destination node.',
              style: TextStyle(color: Theme.of(context).colorScheme.onError)),
          backgroundColor: Theme.of(context).colorScheme.error));
      return;
    }

    if (_selectedSourceNode!.ipAddresses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              isFr
                  ? 'Le nœud source doit avoir au moins une adresse IP.'
                  : 'Source node must have at least one IP address.',
              style: TextStyle(color: Theme.of(context).colorScheme.onError)),
          backgroundColor: Theme.of(context).colorScheme.error));
      return;
    }
    // final sourceIp = _selectedSourceNode!.ipAddresses.first; // REMOVED

    List<Map<String, dynamic>> newRulesToAdd = [];

    final sharedLanRoutes = _selectedDestinationNode!.sharedRoutes
        .where((r) => r != '0.0.0.0/0' && r != '::/0')
        .toList();

    if (sharedLanRoutes.isNotEmpty) {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SharedRoutesAccessDialog(
          destinationNode: _selectedDestinationNode!,
        ),
      );

      if (!mounted) return;

      // Debug: Afficher le résultat reçu du dialogue
      debugPrint('DEBUG: Résultat reçu du dialogue: $result');

      if (result == null) {
        debugPrint('DEBUG: Résultat est null, arrêt du processus');
        return;
      }

      try {
        final choice = result['choice'] as RouteAccessChoice;
        final rules = result['rules'] as Map<String, dynamic>;

        // Debug: Afficher le choix et les règles extraites
        debugPrint('DEBUG: Choix extrait: $choice');
        debugPrint('DEBUG: Règles extraites: $rules');

        if (choice == RouteAccessChoice.none) {
          // Fallback: add rule for the node itself if subnet access is denied
          if (_selectedDestinationNode!.ipAddresses.isNotEmpty) {
            String? fallbackDest;
            String? fallbackSrc;

            // Try to find a pair that works
            // check destination IPs
            for (var destIp in _selectedDestinationNode!.ipAddresses) {
              final src = _getMatchingSourceIp(_selectedSourceNode!, destIp);
              if (src != null && src.isNotEmpty) {
                fallbackDest = destIp;
                fallbackSrc = src;
                break;
              }
            }

            if (fallbackDest != null && fallbackSrc != null) {
              final port = _portController.text.trim();
              newRulesToAdd.add({
                'src': fallbackSrc,
                'dst': fallbackDest,
                'port': port.isEmpty ? '*' : port,
                'proto': _selectedProtocol,
              });
            } else {
              _showIpMismatchError(context, isFr, "Fallback IP");
              return;
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(isFr
                  ? 'Accès au sous-réseau non configuré et le nœud n\'a pas d\'IP pour une règle de base.'
                  : 'Subnet access not configured and the node has no IP for a fallback rule.'),
            ));
            return;
          }
        } else if (choice == RouteAccessChoice.full) {
          for (var route in sharedLanRoutes) {
            final src = _getMatchingSourceIp(_selectedSourceNode!, route);
            if (src == null || src.isEmpty) {
              _showIpMismatchError(context, isFr, route);
              return;
            }
            newRulesToAdd.add({
              'src': src,
              'dst': route,
              'port': '*',
              'proto': _selectedProtocol,
            });
          }
        } else if (choice == RouteAccessChoice.custom) {
          // rules.forEach loop logic
          for (var entry in rules.entries) {
            final ruleDetails = entry.value;
            final startIp = (ruleDetails['startIp'] as String).trim();
            final endIp = (ruleDetails['endIp'] as String).trim();
            final ports = (ruleDetails['ports'] as String).trim();

            if (startIp.isEmpty) continue;

            String dst;
            if (endIp.isNotEmpty) {
              // Range logic - assume range is same IP version as startIp
              // Note: Generating full list of IPs might be heavy if range is huge.
              // Logic assumes startIp and endIp are safe.
              final range = IpUtils.generateIpRange(startIp, endIp);
              dst = range.join(',');
            } else {
              dst = startIp;
            }

            if (dst.isNotEmpty) {
              // Note: if dst is comma separated list, check first one for version?
              // Or check each?
              // The generateIpRange ensures same type.
              final firstDest = dst.split(',').first;
              final src = _getMatchingSourceIp(_selectedSourceNode!, firstDest);

              if (src == null || src.isEmpty) {
                _showIpMismatchError(context, isFr, firstDest);
                return;
              }

              newRulesToAdd.add({
                'src': src,
                'dst': dst,
                'port': ports.isEmpty ? '*' : ports,
                'proto': _selectedProtocol,
              });
            }
          }
        }
      } catch (e) {
        debugPrint('DEBUG: Erreur lors de l\'extraction du choix/règles: $e');
        return;
      }
    } else {
      if (_selectedDestinationNode!.ipAddresses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                isFr
                    ? 'Le nœud destination doit avoir au moins une adresse IP.'
                    : 'Destination node must have at least one IP address.',
                style: TextStyle(color: Theme.of(context).colorScheme.onError)),
            backgroundColor: Theme.of(context).colorScheme.error));
        return;
      }

      // Single node destination (no shared routes)
      // Try to match IPs
      String? validDest;
      String? validSrc;

      // Prefer IPv4 if available? Or depend on what dest has.
      // Strategy: Try IPv4 match first, then IPv6? Or just first available pair?
      // Let's iterate dest IPs.
      for (var destIp in _selectedDestinationNode!.ipAddresses) {
        final src = _getMatchingSourceIp(_selectedSourceNode!, destIp);
        if (src != null && src.isNotEmpty) {
          validDest = destIp;
          validSrc = src;
          // Stop if found?
          // If User wants specifically IPv6, he might be disappointed if we pick IPv4.
          // But here we are selecting a Node, so any connectivity is good?
          // But wait, the previous logic just picked first IP (IPv4 usually).
          // If we find IPv4 pair, good. If not, IPv6 pair.
          // Let's prioritize IPv4 to match legacy behavior if possible.
          final cleanDest = destIp.split('/')[0];
          if (InternetAddress(cleanDest).type == InternetAddressType.IPv4) {
            break; // Found IPv4 pair, awesome.
          }
        }
      }

      if (validDest != null && validSrc != null) {
        if (validSrc == validDest) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  isFr
                      ? 'Les nœuds source et destination ne peuvent pas être identiques.'
                      : 'Source and destination nodes cannot be the same.',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onError)),
              backgroundColor: Theme.of(context).colorScheme.error));
          return;
        }

        final port = _portController.text.trim();
        newRulesToAdd.add({
          'src': validSrc,
          'dst': validDest,
          'port': port,
          'proto': _selectedProtocol,
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                isFr
                    ? 'Impossible de trouver une paire d\'adresses IP compatibles (IPv4/IPv6) entre la source et la destination.'
                    : 'Could not find a compatible IP pair (IPv4/IPv6) between source and destination.',
                style: TextStyle(color: Theme.of(context).colorScheme.onError)),
            backgroundColor: Theme.of(context).colorScheme.error));
        return;
      }
    }

    int addedCount = 0;

    // Debug: Afficher les règles à ajouter
    debugPrint('DEBUG: Nombre de règles à ajouter: ${newRulesToAdd.length}');
    for (var rule in newRulesToAdd) {
      debugPrint('DEBUG: Règle à ajouter: $rule');
    }

    for (var newRule in newRulesToAdd) {
      if (!_ruleExists(newRule)) {
        setState(() {
          _temporaryRules.add(newRule);
          addedCount++;
        });
        debugPrint('DEBUG: Règle ajoutée: $newRule');
      } else {
        debugPrint('DEBUG: Règle ignorée (existe déjà): $newRule');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${isFr ? 'Règle ignorée car elle existe déjà:' : 'Skipped existing rule:'} ${newRule['dst']}',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondaryContainer)),
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer));
      }
    }

    debugPrint('DEBUG: Nombre de règles ajoutées: $addedCount');

    if (addedCount > 0) {
      final appProvider = context.read<AppProvider>();
      final storage = appProvider.storageService;
      final serverId = appProvider.activeServer?.id;
      if (serverId != null) {
        await storage.saveTemporaryRules(serverId, _temporaryRules);
      }
      await _generateAndExportPolicy(
          message: isFr
              ? '$addedCount règle(s) ajoutée(s) et politique appliquée.'
              : '$addedCount rule(s) added and policy applied.');
    } else {
      // Debug: Afficher un message si aucune règle n'a été ajoutée
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              isFr ? 'Aucune règle n\'a été ajoutée.' : 'No rules were added.',
              style: TextStyle(color: Theme.of(context).colorScheme.onError)),
          backgroundColor: Theme.of(context).colorScheme.error));
    }
  }

  Future<void> _generateNewAclPolicy({bool showSnackbar = true}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final appProvider = context.read<AppProvider>();
      final apiService = appProvider.apiService;

      final users = await apiService.getUsers();
      final nodes = await apiService.getNodes();
      _allNodes = nodes;
      _destinationNodes = List.from(nodes);

      // Clean up obsolete lan-sharer tags before ACL generation
      final cleanedNodes =
          await TagCapabilityHelper.cleanupObsoleteLanSharerTags(
        apiService,
        nodes,
      );

      final generatedPolicy = _aclOrchestrator.generatePolicy(
        engineMode: appProvider.aclEngineMode,
        users: users,
        nodes: cleanedNodes,
        temporaryRules: _temporaryRules,
        taildriveShares: appProvider.taildriveShares,
        serverVersion: appProvider.serverVersion,
        includeUntaggedNodes: appProvider.includeUntaggedNodes,
      );
      final bundle =
          await PolicyPreserver.fetchServerPolicyBundleSafely(apiService);
      final serverPolicy = bundle.policy;
      _serverRawPolicyText = bundle.rawText;
      if (bundle.ruleComments.isNotEmpty) {
        _knownRuleComments = {
          ...bundle.ruleComments,
          ..._knownRuleComments,
        };
      }
      _leadingComments ??= bundle.leadingComments;
      _serverPolicySnapshot = PolicyPreserver.deepCopyMap(
        serverPolicy ?? const {},
      );
      var mergedPolicy = PolicyPreserver.merge(
        generatedPolicy,
        serverPolicy,
      );
      if (serverPolicy != null) {
        mergedPolicy = await _preserveCustomRulesOnRegenerate(
          mergedPolicy: mergedPolicy,
          serverPolicy: serverPolicy,
          askUser: showSnackbar,
        );
      }
      _currentAclPolicy = mergedPolicy;
      _users = users;
      _jsonParseError = null;

      _updateAclControllerText();
      if (mounted) {
        final normCurrent =
            _aclController.text.replaceAll('\r\n', '\n').trim();
        final normServer =
            _serverRawPolicyText.replaceAll('\r\n', '\n').trim();
        setState(() {
          _isLocalDraft = json.encode(_currentAclPolicy) !=
                  json.encode(_serverPolicySnapshot) ||
              normCurrent != normServer;
        });
      }

      final locale = appProvider.locale;
      final isFr = locale.languageCode == 'fr';

      if (showSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    isFr
                        ? 'Politique ACL avancée générée dans le champ de texte.'
                        : 'Advanced ACL policy generated in the text field.',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary)),
                const SizedBox(height: 4),
                Text(
                    isFr
                        ? 'Utilisez le menu (⋮) pour l\'exporter.'
                        : 'Use the menu (⋮) to export it.',
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimary
                            .withValues(alpha: 0.7),
                        fontSize: 12)),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      debugPrint(
          'Erreur lors de la génération de la politique ACL avancée : $e');
      if (mounted) {
        final locale = context.read<AppProvider>().locale;
        final isFr = locale.languageCode == 'fr';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${isFr ? 'Échec de la génération de la politique ACL avancée' : 'Failed to generate advanced ACL policy'}: $e',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onError)),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Détecte et propose de conserver les règles `grants` et `acls`
  /// personnalisées (ex: Composeur, Vue Puzzle, règles inter-utilisateurs OIDC)
  /// présentes sur le serveur lors d'une régénération automatique.
  Future<Map<String, dynamic>> _preserveCustomRulesOnRegenerate({
    required Map<String, dynamic> mergedPolicy,
    required Map<String, dynamic> serverPolicy,
    required bool askUser,
  }) async {
    final generatedGrants = List<dynamic>.from(
      (mergedPolicy['grants'] as List?) ?? const [],
    );
    final generatedAcls = List<dynamic>.from(
      (mergedPolicy['acls'] as List?) ?? const [],
    );

    final excludedServerAcls = _pendingRemovedTempRules.isNotEmpty
        ? PolicyPreserver.compileTemporaryRulesToAcls(_pendingRemovedTempRules)
        : const <Map<String, dynamic>>[];
    _pendingRemovedTempRules.clear();

    final extra = PolicyPreserver.extractExtraCustomRules(
      generatedPolicy: mergedPolicy,
      serverPolicy: serverPolicy,
      excludedServerAcls: excludedServerAcls,
    );
    final extraGrants = extra.extraGrants;
    final extraAcls = extra.extraAcls;

    final totalExtra = extraGrants.length + extraAcls.length;
    if (totalExtra == 0) return mergedPolicy;

    bool shouldKeep = true;
    if (askUser && mounted) {
      final isFr = context.read<AppProvider>().locale.languageCode == 'fr';
      final choice = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            isFr
                ? 'Règles personnalisées détectées'
                : 'Custom rules detected',
          ),
          content: Text(
            isFr
                ? '$totalExtra règle(s) personnalisée(s) (ex: Composeur, Vue Puzzle ou accès OIDC inter-utilisateurs) existent actuellement sur le serveur et ne font pas partie des règles par défaut.\n\nVoulez-vous les conserver lors de la régénération ?'
                : '$totalExtra custom rule(s) (e.g. Composer, Puzzle View or cross-user OIDC rules) currently exist on the server and are not part of default rules.\n\nKeep them during regeneration?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(isFr ? 'Tout réinitialiser' : 'Reset all'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(isFr ? 'Conserver (Recommandé)' : 'Keep (Recommended)'),
            ),
          ],
        ),
      );
      shouldKeep = choice ?? true;
    }

    if (!shouldKeep) return mergedPolicy;

    final updated = PolicyPreserver.deepCopyMap(mergedPolicy);
    if (extraGrants.isNotEmpty) {
      updated['grants'] = [...generatedGrants, ...extraGrants];
    }
    if (extraAcls.isNotEmpty) {
      updated['acls'] = [...generatedAcls, ...extraAcls];
    }
    return updated;
  }

  Future<void> _clearTemporaryRules() async {
    if (!mounted) return;
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    final bool confirm = await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(isFr ? 'Confirmer la suppression' : 'Confirm Deletion'),
            content: Text(isFr
                ? 'Cela va supprimer TOUTES les règles et appliquer la nouvelle politique au serveur. Continuer ?'
                : 'This will delete ALL rules and apply the new policy to the server. Continue?'),
            actions: [
              TextButton(
                  child: Text(isFr ? 'Annuler' : 'Cancel'),
                  onPressed: () => Navigator.of(ctx).pop(false)),
              TextButton(
                  child: Text(isFr ? 'Confirmer' : 'Confirm',
                      style: const TextStyle(color: Colors.red)),
                  onPressed: () => Navigator.of(ctx).pop(true)),
            ],
          ),
        ) ??
        false;

    if (!confirm || !mounted) return;

    setState(() {
      _pendingRemovedTempRules.addAll(_temporaryRules);
      _temporaryRules.clear();
    });
    final appProvider = context.read<AppProvider>();
    final storage = appProvider.storageService;
    final serverId = appProvider.activeServer?.id;
    if (serverId != null) {
      await storage.saveTemporaryRules(serverId, _temporaryRules);
    }
    await _generateAndExportPolicy(
        message: isFr
            ? 'Toutes les règles ont été supprimées et la politique a été mise à jour.'
            : 'All rules have been deleted and the policy has been updated.');
  }

  Future<void> _generateAndExportPolicy({String? message}) async {
    await _generateNewAclPolicy(showSnackbar: false);
    await _exportAclPolicyToServer(
        showConfirmation: false, successMessage: message);
  }

  Future<void> _exportAclPolicyToServer(
      {bool showConfirmation = true, String? successMessage}) async {
    if (!mounted) return;
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';
    final apiService = context.read<AppProvider>().apiService;

    late Map<String, dynamic> editedPolicy;
    try {
      final decoded = JsonUtils.decodeHuJson(_aclController.text);
      if (decoded is! Map) {
        throw const FormatException('Root JSON must be an object');
      }
      editedPolicy = Map<String, dynamic>.from(decoded);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFr
                  ? 'JSON/HuJSON invalide : corrigez la syntaxe avant d\'exporter ($e).'
                  : 'Invalid JSON/HuJSON: fix syntax before exporting ($e).',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    // Garde-fou : valider que les IPs/tags référencés dans "tests" existent toujours
    final testsValidation = AclParserService.validatePolicyTests(
      editedPolicy,
      allNodes: _allNodes,
      allUsers: _users,
    );
    if (!testsValidation.isValid && mounted) {
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            isFr
                ? 'Tests ACL obsolètes détectés'
                : 'Obsolete ACL tests detected',
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFr
                        ? 'Le bloc "tests" référence des nœuds ou tags absents du serveur, ce qui peut provoquer un rejet :'
                        : 'The "tests" block references missing nodes or tags which could cause a server rejection:',
                  ),
                  const SizedBox(height: 8),
                  ...testsValidation.issues.map(
                    (issue) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${isFr ? issue.reasonFr : issue.reasonEn}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: Text(isFr ? 'Annuler' : 'Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'keep'),
              child: Text(isFr ? 'Exporter tel quel' : 'Export anyway'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'clean'),
              child: Text(
                isFr ? 'Nettoyer et continuer' : 'Clean & continue',
              ),
            ),
          ],
        ),
      );
      if (choice == null || choice == 'cancel') return;
      if (choice == 'clean') {
        editedPolicy = AclParserService.pruneObsoletePolicyTests(
          editedPolicy,
          allNodes: _allNodes,
          allUsers: _users,
        );
        _currentAclPolicy = PolicyPreserver.deepCopyMap(editedPolicy);
        _knownRuleComments =
            HuJsonCommentService.extractRuleComments(_aclController.text);
        _leadingComments =
            HuJsonCommentService.extractLeadingComments(_aclController.text);
        _updateAclControllerText();
      }
    }

    if (showConfirmation) {
      Map<String, dynamic> baseline = _serverPolicySnapshot;
      String baselineRaw = _serverRawPolicyText;
      try {
        final liveBundle =
            await PolicyPreserver.fetchServerPolicyBundleSafely(apiService);
        if (liveBundle.policy != null) {
          baseline = liveBundle.policy!;
          _serverPolicySnapshot = PolicyPreserver.deepCopyMap(baseline);
        }
        if (liveBundle.rawText.isNotEmpty) {
          baselineRaw = liveBundle.rawText;
          _serverRawPolicyText = liveBundle.rawText;
        }
      } catch (_) {
        // Repli sur le dernier snapshot serveur connu en cas d'erreur réseau transitoire
      }
      if (!mounted) return;

      final confirmed = await PolicyDiffDialog.show(
        context,
        currentPolicy: baseline,
        newPolicy: editedPolicy,
        rawCurrentText: baselineRaw,
        rawNewText: _aclController.text,
        isFr: isFr,
      );
      if (confirmed != true) return;
    }

    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      await apiService.setAclPolicy(_aclController.text);
      if (mounted) {
        setState(() {
          _currentAclPolicy = PolicyPreserver.deepCopyMap(editedPolicy);
          _serverPolicySnapshot = PolicyPreserver.deepCopyMap(editedPolicy);
          _serverRawPolicyText = _aclController.text;
          _knownRuleComments = HuJsonCommentService.extractRuleComments(
            _aclController.text,
          );
          _leadingComments = HuJsonCommentService.extractLeadingComments(
            _aclController.text,
          );
          _jsonParseError = null;
          _isLocalDraft = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  successMessage ??
                      (isFr
                          ? 'Politique ACL exportée avec succès vers le serveur.'
                          : 'ACL policy successfully exported to the server.'),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary)),
              backgroundColor: Theme.of(context).colorScheme.primary),
        );
      }
    } catch (e) {
      debugPrint(
          'Erreur lors de l\'exportation de la politique ACL vers le serveur : $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${isFr ? 'Échec de l\'exportation de la politique ACL' : 'Failed to export ACL policy'}: $e',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onError)),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchAclPolicyFromServer() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final appProvider = context.read<AppProvider>();
      final apiService = appProvider.apiService;
      final aclJsonString = await apiService.getAclPolicy();
      final decoded = JsonUtils.decodeHuJson(aclJsonString);
      final parsed = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
      _currentAclPolicy = PolicyPreserver.deepCopyMap(parsed);
      _serverPolicySnapshot = PolicyPreserver.deepCopyMap(parsed);
      _serverRawPolicyText = aclJsonString;
      _knownRuleComments =
          HuJsonCommentService.extractRuleComments(aclJsonString);
      _leadingComments =
          HuJsonCommentService.extractLeadingComments(aclJsonString);
      _jsonParseError = null;
      _setRawPolicyControllerText(aclJsonString);
      final locale = appProvider.locale;
      final isFr = locale.languageCode == 'fr';
      if (mounted) {
        setState(() => _isLocalDraft = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  isFr
                      ? 'Politique ACL récupérée du serveur.'
                      : 'ACL policy fetched from the server.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary)),
              backgroundColor: Theme.of(context).colorScheme.primary),
        );
      }
    } catch (e) {
      debugPrint(
          'Erreur lors de la récupération de la politique ACL du serveur : $e');
      if (mounted) {
        final locale = context.read<AppProvider>().locale;
        final isFr = locale.languageCode == 'fr';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${isFr ? 'Échec de la récupération de la politique ACL' : 'Failed to fetch ACL policy'}: $e',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onError)),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyPolicyLocally(
    Map<String, dynamic> policy, {
    bool markAsDraft = true,
    bool clearTemporaryRules = false,
  }) {
    setState(() {
      _currentAclPolicy = PolicyPreserver.deepCopyMap(policy);
      _aclController.text = PolicyFileService.encodePolicy(_currentAclPolicy);
      _jsonParseError = null;
      _isLocalDraft = markAsDraft;
      if (clearTemporaryRules) {
        _temporaryRules.clear();
      }
    });
  }

  Future<void> _persistClearedTemporaryRules() async {
    final serverId = context.read<AppProvider>().activeServer?.id;
    if (serverId != null) {
      await context
          .read<AppProvider>()
          .storageService
          .saveTemporaryRules(serverId, _temporaryRules);
    }
  }

  Future<void> _showPolicyStagingDialog() async {
    if (!mounted) return;
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isFr ? 'Repartir de zéro' : 'Start from scratch'),
        content: SingleChildScrollView(
          child: Text(
            isFr
                ? 'Approche recommandée :\n\n'
                    '1. Chargez un brouillon « tout autoriser » (local uniquement — le serveur reste inchangé)\n'
                    '2. Ajoutez vos grants spécifiques via le composeur\n'
                    '3. Supprimez la règle « tout autoriser » quand vos règles sont prêtes\n'
                    '4. Exportez vers le serveur uniquement quand vous êtes prêt\n\n'
                    'Ainsi personne n\'est coupé brutalement pendant que vous construisez la nouvelle policy.'
                : 'Recommended approach:\n\n'
                    '1. Load an « allow all » draft (local only — server unchanged)\n'
                    '2. Add specific grants via the composer\n'
                    '3. Remove the « allow all » rule when your rules are ready\n'
                    '4. Export to server only when you are ready\n\n'
                    'Nobody gets cut off while you build the new policy.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isFr ? 'Annuler' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('local'),
            child: Text(
              isFr ? 'Brouillon local' : 'Local draft',
              style: const TextStyle(color: Colors.orange),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('publish'),
            child: Text(
              isFr ? 'Publier tout autoriser' : 'Publish allow all',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );

    if (!mounted || choice == null) return;

    if (choice == 'local') {
      await _loadAllowAllDraftLocal();
    } else if (choice == 'publish') {
      await _publishAllowAllToServer();
    }
  }

  Future<void> _loadAllowAllDraftLocal() async {
    if (!mounted) return;
    final isFr = context.read<AppProvider>().locale.languageCode == 'fr';

    _applyPolicyLocally(
      PolicyFileService.allowAllTemplate(),
      clearTemporaryRules: true,
    );
    await _persistClearedTemporaryRules();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFr
                ? 'Brouillon « tout autoriser » chargé localement. Le serveur n\'a pas été modifié.'
                : '« Allow all » draft loaded locally. Server was not changed.',
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  Future<void> _publishAllowAllToServer() async {
    if (!mounted) return;
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(isFr ? 'Publier tout autoriser' : 'Publish allow all'),
            content: Text(
              isFr
                  ? 'La policy actuelle du serveur sera remplacée par « tout autoriser » immédiatement. Continuer ?'
                  : 'The server policy will be replaced with « allow all » immediately. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(isFr ? 'Annuler' : 'Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(
                  isFr ? 'Publier' : 'Publish',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm || !mounted) return;

    _applyPolicyLocally(
      PolicyFileService.allowAllTemplate(),
      markAsDraft: false,
      clearTemporaryRules: true,
    );
    await _persistClearedTemporaryRules();

    if (!mounted) return;

    final serverId = context.read<AppProvider>().activeServer?.id;
    if (serverId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFr
                ? 'Aucun serveur actif sélectionné.'
                : 'No active server selected.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    await _exportAclPolicyToServer(
      showConfirmation: false,
      successMessage: isFr
          ? 'Policy publiée : tout le trafic est maintenant autorisé.'
          : 'Policy published: all traffic is now allowed.',
    );
  }

  Future<void> _exportPolicyBackup() async {
    if (!mounted) return;
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    try {
      Map<String, dynamic> policy;
      try {
        policy = json.decode(_aclController.text) as Map<String, dynamic>;
      } catch (_) {
        policy = _currentAclPolicy;
      }

      PolicyFileService.validatePolicy(policy);
      final aclJsonString = PolicyFileService.encodePolicy(policy);

      final directory = await getTemporaryDirectory();
      final fileName = PolicyFileService.backupFileName();
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(aclJsonString);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: isFr
              ? 'Backup de votre policy Headscale.'
              : 'Backup of your Headscale policy.',
        ),
      );
    } catch (e) {
      debugPrint('Erreur export backup policy : $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${isFr ? 'Échec de l\'export backup' : 'Backup export failed'}: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _importPolicyFromFile() async {
    if (!mounted) return;
    final locale = context.read<AppProvider>().locale;
    final isFr = locale.languageCode == 'fr';

    try {
      SecurityService.suppressNextResumeLock = true;
      final FilePickerResult? result;
      try {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
          withData: false,
        );
      } finally {
        Future.delayed(const Duration(milliseconds: 500), () {
          SecurityService.suppressNextResumeLock = false;
        });
      }

      if (result == null || result.files.isEmpty || !mounted) return;

      final picked = result.files.single;
      final path = picked.path;
      if (path == null) {
        throw Exception(
            isFr ? 'Chemin fichier inaccessible' : 'File path unavailable');
      }

      final raw = await File(path).readAsString();
      final policy = PolicyFileService.parsePolicyContent(raw);

      if (!mounted) return;

      final publish = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isFr ? 'Importer la policy' : 'Import policy'),
          content: Text(
            isFr
                ? 'Charger en brouillon local (recommandé) ou publier immédiatement sur le serveur ?'
                : 'Load as local draft (recommended) or publish immediately to the server?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(isFr ? 'Annuler' : 'Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                isFr ? 'Brouillon local' : 'Local draft',
                style: const TextStyle(color: Colors.orange),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(isFr ? 'Publier' : 'Publish'),
            ),
          ],
        ),
      );

      if (!mounted || publish == null) return;

      _applyPolicyLocally(policy, markAsDraft: !publish);

      if (publish) {
        await _exportAclPolicyToServer(
          showConfirmation: true,
          successMessage: isFr
              ? 'Policy importée et publiée sur le serveur.'
              : 'Policy imported and published to the server.',
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isFr
                  ? 'Policy importée en brouillon local. Le serveur n\'a pas été modifié.'
                  : 'Policy imported as local draft. Server was not changed.',
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erreur import policy : $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${isFr ? 'Échec de l\'import' : 'Import failed'}: $e',
              style: TextStyle(color: Theme.of(context).colorScheme.onError),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _shareAclFile() async {
    await _exportPolicyBackup();
  }
}

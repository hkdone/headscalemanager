import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:headscalemanager/models/acl_engine_mode.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/models/version_info.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/services/acl/acl_policy_orchestrator.dart';
import 'package:headscalemanager/services/acl/alignment_diagnostic_service.dart';
import 'package:headscalemanager/services/acl/hujson_comment_service.dart';
import 'package:headscalemanager/services/acl/migration_assistant_service.dart';
import 'package:headscalemanager/services/acl/policy_infrastructure_builder.dart';
import 'package:headscalemanager/services/acl/policy_preserver.dart';
import 'package:headscalemanager/services/acl_parser_service.dart';
import 'package:headscalemanager/utils/snack_bar_utils.dart';
import 'package:headscalemanager/utils/string_utils.dart';
import 'package:headscalemanager/utils/tag_capability_helper.dart';
import 'package:headscalemanager/widgets/acl/alignment_assistant_dialog.dart';
import 'package:headscalemanager/widgets/acl/policy_diff_dialog.dart';
import 'package:provider/provider.dart';

/// Centre d'Assistance à la Bascule Nœud-par-Nœud & Serveur (Sous-Plan 09-B).
///
/// Propose 3 parcours guidés non intrusifs :
/// - Parcours A : Basculer un nœud Taggé (`tagged-devices`) → Sans Tag / OIDC
/// - Parcours B : Basculer un nœud Sans Tag → Taggé (1 clic API)
/// - Parcours C : Basculer / vérifier le serveur (Grants V29 / Hybride)
class AclMigrationCenterScreen extends StatefulWidget {
  final Node? initialNode;
  final int initialTabIndex;

  const AclMigrationCenterScreen({
    super.key,
    this.initialNode,
    this.initialTabIndex = 0,
  });

  @override
  State<AclMigrationCenterScreen> createState() =>
      _AclMigrationCenterScreenState();
}

class _AclMigrationCenterScreenState extends State<AclMigrationCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _loading = true;
  bool _busy = false;
  String? _loadError;

  List<User> _users = [];
  List<Node> _nodes = [];
  Map<String, dynamic>? _serverPolicy;
  String _serverRawPolicy = '';
  Map<String, String> _serverRuleComments = const {};
  String? _serverLeadingComments;

  // Parcours A (Taggé -> Sans Tag)
  Node? _selectedTaggedNode;
  User? _targetOwnerForTagless;
  bool _useCliMethod = false;
  bool _step1Prepared = false;
  bool _step2ReauthTriggered = false;
  TaglessTransitionReport? _step3Report;

  // Parcours B (Sans Tag -> Taggé)
  Node? _selectedUntaggedNode;
  bool _addExitNodeCap = false;
  bool _addLanSharerCap = false;
  String? _parcoursBResult;

  // Parcours C (Serveur)
  AlignmentReport? _diagnosticReport;
  List<ServerSimulationCheck> _serverSimChecks = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    _refreshState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refreshState() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final provider = context.read<AppProvider>();
      final api = provider.apiService;
      final users = await api.getUsers();
      final nodes = await api.getNodes();
      final bundle = await PolicyPreserver.fetchServerPolicyBundleSafely(api);

      if (!mounted) return;
      final tagged = nodes.where((n) => n.tags.isNotEmpty).toList();
      final untagged = nodes.where((n) => n.tags.isEmpty).toList();

      Node? initialTagged = _selectedTaggedNode;
      if (widget.initialNode != null &&
          widget.initialNode!.tags.isNotEmpty &&
          initialTagged == null) {
        initialTagged = tagged.cast<Node?>().firstWhere(
              (n) => n!.id == widget.initialNode!.id,
              orElse: () => tagged.isNotEmpty ? tagged.first : null,
            );
      } else if (initialTagged != null) {
        initialTagged = tagged.cast<Node?>().firstWhere(
              (n) => n!.id == initialTagged!.id,
              orElse: () => tagged.isNotEmpty ? tagged.first : null,
            );
      } else {
        initialTagged = tagged.isNotEmpty ? tagged.first : null;
      }

      Node? initialUntagged = _selectedUntaggedNode;
      if (widget.initialNode != null &&
          widget.initialNode!.tags.isEmpty &&
          initialUntagged == null) {
        initialUntagged = untagged.cast<Node?>().firstWhere(
              (n) => n!.id == widget.initialNode!.id,
              orElse: () => untagged.isNotEmpty ? untagged.first : null,
            );
      } else if (initialUntagged != null) {
        initialUntagged = untagged.cast<Node?>().firstWhere(
              (n) => n!.id == initialUntagged!.id,
              orElse: () => untagged.isNotEmpty ? untagged.first : null,
            );
      } else {
        initialUntagged = untagged.isNotEmpty ? untagged.first : null;
      }

      User? targetOwner = _targetOwnerForTagless;
      if (initialTagged != null) {
        targetOwner = PolicyInfrastructureBuilder.findOwnerUser(
              initialTagged,
              users,
            ) ??
            targetOwner ??
            (users.isNotEmpty ? users.first : null);
      } else if (users.isNotEmpty) {
        targetOwner ??= users.first;
      }

      final serverId = provider.activeServer?.id;
      final tempRules = serverId != null
          ? await provider.storageService.getTemporaryRules(serverId)
          : const <Map<String, dynamic>>[];

      AlignmentReport? diagReport;
      if (bundle.policy != null) {
        diagReport = AlignmentDiagnosticService.inspect(
          serverPolicy: bundle.policy,
          users: users,
          nodes: nodes,
          temporaryRules: tempRules,
          taildriveShares: provider.taildriveShares,
          serverVersion: provider.serverVersion,
          engineMode: provider.aclEngineMode,
        );
      }

      final isStep1Done = targetOwner != null &&
          AclMigrationAssistantService.isHybridNetReadyForUser(
            serverPolicy: bundle.policy,
            targetUser: targetOwner,
          );

      setState(() {
        _users = users;
        _nodes = nodes;
        _serverPolicy = bundle.policy;
        _serverRawPolicy = bundle.rawText;
        _serverRuleComments = bundle.ruleComments;
        _serverLeadingComments = bundle.leadingComments;
        _selectedTaggedNode = initialTagged;
        _targetOwnerForTagless = targetOwner;
        _selectedUntaggedNode = initialUntagged;
        _diagnosticReport = diagReport;
        _step1Prepared = isStep1Done;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _prepareWelcomeAclForParcoursA(bool isFr) async {
    final targetUser = _targetOwnerForTagless;
    if (targetUser == null) return;
    setState(() => _busy = true);
    try {
      final provider = context.read<AppProvider>();
      final serverId = provider.activeServer?.id;
      final tempRules = serverId != null
          ? await provider.storageService.getTemporaryRules(serverId)
          : const <Map<String, dynamic>>[];

      final prepared = AclMigrationAssistantService.buildPreparedWelcomePolicy(
        engineMode: provider.aclEngineMode,
        users: _users,
        nodes: _nodes,
        serverPolicy: _serverPolicy,
        targetUser: targetUser,
        temporaryRules: tempRules,
        taildriveShares: provider.taildriveShares,
        serverVersion: provider.serverVersion,
        includeUntaggedNodes: provider.includeUntaggedNodes,
      );

      final hasComments = _serverRuleComments.isNotEmpty ||
          (_serverLeadingComments != null &&
              _serverLeadingComments!.trim().isNotEmpty);
      final rawNewText = hasComments
          ? HuJsonCommentService.formatPolicyWithComments(
              prepared,
              ruleComments: _serverRuleComments,
              leadingComments: _serverLeadingComments,
            )
          : const JsonEncoder.withIndent('  ').convert(prepared);

      if (!mounted) return;
      final confirmed = await PolicyDiffDialog.show(
            context,
            currentPolicy: _serverPolicy ?? const {},
            newPolicy: prepared,
            rawCurrentText: _serverRawPolicy,
            rawNewText: rawNewText,
            isFr: isFr,
          ) ??
          false;

      if (!confirmed || !mounted) return;

      await PolicyPreserver.applyPreservingPolicy(
        apiService: provider.apiService,
        generatedPolicy: prepared,
        serverPolicy: _serverPolicy,
        rawServerPolicy: _serverRawPolicy.isNotEmpty ? _serverRawPolicy : null,
        pretty: true,
        preserveCustomRules: false,
      );

      if (!mounted) return;
      setState(() => _step1Prepared = true);
      showSafeSnackBar(
        context,
        isFr
            ? 'Filet d\'accueil hybride appliqué pour group:${normalizeUserName(targetUser.name)}.'
            : 'Hybrid welcome ACL applied for group:${normalizeUserName(targetUser.name)}.',
      );
      await _refreshState();
    } catch (e) {
      if (mounted) {
        showSafeSnackBar(context, '${isFr ? 'Erreur' : 'Error'}: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _expireTaggedNodeSession(bool isFr) async {
    final node = _selectedTaggedNode;
    if (node == null) return;

    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(isFr
                ? 'Expirer la session de "${node.name}" ?'
                : 'Expire session for "${node.name}"?'),
            content: Text(
              isFr
                  ? 'Le nœud restera visible mais devra se ré-authentifier sans tag. Sur l\'appareil, cliquez ensuite sur Reconnecter (Login) et authentifiez-vous avec le compte souhaité.'
                  : 'The node stays listed but will require re-authentication without tags. Then click Login on the device to authenticate with the target account.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(isFr ? 'Annuler' : 'Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(isFr ? 'Expirer maintenant' : 'Expire now'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<AppProvider>().apiService.expireNode(node.id);
      if (!mounted) return;
      setState(() => _step2ReauthTriggered = true);
      showSafeSnackBar(
        context,
        isFr
            ? 'Session expirée. Reconnectez l\'appareil puis cliquez sur Vérifier à l\'étape 3.'
            : 'Session expired. Reconnect device then run Step 3 verification.',
      );
    } catch (e) {
      if (mounted) {
        showSafeSnackBar(context, '${isFr ? 'Erreur' : 'Error'}: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyTaglessTransition(bool isFr) async {
    final orig = _selectedTaggedNode;
    final targetUser = _targetOwnerForTagless;
    if (orig == null || targetUser == null) return;

    setState(() => _busy = true);
    try {
      final provider = context.read<AppProvider>();
      final api = provider.apiService;
      final latestUsers = await api.getUsers();
      final latestNodes = await api.getNodes();
      final bundle = await PolicyPreserver.fetchServerPolicyBundleSafely(api);

      final report = AclMigrationAssistantService.verifyTaglessTransition(
        originalTaggedNode: orig,
        targetUser: targetUser,
        latestNodes: latestNodes,
        latestUsers: latestUsers,
        serverPolicy: bundle.policy ?? const {},
        isFr: isFr,
      );

      if (!mounted) return;
      setState(() {
        _users = latestUsers;
        _nodes = latestNodes;
        _serverPolicy = bundle.policy;
        _serverRawPolicy = bundle.rawText;
        _step3Report = report;
      });
    } catch (e) {
      if (mounted) {
        showSafeSnackBar(context, '${isFr ? 'Erreur' : 'Error'}: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reapprovePreviousRoutes(bool isFr) async {
    final orig = _selectedTaggedNode;
    final matched = _step3Report?.matchedNode;
    if (orig == null || matched == null) return;

    setState(() => _busy = true);
    try {
      final provider = context.read<AppProvider>();
      final mergedRoutes = <String>{
        ...matched.sharedRoutes,
        ...orig.sharedRoutes,
      }.toList();
      await provider.apiService.setNodeRoutes(matched.id, mergedRoutes);
      if (!mounted) return;
      showSafeSnackBar(
        context,
        isFr ? 'Routes ré-approuvées !' : 'Routes re-approved!',
      );
      await _verifyTaglessTransition(isFr);
    } catch (e) {
      if (mounted) {
        showSafeSnackBar(context, '${isFr ? 'Erreur' : 'Error'}: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _convertUntaggedToTagged(bool isFr) async {
    final node = _selectedUntaggedNode;
    if (node == null) return;

    setState(() {
      _busy = true;
      _parcoursBResult = null;
    });

    try {
      final provider = context.read<AppProvider>();
      final api = provider.apiService;
      final ownerUser = PolicyInfrastructureBuilder.findOwnerUser(node, _users);
      final ownerNorm = ownerUser != null
          ? normalizeUserName(ownerUser.name)
          : node.getNormalizedOwner();

      final newTags = TagCapabilityHelper.buildInitialTags(
        engineMode: provider.aclEngineMode,
        normalizedUser: ownerNorm,
        isExitNode: _addExitNodeCap,
        isLanSharer: _addLanSharerCap,
      );

      final updatedNodes = _nodes
          .map((n) => n.id == node.id ? n.copyWith(tags: newTags) : n)
          .toList();
      final serverId = provider.activeServer?.id;
      final tempRules = serverId != null
          ? await provider.storageService.getTemporaryRules(serverId)
          : const <Map<String, dynamic>>[];

      // 1. Pousser tagOwners à jour en préservant toutes les règles custom
      final prepPolicy = AclPolicyOrchestrator().generatePolicy(
        engineMode: provider.aclEngineMode,
        users: _users,
        nodes: updatedNodes,
        temporaryRules: tempRules,
        taildriveShares: provider.taildriveShares,
        serverVersion: provider.serverVersion,
        includeUntaggedNodes: provider.includeUntaggedNodes,
      );
      await PolicyPreserver.applyPreservingPolicy(
        apiService: api,
        generatedPolicy: prepPolicy,
        pretty: true,
        preserveCustomRules: true,
        users: _users,
        nodes: updatedNodes,
        includeUntaggedNodes: provider.includeUntaggedNodes,
      );

      // 2. Appliquer les tags via API
      await api.setTags(node.id, newTags);

      // 3. Recharger et vérifier dans le simulateur
      final latestNodes = await api.getNodes();
      final latestUsers = await api.getUsers();
      final bundle = await PolicyPreserver.fetchServerPolicyBundleSafely(api);
      final taggedNode = latestNodes.firstWhere(
        (n) => n.id == node.id,
        orElse: () => node.copyWith(tags: newTags),
      );
      final parser = AclParserService(
        aclPolicy: bundle.policy ?? prepPolicy,
        allNodes: latestNodes,
        allUsers: latestUsers,
      );
      final peers = latestNodes
          .where((n) =>
              n.id != taggedNode.id &&
              n.ipAddresses.isNotEmpty &&
              (ownerUser != null &&
                  PolicyInfrastructureBuilder.nodeBelongsToUser(n, ownerUser)))
          .toList();
      var allowedPeers = 0;
      for (final peer in peers) {
        if (parser
            .simulateConnection(
              sourceNode: taggedNode,
              destination: peer.ipAddresses.first,
            )
            .allowed) {
          allowedPeers++;
        }
      }

      if (!mounted) return;
      setState(() {
        _parcoursBResult = isFr
            ? '✅ Tags appliqués (${newTags.join(', ')}) et ACL régénérée. Flux validé avec $allowedPeers/${peers.length} appareil(s).'
            : '✅ Tags applied (${newTags.join(', ')}) and ACL regenerated. Flows verified with $allowedPeers/${peers.length} device(s).';
      });
      await _refreshState();
    } catch (e) {
      if (mounted) {
        setState(() {
          _parcoursBResult = '${isFr ? '❌ Échec' : '❌ Failed'}: $e';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _switchOrValidateServerMode(
    bool isFr, {
    required AclEngineMode targetMode,
  }) async {
    setState(() => _busy = true);
    try {
      final provider = context.read<AppProvider>();
      final serverId = provider.activeServer?.id;
      final tempRules = serverId != null
          ? await provider.storageService.getTemporaryRules(serverId)
          : const <Map<String, dynamic>>[];

      final orchestrator = AclPolicyOrchestrator();
      final generated = orchestrator.generatePolicy(
        engineMode: targetMode,
        users: _users,
        nodes: _nodes,
        temporaryRules: tempRules,
        taildriveShares: provider.taildriveShares,
        serverVersion: provider.serverVersion,
        includeUntaggedNodes: provider.includeUntaggedNodes,
      );
      final merged = PolicyPreserver.merge(
        generated,
        _serverPolicy,
        preserveCustomRules: true,
        users: _users,
        nodes: _nodes,
        includeUntaggedNodes: provider.includeUntaggedNodes,
      );

      final rawNewText = const JsonEncoder.withIndent('  ').convert(merged);
      if (!mounted) return;
      final confirmed = await PolicyDiffDialog.show(
            context,
            currentPolicy: _serverPolicy ?? const {},
            newPolicy: merged,
            rawCurrentText: _serverRawPolicy,
            rawNewText: rawNewText,
            isFr: isFr,
          ) ??
          false;
      if (!confirmed || !mounted) return;

      await provider.setAclEngineMode(targetMode);
      await PolicyPreserver.applyPreservingPolicy(
        apiService: provider.apiService,
        generatedPolicy: merged,
        serverPolicy: _serverPolicy,
        rawServerPolicy: _serverRawPolicy.isNotEmpty ? _serverRawPolicy : null,
        pretty: true,
        preserveCustomRules: false,
      );

      final checks = AclMigrationAssistantService.evaluateServerSimulation(
        policy: merged,
        users: _users,
        nodes: _nodes,
      );

      if (!mounted) return;
      setState(() => _serverSimChecks = checks);
      showSafeSnackBar(
        context,
        isFr
            ? 'Politique appliquée et vérifiée par simulation.'
            : 'Policy applied and verified by simulation.',
      );
      await _refreshState();
    } catch (e) {
      if (mounted) {
        showSafeSnackBar(context, '${isFr ? 'Erreur' : 'Error'}: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isFr = provider.locale.languageCode == 'fr';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isFr
              ? 'Centre d\'Assistance à la Bascule'
              : 'ACL Transition & Migration Center',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: isFr ? 'Actualiser' : 'Refresh',
            onPressed: _busy ? null : _refreshState,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.label_off_outlined),
              text: isFr ? 'Taggé → Sans tag' : 'Tagged → Tagless',
            ),
            Tab(
              icon: const Icon(Icons.label_outline),
              text: isFr ? 'Sans tag → Taggé' : 'Tagless → Tagged',
            ),
            Tab(
              icon: const Icon(Icons.dns_outlined),
              text: isFr ? 'Serveur (Global)' : 'Server (Global)',
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('$_loadError'),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildParcoursA(isFr, provider),
                    _buildParcoursB(isFr),
                    _buildParcoursC(isFr, provider),
                  ],
                ),
    );
  }

  Widget _buildParcoursA(bool isFr, AppProvider provider) {
    final taggedNodes = _nodes.where((n) => n.tags.isNotEmpty).toList();
    final serverUrl = provider.activeServer?.url ?? 'https://votre-headscale';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFr
                ? 'Parcours A — Passer un appareil de Taggé vers Sans Tag (OIDC / Local) sans couper les autres machines.'
                : 'Track A — Move a device from Tagged to Tagless (OIDC / Local) without disrupting the fleet.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          if (taggedNodes.isEmpty)
            Card(
              color: Colors.green.withValues(alpha: 0.1),
              child: ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(
                  isFr
                      ? 'Aucun nœud tagué restant !'
                      : 'No tagged nodes remaining!',
                ),
                subtitle: Text(
                  isFr
                      ? 'Tous vos appareils sont déjà en mode sans tag.'
                      : 'All your devices are already tagless.',
                ),
              ),
            )
          else ...[
            DropdownButtonFormField<Node>(
              isExpanded: true,
              initialValue: _selectedTaggedNode,
              decoration: InputDecoration(
                labelText: isFr ? 'Appareil tagué à basculer' : 'Tagged device',
                border: const OutlineInputBorder(),
              ),
              items: taggedNodes
                  .map(
                    (n) => DropdownMenuItem<Node>(
                      value: n,
                      child: Text('${n.name} (${n.tags.join(', ')})'),
                    ),
                  )
                  .toList(),
              onChanged: (node) {
                setState(() {
                  _selectedTaggedNode = node;
                  _step2ReauthTriggered = false;
                  _step3Report = null;
                  if (node != null) {
                    _targetOwnerForTagless =
                        PolicyInfrastructureBuilder.findOwnerUser(node, _users) ??
                            _targetOwnerForTagless;
                    _step1Prepared = _targetOwnerForTagless != null &&
                        AclMigrationAssistantService.isHybridNetReadyForUser(
                          serverPolicy: _serverPolicy,
                          targetUser: _targetOwnerForTagless!,
                        );
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            if (_users.isNotEmpty)
              DropdownButtonFormField<User>(
                isExpanded: true,
                initialValue: _targetOwnerForTagless,
                decoration: InputDecoration(
                  labelText: isFr
                      ? 'Utilisateur propriétaire cible (après bascule)'
                      : 'Target owner user (after switch)',
                  border: const OutlineInputBorder(),
                ),
                items: _users
                    .map(
                      (u) => DropdownMenuItem<User>(
                        value: u,
                        child: Text(
                          u.email != null && u.email!.isNotEmpty
                              ? '${u.name} (${u.email})'
                              : u.name,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (user) {
                  setState(() {
                    _targetOwnerForTagless = user;
                    _step1Prepared = user != null &&
                        AclMigrationAssistantService.isHybridNetReadyForUser(
                          serverPolicy: _serverPolicy,
                          targetUser: user,
                        );
                    _step3Report = null;
                  });
                },
              ),
            const SizedBox(height: 16),
            _StepCard(
              stepNumber: 1,
              statusIcon: _step1Prepared ? Icons.check_circle : Icons.circle_outlined,
              statusColor: _step1Prepared ? Colors.green : Colors.grey,
              title: isFr
                  ? 'Étape 1 — Préparer le filet hybride sur le serveur'
                  : 'Step 1 — Prepare hybrid net on server',
              subtitle: isFr
                  ? 'Vérifie que group:<utilisateur> et les règles hybrides 09-A sont déjà actifs avant de déconnecter l\'appareil.'
                  : 'Ensures group:<user> and 09-A hybrid rules are active before disconnecting the device.',
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy || _targetOwnerForTagless == null
                      ? null
                      : () => _prepareWelcomeAclForParcoursA(isFr),
                  icon: const Icon(Icons.shield_outlined),
                  label: Text(
                    isFr
                        ? (_step1Prepared
                            ? 'Mettre à jour / Vérifier l\'ACL d\'accueil'
                            : 'Préparer l\'ACL d\'accueil (Diff)')
                        : (_step1Prepared
                            ? 'Refresh / Check welcome ACL'
                            : 'Prepare welcome ACL (Diff)'),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_selectedTaggedNode != null)
              _StepCard(
                stepNumber: 2,
                statusIcon: _step2ReauthTriggered
                    ? Icons.sync
                    : Icons.circle_outlined,
                statusColor:
                    _step2ReauthTriggered ? Colors.orange : Colors.grey,
                title: isFr
                    ? 'Étape 2 — Reconnecter "${_selectedTaggedNode!.name}" sans tag'
                    : 'Step 2 — Reconnect "${_selectedTaggedNode!.name}" tagless',
                subtitle: isFr
                    ? 'Avec Headscale ≥ 0.26, une ré-authentification est requise pour quitter "tagged-devices".'
                    : 'With Headscale ≥ 0.26, re-authentication is required to leave "tagged-devices".',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment<bool>(
                          value: false,
                          icon: const Icon(Icons.smartphone),
                          label: Text(isFr ? 'Mobile / OIDC' : 'Mobile / OIDC'),
                        ),
                        ButtonSegment<bool>(
                          value: true,
                          icon: const Icon(Icons.terminal),
                          label: Text(isFr ? 'PC / Serveur CLI' : 'PC / Server CLI'),
                        ),
                      ],
                      selected: {_useCliMethod},
                      onSelectionChanged: (sel) =>
                          setState(() => _useCliMethod = sel.first),
                    ),
                    const SizedBox(height: 12),
                    if (!_useCliMethod) ...[
                      Text(
                        isFr
                            ? '1. Expirez la session ci-dessous (ou supprimez l\'ancienne fiche taguée si vous changez de compte).\n2. Sur l\'appareil, ouvrez Tailscale → Se reconnecter (Login) et choisissez ${_targetOwnerForTagless?.email ?? _targetOwnerForTagless?.name ?? 'le compte'}.'
                            : '1. Expire the current session below (or delete old entry if switching account).\n2. On the device, open Tailscale → Login and authenticate with ${_targetOwnerForTagless?.email ?? _targetOwnerForTagless?.name ?? 'the account'}.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _expireTaggedNodeSession(isFr),
                          icon: const Icon(Icons.logout),
                          label: Text(
                            isFr
                                ? 'Expirer la session actuelle (expireNode)'
                                : 'Expire current session (expireNode)',
                          ),
                        ),
                      ),
                    ] else ...[
                      Builder(
                        builder: (btnCtx) {
                          final cmd = AclMigrationAssistantService
                              .buildTailscaleReauthCommand(
                            node: _selectedTaggedNode!,
                            serverUrl: serverUrl,
                          );
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(
                                cmd,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(
                                      ClipboardData(text: cmd));
                                  if (!btnCtx.mounted) return;
                                  setState(() => _step2ReauthTriggered = true);
                                  showSafeSnackBar(
                                    btnCtx,
                                    isFr
                                        ? 'Commande copiée !'
                                        : 'Command copied!',
                                  );
                                },
                                icon: const Icon(Icons.copy),
                                label: Text(
                                  isFr
                                      ? 'Copier la commande'
                                      : 'Copy command',
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 12),
            _StepCard(
              stepNumber: 3,
              statusIcon: _step3Report == null
                  ? Icons.circle_outlined
                  : (_step3Report!.isFullyValidated
                      ? Icons.check_circle
                      : Icons.warning_amber),
              statusColor: _step3Report == null
                  ? Colors.grey
                  : (_step3Report!.isFullyValidated
                      ? Colors.green
                      : Colors.orange),
              title: isFr
                  ? 'Étape 3 — Vérifier & Valider en direct'
                  : 'Step 3 — Live Verification & Validation',
              subtitle: isFr
                  ? 'Contrôle le retour en ligne sans tag et simule les flux réseau avec les autres machines.'
                  : 'Checks tagless online state via API and simulates network flows with peers.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy || _selectedTaggedNode == null
                          ? null
                          : () => _verifyTaglessTransition(isFr),
                      icon: const Icon(Icons.radar),
                      label: Text(
                        isFr
                            ? 'Vérifier & Valider la bascule'
                            : 'Verify & Validate switch',
                      ),
                    ),
                  ),
                  if (_step3Report != null) ...[
                    const SizedBox(height: 12),
                    _buildStep3ReportBanner(_step3Report!, isFr),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep3ReportBanner(TaglessTransitionReport report, bool isFr) {
    final ok = report.isFullyValidated;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (ok ? Colors.green : Colors.orange).withValues(alpha: 0.12),
        border: Border.all(color: ok ? Colors.green : Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ok
                ? (isFr
                    ? '✅ Nœud basculé en Sans Tag et communication validée avec ${report.verifiedPeerCount} appareil(s) !'
                    : '✅ Node switched to Tagless and connectivity validated with ${report.verifiedPeerCount} device(s)!')
                : (isFr
                    ? '⚠️ Vérification partielle / actions requises :'
                    : '⚠️ Partial check / action needed:'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (report.found) ...[
            const SizedBox(height: 4),
            Text(
              isFr
                  ? 'État : ${report.isOnline ? 'En ligne' : 'Hors ligne'} • Sans tag : ${report.isUntagged ? 'Oui' : 'Non'} • Exit Node : ${report.exitNodeVerified ? 'ALLOW' : 'N/A'}'
                  : 'State: ${report.isOnline ? 'Online' : 'Offline'} • Tagless: ${report.isUntagged ? 'Yes' : 'No'} • Exit Node: ${report.exitNodeVerified ? 'ALLOW' : 'N/A'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          for (final msg in report.messages) ...[
            const SizedBox(height: 4),
            Text('• $msg', style: Theme.of(context).textTheme.bodySmall),
          ],
          if (report.missingRoutes.isNotEmpty) ...[
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _busy ? null : () => _reapprovePreviousRoutes(isFr),
              icon: const Icon(Icons.alt_route),
              label: Text(
                isFr
                    ? 'Ré-approuver ses routes précédentes'
                    : 'Re-approve previous routes',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParcoursB(bool isFr) {
    final untaggedNodes = _nodes.where((n) => n.tags.isEmpty).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFr
                ? 'Parcours B — Convertir un appareil Sans Tag en nœud Taggé (1 clic API, sans toucher à l\'appareil).'
                : 'Track B — Convert a Tagless device to Tagged (1 API click, no device re-auth required).',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          if (untaggedNodes.isEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.blue),
                title: Text(
                  isFr
                      ? 'Aucun nœud sans tag détecté.'
                      : 'No tagless nodes detected.',
                ),
              ),
            )
          else ...[
            DropdownButtonFormField<Node>(
              isExpanded: true,
              initialValue: _selectedUntaggedNode,
              decoration: InputDecoration(
                labelText:
                    isFr ? 'Appareil sans tag à taguer' : 'Tagless device',
                border: const OutlineInputBorder(),
              ),
              items: untaggedNodes
                  .map(
                    (n) => DropdownMenuItem<Node>(
                      value: n,
                      child: Text('${n.name} (${n.user})'),
                    ),
                  )
                  .toList(),
              onChanged: (node) => setState(() {
                _selectedUntaggedNode = node;
                _parcoursBResult = null;
              }),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Exit Node'),
              value: _addExitNodeCap,
              onChanged: (v) => setState(() => _addExitNodeCap = v ?? false),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('LAN Sharer'),
              value: _addLanSharerCap,
              onChanged: (v) => setState(() => _addLanSharerCap = v ?? false),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy || _selectedUntaggedNode == null
                    ? null
                    : () => _convertUntaggedToTagged(isFr),
                icon: const Icon(Icons.label),
                label: Text(
                  isFr
                      ? 'Appliquer le tag, régénérer et vérifier'
                      : 'Apply tag, regenerate & verify',
                ),
              ),
            ),
            if (_parcoursBResult != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_parcoursBResult!),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildParcoursC(bool isFr, AppProvider provider) {
    final supportsGrantsV29 = VersionInfo.checkVersionAtLeast(
      provider.serverVersion,
      '0.29.0',
    );
    final issueCount = _diagnosticReport?.issues.length ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isFr
                ? 'Parcours C — Audit pré-bascule, application avec Diff visuel et contrôle automatique des flux pour chaque utilisateur.'
                : 'Track C — Pre-switch audit, visual Diff apply, and per-user flow simulation.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(
                issueCount == 0 ? Icons.verified_user : Icons.health_and_safety,
                color: issueCount == 0 ? Colors.green : Colors.orange,
              ),
              title: Text(
                issueCount == 0
                    ? (isFr
                        ? 'Diagnostic ACL sain (0 anomalie)'
                        : 'ACL diagnostic clean (0 issues)')
                    : (isFr
                        ? '$issueCount point(s) d\'alignement détecté(s)'
                        : '$issueCount alignment issue(s) detected'),
              ),
              trailing: TextButton(
                onPressed: () async {
                  final changed = await AlignmentAssistantDialog.show(context);
                  if (changed && mounted) await _refreshState();
                },
                child: Text(isFr ? 'Inspecter' : 'Inspect'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFr
                        ? 'Moteur actuel : ${provider.aclEngineMode.name} • Hybride sans tag : ${provider.includeUntaggedNodes ? 'Actif' : 'Quarantaine'}'
                        : 'Active engine: ${provider.aclEngineMode.name} • Tagless Hybrid: ${provider.includeUntaggedNodes ? 'On' : 'Quarantine'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (supportsGrantsV29)
                        FilledButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _switchOrValidateServerMode(
                                    isFr,
                                    targetMode: AclEngineMode.grantsV29,
                                  ),
                          icon: const Icon(Icons.auto_fix_high),
                          label: Text(
                            isFr
                                ? 'Appliquer Grants V29 + Hybride (Diff)'
                                : 'Apply Grants V29 + Hybrid (Diff)',
                          ),
                        ),
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _switchOrValidateServerMode(
                                  isFr,
                                  targetMode: AclEngineMode.standard,
                                ),
                        icon: const Icon(Icons.layers_outlined),
                        label: Text(
                          isFr
                              ? 'Appliquer Standard + Hybride (Diff)'
                              : 'Apply Standard + Hybrid (Diff)',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_serverSimChecks.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              isFr
                  ? 'Contrôle post-bascule par utilisateur'
                  : 'Post-switch simulation per user',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            for (final check in _serverSimChecks)
              Card(
                child: ListTile(
                  leading: Icon(
                    check.allPassed ? Icons.check_circle : Icons.warning_amber,
                    color: check.allPassed ? Colors.green : Colors.orange,
                  ),
                  title: Text(check.user.name),
                  subtitle: Text(
                    isFr
                        ? '${check.nodeCount} nœud(s) • ${check.passedFlows}/${check.totalFlows} flux testé(s) OK'
                        : '${check.nodeCount} node(s) • ${check.passedFlows}/${check.totalFlows} tested flow(s) OK',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int stepNumber;
  final IconData statusIcon;
  final Color statusColor;
  final String title;
  final String subtitle;
  final Widget child;

  const _StepCard({
    required this.stepNumber,
    required this.statusIcon,
    required this.statusColor,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

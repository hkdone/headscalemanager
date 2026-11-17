import 'dart:convert';
import 'package:headscalemanager/models/acl_engine_mode.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/taildrive_share.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/models/version_info.dart';
import 'package:headscalemanager/services/acl/hujson_comment_service.dart';
import 'package:headscalemanager/services/acl/policy_infrastructure_builder.dart';
import 'package:headscalemanager/services/acl/policy_preserver.dart';
import 'package:headscalemanager/utils/ip_utils.dart';
import 'package:headscalemanager/utils/string_utils.dart';

enum AlignmentIssueSeverity { critical, warning, info }

enum AlignmentIssueType {
  doubleProfileLocalOidc,
  malformedGroupMembers,
  invalidOrMissingTagOwners,
  legacyAutoApproversExitNodes,
  legacyOrDottedTags,
  invalidDnsNodeNames,
  incompatibleEngineOrVersion,
  cascadeRuleReferencesUpdated,
  brokenRuleReferences,
}

/// Action corrective ciblant un nœud Headscale (tags ou renommage DNS-1123).
class AlignmentNodeAction {
  final String nodeId;
  final String nodeName;
  final List<String>? newTags;
  final String? newNodeName;
  final String summaryFr;
  final String summaryEn;

  const AlignmentNodeAction({
    required this.nodeId,
    required this.nodeName,
    this.newTags,
    this.newNodeName,
    required this.summaryFr,
    required this.summaryEn,
  });
}

/// Anomalie détectée par [AlignmentDiagnosticService].
class AlignmentIssue {
  final AlignmentIssueType type;
  final AlignmentIssueSeverity severity;
  final String titleFr;
  final String titleEn;
  final String descriptionFr;
  final String descriptionEn;
  final List<String> affectedItems;
  final bool canAutoFixPolicy;
  final bool canAutoFixNodes;
  final List<AlignmentNodeAction> nodeActions;

  const AlignmentIssue({
    required this.type,
    required this.severity,
    required this.titleFr,
    required this.titleEn,
    required this.descriptionFr,
    required this.descriptionEn,
    this.affectedItems = const [],
    this.canAutoFixPolicy = false,
    this.canAutoFixNodes = false,
    this.nodeActions = const [],
  });
}

/// Résultat complet du diagnostic d'alignement ACL + nœuds + règles locales.
class AlignmentReport {
  final List<AlignmentIssue> issues;
  final Map<String, dynamic>? alignedPolicy;
  final bool policyHasChanges;
  final List<Map<String, dynamic>>? alignedTemporaryRules;
  final List<TaildriveShare>? alignedTaildriveShares;

  /// Signatures de commentaires HuJSON déplacées suite à la réécriture
  /// d'une règle (`oldSignature -> newSignature`).
  final Map<String, String> migratedRuleCommentKeys;

  const AlignmentReport({
    required this.issues,
    required this.alignedPolicy,
    required this.policyHasChanges,
    this.alignedTemporaryRules,
    this.alignedTaildriveShares,
    this.migratedRuleCommentKeys = const {},
  });

  bool get isClean => issues.isEmpty;

  bool get hasPolicyFix => policyHasChanges && alignedPolicy != null;

  bool get hasLocalConfigFixes =>
      alignedTemporaryRules != null || alignedTaildriveShares != null;

  bool get hasNodeFixes => issues.any(
        (i) => i.canAutoFixNodes && i.nodeActions.isNotEmpty,
      );

  List<AlignmentNodeAction> get allNodeActions =>
      issues.expand((i) => i.nodeActions).toList();

  int get criticalCount =>
      issues.where((i) => i.severity == AlignmentIssueSeverity.critical).length;
}

class _CascadeRewrites {
  /// Ex: `'group:jean.dupont' -> 'group:jean-dupont'`
  final Map<String, String> groupRenames = {};

  /// Ex: `'bob' -> 'bob@'`, `'bob@headscale.local' -> 'bob@'`
  final Map<String, String> userMemberRewrites = {};

  /// Ex: `'tag:jean.dupont-client' -> ['tag:jean-dupont-client']`
  /// ou `'tag:bob-client;exit-node' -> ['tag:bob-client', 'tag:bob-exit-node']`
  final Map<String, List<String>> tagReplacements = {};

  final Set<String> activeLegacyNodeTags = {};
  final List<String> cascadedRuleItems = [];
  final Map<String, String> migratedCommentKeys = {};

  bool get hasAnyRewrite =>
      groupRenames.isNotEmpty ||
      userMemberRewrites.isNotEmpty ||
      tagReplacements.isNotEmpty;
}

/// Service d'audit intelligent détectant les désalignements entre les comptes
/// (locaux, OIDC mobiles), les nœuds (tags legacy, noms DNS-1123), la
/// politique ACL serveur et les règles spécifiques locales, puis répercutant
/// chaque alignement en cascade partout (`acls`, `grants`, `ssh`, `nodeAttrs`,
/// `autoApprovers`, `tests`, `temporaryRules`, `taildriveShares`).
class AlignmentDiagnosticService {
  static AlignmentReport inspect({
    required List<User> users,
    required List<Node> nodes,
    Map<String, dynamic>? serverPolicy,
    String? serverVersion,
    AclEngineMode engineMode = AclEngineMode.standard,
    List<Map<String, dynamic>> temporaryRules = const [],
    List<TaildriveShare> taildriveShares = const [],
  }) {
    final issues = <AlignmentIssue>[];
    final workingPolicy = serverPolicy != null
        ? PolicyPreserver.deepCopyMap(serverPolicy)
        : null;
    final originalEncoded =
        serverPolicy != null ? jsonEncode(serverPolicy) : null;
    final rewrites = _CascadeRewrites();

    final isPre26 = VersionInfo.isPreV26(serverVersion);
    final supportsDns1123 = serverVersion == null ||
        serverVersion.trim().isEmpty ||
        serverVersion == 'unknown' ||
        VersionInfo.checkVersionAtLeast(serverVersion, '0.27.0');
    final supportsGrants = serverVersion == null ||
        serverVersion.trim().isEmpty ||
        serverVersion == 'unknown' ||
        VersionInfo.checkVersionAtLeast(serverVersion, '0.29.0');

    // 0. Cohérence version serveur <-> mode ACL (grants vs sans grants)
    _checkEngineVersionCompatibility(
      workingPolicy: workingPolicy,
      serverVersion: serverVersion,
      engineMode: engineMode,
      supportsGrants: supportsGrants,
      issues: issues,
    );

    // 1. Double profil Local + OIDC ou nœuds OIDC sans tags à côté de tagués
    _checkDoubleProfileLocalOidc(
      users: users,
      nodes: nodes,
      workingPolicy: workingPolicy,
      isPre26: isPre26,
      issues: issues,
    );

    // 2. Membres de "groups" mal formés & clés de groupes non normalisées (. -> -)
    if (workingPolicy != null) {
      _checkGroupsAndMembers(
        users: users,
        workingPolicy: workingPolicy,
        isPre26: isPre26,
        rewrites: rewrites,
        issues: issues,
      );
    }

    // 3. Propriétaires "tagOwners" invalides ou tags actifs manquants
    if (workingPolicy != null) {
      _checkTagOwners(
        users: users,
        nodes: nodes,
        workingPolicy: workingPolicy,
        isPre26: isPre26,
        rewrites: rewrites,
        issues: issues,
      );
    }

    // 4. Ancien bloc autoApprovers.exitNodes (supprimé en >= 0.26)
    if (workingPolicy != null) {
      _checkLegacyAutoApproversExitNodes(
        workingPolicy: workingPolicy,
        isPre26: isPre26,
        issues: issues,
      );
    }

    // 5. Tags fusionnés (;) ou contenant des points (.) selon le moteur actif
    _checkLegacyOrDottedTags(
      users: users,
      nodes: nodes,
      workingPolicy: workingPolicy,
      engineMode: engineMode,
      rewrites: rewrites,
      issues: issues,
    );

    // 6. Noms de machines non conformes RFC 1123 (exigé en >= 0.27)
    _checkInvalidDnsNodeNames(
      nodes: nodes,
      supportsDns1123: supportsDns1123,
      issues: issues,
    );

    // 7. Découvrir aussi les group:/tag:/user mal formés uniquement présents
    // dans les règles (grants/acls/ssh/nodeAttrs/tests/temporaryRules/taildrive)
    if (workingPolicy != null && !isPre26) {
      _discoverRuleLevelRewrites(
        users: users,
        workingPolicy: workingPolicy,
        engineMode: engineMode,
        temporaryRules: temporaryRules,
        taildriveShares: taildriveShares,
        rewrites: rewrites,
      );
    }

    // 8. Répercuter EN CASCADE toutes les réécritures dans l'ensemble de la
    // politique (acls, grants, ssh, nodeAttrs, autoApprovers, tests, tagOwners)
    // ET dans les règles spécifiques / Taildrive locales !
    List<Map<String, dynamic>>? alignedTempRules;
    List<TaildriveShare>? alignedTaildrive;

    if (workingPolicy != null && rewrites.hasAnyRewrite) {
      _applyCascadeRewritesToPolicy(
        workingPolicy: workingPolicy,
        rewrites: rewrites,
      );
    }

    if (rewrites.hasAnyRewrite) {
      alignedTempRules = _applyCascadeRewritesToTemporaryRules(
        temporaryRules: temporaryRules,
        rewrites: rewrites,
      );
      alignedTaildrive = _applyCascadeRewritesToTaildrive(
        taildriveShares: taildriveShares,
        rewrites: rewrites,
      );
    }

    if (rewrites.cascadedRuleItems.isNotEmpty) {
      issues.add(
        AlignmentIssue(
          type: AlignmentIssueType.cascadeRuleReferencesUpdated,
          severity: AlignmentIssueSeverity.warning,
          titleFr:
              'Références mises à jour en cascade dans les règles (${rewrites.cascadedRuleItems.length})',
          titleEn:
              'Rule references updated in cascade (${rewrites.cascadedRuleItems.length})',
          descriptionFr:
              'Pour éviter qu\'aucune règle spécifique (AdGuard DNS, Exit Node, SSH, Taildrive, tests…) ne soit cassée après l\'alignement d\'un groupe, d\'un "@" ou d\'un tag (. → -), toutes les références ont été répercutées automatiquement.',
          descriptionEn:
              'To keep specific rules (AdGuard DNS, Exit Node, SSH, Taildrive, tests…) working after group, "@", or tag (. → -) alignment, all references were automatically updated in cascade.',
          affectedItems: rewrites.cascadedRuleItems.toSet().toList(),
          canAutoFixPolicy: workingPolicy != null,
        ),
      );
    }

    // 9. Contrôle final : signaler toute référence résiduelle pointant vers un
    // groupe ou tag qui n'existe toujours pas après alignement.
    if (workingPolicy != null) {
      _checkBrokenRuleReferences(
        users: users,
        nodes: nodes,
        workingPolicy: workingPolicy,
        temporaryRules: alignedTempRules ?? temporaryRules,
        taildriveShares: alignedTaildrive ?? taildriveShares,
        issues: issues,
      );
    }

    final policyChanged = workingPolicy != null &&
        originalEncoded != null &&
        jsonEncode(workingPolicy) != originalEncoded;

    return AlignmentReport(
      issues: issues,
      alignedPolicy: policyChanged ? workingPolicy : null,
      policyHasChanges: policyChanged,
      alignedTemporaryRules: alignedTempRules,
      alignedTaildriveShares: alignedTaildrive,
      migratedRuleCommentKeys: Map<String, String>.from(
        rewrites.migratedCommentKeys,
      ),
    );
  }

  static void _checkEngineVersionCompatibility({
    required Map<String, dynamic>? workingPolicy,
    required String? serverVersion,
    required AclEngineMode engineMode,
    required bool supportsGrants,
    required List<AlignmentIssue> issues,
  }) {
    final hasPolicyGrants = workingPolicy != null &&
        workingPolicy['grants'] is List &&
        (workingPolicy['grants'] as List).isNotEmpty;
    final hasPolicyAcls = workingPolicy != null &&
        workingPolicy['acls'] is List &&
        (workingPolicy['acls'] as List).isNotEmpty;

    if (!supportsGrants) {
      if (hasPolicyGrants) {
        issues.add(
          AlignmentIssue(
            type: AlignmentIssueType.incompatibleEngineOrVersion,
            severity: AlignmentIssueSeverity.critical,
            titleFr:
                'Bloc "grants" incompatible avec Headscale ${serverVersion ?? "< 0.29"}',
            titleEn:
                '"grants" block incompatible with Headscale ${serverVersion ?? "< 0.29"}',
            descriptionFr:
                'La politique active contient des règles "grants", supportées uniquement à partir de Headscale 0.29.0. Sur ce serveur, utilisez le moteur Standard ("acls") ou mettez Headscale à jour.',
            descriptionEn:
                'Active policy contains "grants" rules, which require Headscale 0.29.0+. Use the Standard engine ("acls") on this server or upgrade Headscale.',
            affectedItems: [
              'Serveur : ${serverVersion ?? "?"}',
              'grants (${(workingPolicy['grants'] as List).length})',
            ],
          ),
        );
      } else if (engineMode == AclEngineMode.grantsV29) {
        issues.add(
          AlignmentIssue(
            type: AlignmentIssueType.incompatibleEngineOrVersion,
            severity: AlignmentIssueSeverity.warning,
            titleFr:
                'Moteur Grants V29 sélectionné sur serveur < 0.29 (${serverVersion ?? "?"})',
            titleEn:
                'Grants V29 engine selected on server < 0.29 (${serverVersion ?? "?"})',
            descriptionFr:
                'Headscale < 0.29 ne supporte pas les "grants". L\'application bascule automatiquement sur le moteur Standard ("acls") pour ce serveur.',
            descriptionEn:
                'Headscale < 0.29 does not support "grants". The app automatically falls back to the Standard engine ("acls") for this server.',
            affectedItems: ['Moteur : Grants V29 → Fallback Standard'],
          ),
        );
      }
      return;
    }

    if (engineMode == AclEngineMode.grantsV29 &&
        !hasPolicyGrants &&
        hasPolicyAcls) {
      issues.add(
        AlignmentIssue(
          type: AlignmentIssueType.incompatibleEngineOrVersion,
          severity: AlignmentIssueSeverity.info,
          titleFr:
              'Serveur prêt pour Grants V29 (politique encore en "acls" seul)',
          titleEn:
              'Server ready for Grants V29 (policy still uses "acls" only)',
          descriptionFr:
              'Votre serveur (${serverVersion ?? "0.29+"}) est configuré sur le moteur Grants V29, mais la politique active sur le serveur ne contient pas encore de "grants". Régénérez la politique depuis l\'écran ACL si vous souhaitez passer aux Grants avec routage "via".',
          descriptionEn:
              'Your server (${serverVersion ?? "0.29+"}) is set to Grants V29, but the live policy has no "grants" yet. Regenerate policy from the ACL screen when ready to use Grants with "via" routing.',
        ),
      );
    }
  }

  static void _checkDoubleProfileLocalOidc({
    required List<User> users,
    required List<Node> nodes,
    required Map<String, dynamic>? workingPolicy,
    required bool isPre26,
    required List<AlignmentIssue> issues,
  }) {
    final siblingSlugs = <String, Set<User>>{};
    for (final user in users) {
      final norms = PolicyInfrastructureBuilder.candidateNormalizedNames(user);
      for (final norm in norms) {
        siblingSlugs.putIfAbsent(norm, () => <User>{}).add(user);
      }
    }

    final affected = <String>[];
    var hasPolicyAutoFix = false;
    var hasMultiAccountSplit = false;
    var hasUntaggedOidcWithTagged = false;

    Map<String, dynamic>? groupsMap;
    Map<String, dynamic>? tagOwnersMap;
    if (workingPolicy != null) {
      groupsMap = (workingPolicy['groups'] is Map)
          ? Map<String, dynamic>.from(workingPolicy['groups'] as Map)
          : <String, dynamic>{};
      tagOwnersMap = (workingPolicy['tagOwners'] is Map)
          ? Map<String, dynamic>.from(workingPolicy['tagOwners'] as Map)
          : <String, dynamic>{};
    }

    // A. Groupes avec 2+ comptes Headscale partageant le même radical
    final inspectedUserSets = <String>{};
    for (final entry in siblingSlugs.entries) {
      if (entry.value.length < 2) continue;
      final accountList = entry.value.toList();
      final setKey = (accountList.map((u) => u.id).toList()..sort()).join('|');
      if (!inspectedUserSets.add(setKey)) continue;

      hasMultiAccountSplit = true;
      final groupSlug = entry.key;
      final groupName = 'group:$groupSlug';
      affected.add(
        '${accountList.map((u) => u.email?.isNotEmpty == true ? '${u.name} (${u.email})' : u.name).join(' + ')} → $groupName',
      );

      if (!isPre26 && workingPolicy != null && groupsMap != null) {
        final mergedMembers = <String>{};
        final existing = groupsMap[groupName];
        if (existing is List) {
          for (final m in existing) {
            final s = m.toString().trim();
            if (s.contains('@') ||
                s.startsWith('group:') ||
                s.startsWith('autogroup:')) {
              mergedMembers.add(s);
            }
          }
        }
        for (final acc in accountList) {
          mergedMembers.addAll(
            resolveAclGroupMembers(acc.name, email: acc.email),
          );
        }
        final beforeList = (existing is List)
            ? existing.map((e) => e.toString()).toList()
            : <String>[];
        final afterList = mergedMembers.toList()..sort();
        if (jsonEncode(beforeList..sort()) != jsonEncode(afterList)) {
          groupsMap[groupName] = afterList;
          hasPolicyAutoFix = true;
        }
      }
    }

    // B. Utilisateur OIDC unique ayant à la fois un nom local et un email distinct,
    // ou des nœuds sans tag à côté d'anciens nœuds tagués
    for (final user in users) {
      final norm = normalizeUserName(user.name);
      final groupName = 'group:$norm';
      final userNodes = nodes
          .where(
              (n) => PolicyInfrastructureBuilder.nodeBelongsToUser(n, user))
          .toList();
      final hasTagged = userNodes.any((n) => n.tags.isNotEmpty);
      final hasUntagged = userNodes.any((n) => n.tags.isEmpty);
      final hasDistinctOidcEmail = user.email != null &&
          user.email!.contains('@') &&
          user.email!.trim().toLowerCase() != user.name.trim().toLowerCase();

      if (!isPre26 &&
          workingPolicy != null &&
          groupsMap != null &&
          hasDistinctOidcEmail) {
        final expected = resolveAclGroupMembers(user.name, email: user.email);
        final currentRaw = groupsMap[groupName];
        final currentList = (currentRaw is List)
            ? currentRaw.map((e) => e.toString()).toList()
            : <String>[];
        final missing =
            expected.where((m) => !currentList.contains(m)).toList();
        if (missing.isNotEmpty) {
          hasPolicyAutoFix = true;
          final updated = <String>{...currentList, ...expected}.toList()
            ..sort();
          groupsMap[groupName] = updated;
          affected.add('$groupName (+ ${missing.join(', ')})');
        }

        if (tagOwnersMap != null &&
            tagOwnersMap.containsKey('tag:$norm-client')) {
          final currentOwners = (tagOwnersMap['tag:$norm-client'] is List)
              ? (tagOwnersMap['tag:$norm-client'] as List)
                  .map((e) => e.toString())
                  .toList()
              : <String>[];
          final updatedOwners = <String>{
            ...currentOwners,
            groupName,
            user.email!.trim(),
          }.toList();
          if (jsonEncode(currentOwners) != jsonEncode(updatedOwners)) {
            tagOwnersMap['tag:$norm-client'] = updatedOwners;
            hasPolicyAutoFix = true;
          }
        }
      }

      if (hasTagged && hasUntagged) {
        final policyContainsGroup = _policyReferencesGroupInRules(
          workingPolicy,
          groupName,
        );
        if (workingPolicy != null && !policyContainsGroup) {
          hasUntaggedOidcWithTagged = true;
          affected.add(
            '${user.name}: ${userNodes.where((n) => n.tags.isEmpty).length} sans tag / ${userNodes.where((n) => n.tags.isNotEmpty).length} tagué(s)',
          );
        }
      }
    }

    if (hasPolicyAutoFix && workingPolicy != null) {
      if (groupsMap != null) workingPolicy['groups'] = groupsMap;
      if (tagOwnersMap != null) workingPolicy['tagOwners'] = tagOwnersMap;
    }

    if (affected.isEmpty) return;

    issues.add(
      AlignmentIssue(
        type: AlignmentIssueType.doubleProfileLocalOidc,
        severity: (hasUntaggedOidcWithTagged || hasMultiAccountSplit)
            ? AlignmentIssueSeverity.warning
            : AlignmentIssueSeverity.info,
        titleFr: 'Identités Local + OIDC ou parc mixte à unifier',
        titleEn: 'Local + OIDC identities or mixed fleet to unify',
        descriptionFr: hasMultiAccountSplit
            ? 'Plusieurs profils (local + OIDC, ex: mobile reconnecté en OIDC) partagent le même identifiant. Unifier leurs membres dans le même groupe ACL évite toute perte d\'accès lors des régénérations. Si deux comptes distincts ont chacun des nœuds sur Headscale ≥ 0.28, conservez les deux identifiants unifiés dans le groupe ou ré-enregistrez les anciens nœuds sous le compte OIDC.'
            : 'Des identifiants OIDC/locaux complémentaires ou des nœuds sans tag coexistent avec des nœuds tagués. La mise en conformité garantit que le groupe ACL reconnaît tous vos appareils lors des mises à jour.',
        descriptionEn: hasMultiAccountSplit
            ? 'Multiple user profiles (local + OIDC, e.g. mobile re-registered via OIDC) share the same normalized identity. Unifying their members into the same ACL group prevents rule loss on regeneration.'
            : 'Complementary OIDC/local identifiers or untagged nodes coexist with tagged nodes. Aligning group membership ensures all devices stay covered during updates.',
        affectedItems: affected.toSet().toList(),
        canAutoFixPolicy: hasPolicyAutoFix,
      ),
    );
  }

  static bool _policyReferencesGroupInRules(
    Map<String, dynamic>? policy,
    String groupName,
  ) {
    if (policy == null) return false;
    bool listContains(dynamic list) =>
        list is List && list.any((e) => e.toString().startsWith(groupName));

    final grants = policy['grants'];
    if (grants is List) {
      for (final g in grants) {
        if (g is Map &&
            (listContains(g['src']) || listContains(g['dst']))) {
          return true;
        }
      }
    }
    final acls = policy['acls'];
    if (acls is List) {
      for (final a in acls) {
        if (a is Map &&
            (listContains(a['src']) || listContains(a['dst']))) {
          return true;
        }
      }
    }
    return false;
  }

  static void _checkGroupsAndMembers({
    required List<User> users,
    required Map<String, dynamic> workingPolicy,
    required bool isPre26,
    required _CascadeRewrites rewrites,
    required List<AlignmentIssue> issues,
  }) {
    if (isPre26) return;
    final groupsRaw = workingPolicy['groups'];
    if (groupsRaw is! Map) return;

    final userByGroupName = <String, User>{};
    for (final u in users) {
      userByGroupName['group:${normalizeUserName(u.name)}'] = u;
    }

    final affected = <String>[];
    final fixedGroups = <String, dynamic>{};
    var changed = false;

    for (final entry in groupsRaw.entries) {
      final rawGroupKey = entry.key.toString();
      var targetGroupKey = rawGroupKey;

      // Normaliser les anciennes clés de groupe (ex: group:jean.dupont -> group:jean-dupont)
      if (rawGroupKey.startsWith('group:')) {
        final slug = rawGroupKey.substring('group:'.length);
        final normalizedSlug = normalizeUserName(slug);
        final candidateKey = 'group:$normalizedSlug';
        if (candidateKey != rawGroupKey &&
            (slug.contains('.') ||
                slug != slug.toLowerCase() ||
                userByGroupName.containsKey(candidateKey))) {
          targetGroupKey = candidateKey;
          rewrites.groupRenames[rawGroupKey] = candidateKey;
          affected.add('$rawGroupKey → $candidateKey');
          changed = true;
        }
      }

      if (entry.value is! List) {
        fixedGroups[targetGroupKey] = entry.value;
        continue;
      }

      final members =
          (entry.value as List).map((e) => e.toString().trim()).toList();
      final updated = <String>[];
      var groupModified = false;

      final matchedUser = userByGroupName[targetGroupKey];
      final isPureLocalCliUser = matchedUser != null &&
          !matchedUser.name.contains('@') &&
          (matchedUser.email == null || matchedUser.email!.trim().isEmpty);

      for (final member in members) {
        if (member.isEmpty) {
          groupModified = true;
          continue;
        }
        if (member.startsWith('group:') || member.startsWith('autogroup:')) {
          updated.add(member);
          continue;
        }
        if (!member.contains('@')) {
          final canonical = '$member@';
          updated.add(canonical);
          rewrites.userMemberRewrites[member] = canonical;
          affected.add('$targetGroupKey: "$member" → "$canonical"');
          groupModified = true;
          continue;
        }
        if (isPureLocalCliUser) {
          final prefix = member.split('@').first;
          final suffix = member.split('@').last;
          if (prefix == matchedUser.name && suffix.isNotEmpty) {
            final canonical = '${matchedUser.name}@';
            updated.add(canonical);
            rewrites.userMemberRewrites[member] = canonical;
            affected.add('$targetGroupKey: "$member" → "$canonical"');
            groupModified = true;
            continue;
          }
        }
        updated.add(member);
      }

      if (isPureLocalCliUser &&
          !updated.contains('${matchedUser.name}@')) {
        updated.add('${matchedUser.name}@');
        affected.add('$targetGroupKey: + "${matchedUser.name}@"');
        groupModified = true;
      }

      if (groupModified) changed = true;

      final existingList = (fixedGroups[targetGroupKey] is List)
          ? (fixedGroups[targetGroupKey] as List)
              .map((e) => e.toString())
              .toList()
          : const <String>[];
      fixedGroups[targetGroupKey] =
          <String>{...existingList, ...updated}.toList();
    }

    if (!changed) return;

    workingPolicy['groups'] = fixedGroups;
    issues.add(
      AlignmentIssue(
        type: AlignmentIssueType.malformedGroupMembers,
        severity: AlignmentIssueSeverity.critical,
        titleFr:
            'Groupes ou membres incompatibles Policy v2 (>= 0.26) / normalisation (. → -)',
        titleEn:
            'Groups or members incompatible with Policy v2 (>= 0.26) / normalization (. → -)',
        descriptionFr:
            'Headscale ≥ 0.26 exige un "@" dans chaque membre, attend "nom@" pour les comptes locaux sans email, et des noms de groupes normalisés (sans "."). Les règles et partages pointant vers ces groupes seront mis à jour en cascade.',
        descriptionEn:
            'Headscale ≥ 0.26 requires "@" in every group member, expects "username@" for local accounts without email, and normalized group names (no "."). All downstream rules referencing them will be updated in cascade.',
        affectedItems: affected.toSet().toList(),
        canAutoFixPolicy: true,
      ),
    );
  }

  static void _checkTagOwners({
    required List<User> users,
    required List<Node> nodes,
    required Map<String, dynamic> workingPolicy,
    required bool isPre26,
    required _CascadeRewrites rewrites,
    required List<AlignmentIssue> issues,
  }) {
    final tagOwnersRaw = workingPolicy['tagOwners'];
    final tagOwners = (tagOwnersRaw is Map)
        ? Map<String, dynamic>.from(tagOwnersRaw)
        : <String, dynamic>{};

    final userByNorm = <String, User>{};
    for (final u in users) {
      userByNorm[normalizeUserName(u.name)] = u;
    }

    final affected = <String>[];
    var changed = false;

    if (!isPre26) {
      for (final key in tagOwners.keys.toList()) {
      final rawList = tagOwners[key];
      if (rawList is! List) continue;
      final cleaned = <String>[];
      var tagChanged = false;
      for (final o in rawList) {
        final owner = o.toString().trim();
        if (owner.isEmpty) {
          tagChanged = true;
          continue;
        }
        if (owner.startsWith('group:') ||
            owner.startsWith('autogroup:') ||
            owner.contains('@')) {
          cleaned.add(owner);
        } else {
          final norm = normalizeUserName(owner);
          final replacement =
              userByNorm.containsKey(norm) ? 'group:$norm' : '$owner@';
          cleaned.add(replacement);
          rewrites.userMemberRewrites[owner] = replacement;
          affected.add('$key: "$owner" → "$replacement"');
          tagChanged = true;
        }
      }
        if (tagChanged) {
          tagOwners[key] = cleaned.toSet().toList();
          changed = true;
        }
      }
    }

    for (final node in nodes) {
      final ownerNorm = node.getNormalizedOwner();
      final fallbackGroup = (ownerNorm.isNotEmpty &&
              ownerNorm != 'tagged-devices' &&
              ownerNorm != 'n-a' &&
              ownerNorm != 'na')
          ? 'group:$ownerNorm'
          : (users.isNotEmpty
              ? 'group:${normalizeUserName(users.first.name)}'
              : null);

      for (final rawTag in node.tags) {
        if (!rawTag.startsWith('tag:')) continue;
        final existing = tagOwners[rawTag];
        if (existing is! List || existing.isEmpty) {
          if (fallbackGroup != null) {
            tagOwners[rawTag] = [fallbackGroup];
            affected.add('+ $rawTag → [$fallbackGroup] (${node.name})');
            changed = true;
          }
        }
      }
    }

    if (!changed) return;

    workingPolicy['tagOwners'] = tagOwners;
    issues.add(
      AlignmentIssue(
        type: AlignmentIssueType.invalidOrMissingTagOwners,
        severity: AlignmentIssueSeverity.critical,
        titleFr: 'tagOwners invalides ou tags actifs non déclarés',
        titleEn: 'Invalid tagOwners or undeclared active node tags',
        descriptionFr:
            'Des propriétaires de tags ne respectent pas Policy v2 (risque d\'erreur Go v2.OwnerEnc) ou des tags portés par des nœuds manquent dans tagOwners (bloqué en 0.29/0.30 par tags_not_permitted).',
        descriptionEn:
            'Some tag owners violate Policy v2 syntax (v2.OwnerEnc error) or active node tags are missing from tagOwners (blocked in 0.29/0.30 with tags_not_permitted).',
        affectedItems: affected.toSet().toList(),
        canAutoFixPolicy: true,
      ),
    );
  }

  static void _checkLegacyAutoApproversExitNodes({
    required Map<String, dynamic> workingPolicy,
    required bool isPre26,
    required List<AlignmentIssue> issues,
  }) {
    final autoApproversRaw = workingPolicy['autoApprovers'];
    if (autoApproversRaw is! Map || !autoApproversRaw.containsKey('exitNodes')) {
      return;
    }

    final oldExitNodes = autoApproversRaw['exitNodes'];
    final migratedApprovers = <String>[];
    if (oldExitNodes is List) {
      for (final item in oldExitNodes) {
        final str = item.toString().trim();
        if (str.isNotEmpty) migratedApprovers.add(str);
      }
    }

    if (isPre26) {
      issues.add(
        AlignmentIssue(
          type: AlignmentIssueType.legacyAutoApproversExitNodes,
          severity: AlignmentIssueSeverity.info,
          titleFr: 'Bloc "autoApprovers.exitNodes" (pré-0.26) à migrer après upgrade',
          titleEn: '"autoApprovers.exitNodes" (pre-0.26) to migrate after server upgrade',
          descriptionFr:
              'Votre serveur est encore en < 0.26 où "exitNodes" fonctionne, mais ce champ est supprimé dès la 0.26+. Il sera converti vers routes["0.0.0.0/0", "::/0"] après mise à jour.',
          descriptionEn:
              'Your server is still on < 0.26 where "exitNodes" works, but it is removed in 0.26+. Upgrade the server first, then migrate to routes["0.0.0.0/0", "::/0"].',
          affectedItems: migratedApprovers.isEmpty
              ? const ['autoApprovers.exitNodes']
              : migratedApprovers,
          canAutoFixPolicy: false,
        ),
      );
      return;
    }

    final autoApprovers = Map<String, dynamic>.from(autoApproversRaw);
    final routes = (autoApprovers['routes'] is Map)
        ? Map<String, dynamic>.from(autoApprovers['routes'] as Map)
        : <String, dynamic>{};

    for (final cidr in const ['0.0.0.0/0', '::/0']) {
      final list = (routes[cidr] is List)
          ? (routes[cidr] as List).map((e) => e.toString()).toSet()
          : <String>{};
      list.addAll(migratedApprovers);
      if (list.isNotEmpty) {
        routes[cidr] = list.toList();
      }
    }

    autoApprovers.remove('exitNodes');
    autoApprovers['routes'] = routes;
    workingPolicy['autoApprovers'] = autoApprovers;

    issues.add(
      AlignmentIssue(
        type: AlignmentIssueType.legacyAutoApproversExitNodes,
        severity: AlignmentIssueSeverity.warning,
        titleFr: 'Ancien bloc "autoApprovers.exitNodes" (pré-0.26)',
        titleEn: 'Legacy "autoApprovers.exitNodes" block (pre-0.26)',
        descriptionFr:
            'Le champ "exitNodes" dans autoApprovers a été supprimé à partir de Headscale 0.26 au profit des routes "0.0.0.0/0" et "::/0".',
        descriptionEn:
            '"autoApprovers.exitNodes" was removed in Headscale 0.26 and replaced by "0.0.0.0/0" and "::/0" inside "autoApprovers.routes".',
        affectedItems: migratedApprovers.isEmpty
            ? const ['autoApprovers.exitNodes']
            : migratedApprovers,
        canAutoFixPolicy: true,
      ),
    );
  }

  static void _checkLegacyOrDottedTags({
    required List<User> users,
    required List<Node> nodes,
    required Map<String, dynamic>? workingPolicy,
    required AclEngineMode engineMode,
    required _CascadeRewrites rewrites,
    required List<AlignmentIssue> issues,
  }) {
    final actions = <AlignmentNodeAction>[];
    final affected = <String>[];
    final keepLegacyMerged = engineMode == AclEngineMode.legacy;

    Map<String, dynamic>? tagOwners;
    if (workingPolicy != null) {
      tagOwners = (workingPolicy['tagOwners'] is Map)
          ? Map<String, dynamic>.from(workingPolicy['tagOwners'] as Map)
          : <String, dynamic>{};
    }

    final legacyNodesInLegacyMode = <String>[];

    for (final node in nodes) {
      if (keepLegacyMerged) {
        if (node.tags.any((t) => t.contains(';'))) {
          legacyNodesInLegacyMode.add(node.name);
        }
        // En mode Legacy : ne corriger QUE les points (.) tout en gardant ';'
        if (!node.tags.any((t) => t.contains('.'))) continue;
        final dotFixed = node.tags.map((t) {
          if (!t.contains('.')) return t;
          return t.startsWith('tag:')
              ? 'tag:${t.substring(4).replaceAll('.', '-').toLowerCase()}'
              : t.replaceAll('.', '-').toLowerCase();
        }).toList();
        if (jsonEncode(dotFixed) == jsonEncode(node.tags)) continue;

        for (int idx = 0; idx < node.tags.length; idx++) {
          final oldTag = node.tags[idx];
          if (oldTag.contains('.')) {
            rewrites.activeLegacyNodeTags.add(oldTag);
            rewrites.tagReplacements[oldTag] = [dotFixed[idx]];
          }
        }
        affected.add('${node.name}: ${node.tags.join(', ')} → ${dotFixed.join(', ')}');
        actions.add(
          AlignmentNodeAction(
            nodeId: node.id,
            nodeName: node.name,
            newTags: dotFixed,
            summaryFr: '${node.name} : ${node.tags.join(", ")} → ${dotFixed.join(", ")}',
            summaryEn: '${node.name}: ${node.tags.join(", ")} → ${dotFixed.join(", ")}',
          ),
        );
        if (tagOwners != null) {
          final ownerNorm = node.getNormalizedOwner();
          final ownerGroup = (ownerNorm.isNotEmpty &&
                  ownerNorm != 'tagged-devices' &&
                  ownerNorm != 'n-a' &&
                  ownerNorm != 'na')
              ? 'group:${normalizeUserName(ownerNorm)}'
              : (users.isNotEmpty
                  ? 'group:${normalizeUserName(users.first.name)}'
                  : null);
          if (ownerGroup != null) {
            for (final tag in dotFixed) {
              if (!tag.startsWith('tag:')) continue;
              final owners = (tagOwners[tag] is List)
                  ? (tagOwners[tag] as List).map((e) => e.toString()).toSet()
                  : <String>{};
              owners.add(ownerGroup);
              tagOwners[tag] = owners.toList();
            }
          }
        }
        continue;
      }

      final needsFix =
          node.tags.any((t) => t.contains(';') || t.contains('.'));
      if (!needsFix) continue;

      final converted = convertTagsToCleanStandard(node);
      if (jsonEncode(converted) == jsonEncode(node.tags)) continue;

      for (final oldTag in node.tags) {
        if (oldTag.contains(';') || oldTag.contains('.')) {
          rewrites.activeLegacyNodeTags.add(oldTag);
          rewrites.tagReplacements[oldTag] = _mapSingleOldTag(
            oldTag,
            fallbackOwnerNorm: normalizeUserName(node.getNormalizedOwner()),
          );
        }
      }

      affected.add('${node.name}: ${node.tags.join(', ')} → ${converted.join(', ')}');
      actions.add(
        AlignmentNodeAction(
          nodeId: node.id,
          nodeName: node.name,
          newTags: converted,
          summaryFr: '${node.name} : ${node.tags.join(", ")} → ${converted.join(", ")}',
          summaryEn: '${node.name}: ${node.tags.join(", ")} → ${converted.join(", ")}',
        ),
      );

      if (tagOwners != null) {
        final ownerNorm = node.getNormalizedOwner();
        final ownerGroup = (ownerNorm.isNotEmpty &&
                ownerNorm != 'tagged-devices' &&
                ownerNorm != 'n-a' &&
                ownerNorm != 'na')
            ? 'group:${normalizeUserName(ownerNorm)}'
            : (users.isNotEmpty
                ? 'group:${normalizeUserName(users.first.name)}'
                : null);
        if (ownerGroup != null) {
          for (final tag in converted) {
            if (!tag.startsWith('tag:')) continue;
            final owners = (tagOwners[tag] is List)
                ? (tagOwners[tag] as List).map((e) => e.toString()).toSet()
                : <String>{};
            owners.add(ownerGroup);
            tagOwners[tag] = owners.toList();
          }
        }
      }
    }

    // Détecter aussi les vieux tags (.;) déclarés uniquement dans tagOwners sans nœud
    var tagOwnersCleaned = false;
    if (tagOwners != null) {
      for (final rawTag in tagOwners.keys.toList()) {
        if (!rawTag.startsWith('tag:')) continue;
        final needsSplit = !keepLegacyMerged && rawTag.contains(';');
        if (!needsSplit && !rawTag.contains('.')) continue;

        final replacementTags = keepLegacyMerged
            ? [
                'tag:${rawTag.substring(4).replaceAll('.', '-').toLowerCase()}'
              ]
            : _mapSingleOldTag(rawTag);
        rewrites.tagReplacements.putIfAbsent(rawTag, () => replacementTags);

        final oldOwners = (tagOwners[rawTag] is List)
            ? (tagOwners[rawTag] as List).map((e) => e.toString()).toList()
            : <String>[];
        for (final newTag in replacementTags) {
          final existing = (tagOwners[newTag] is List)
              ? (tagOwners[newTag] as List).map((e) => e.toString()).toSet()
              : <String>{};
          existing.addAll(oldOwners);
          if (existing.isNotEmpty) {
            tagOwners[newTag] = existing.toList();
          }
        }
        // Si plus aucun nœud actif ne porte cet ancien tag, on peut retirer la clé obsolète
        if (!rewrites.activeLegacyNodeTags.contains(rawTag)) {
          tagOwners.remove(rawTag);
          affected.add('$rawTag → ${replacementTags.join(', ')} (tagOwners)');
          tagOwnersCleaned = true;
        }
      }
    }

    if (actions.isNotEmpty || tagOwnersCleaned) {
      if (workingPolicy != null && tagOwners != null) {
        workingPolicy['tagOwners'] = tagOwners;
      }

      issues.add(
        AlignmentIssue(
          type: AlignmentIssueType.legacyOrDottedTags,
          severity: AlignmentIssueSeverity.warning,
          titleFr: keepLegacyMerged
              ? 'Tags avec points (.) détectés'
              : 'Tags legacy (;) ou avec points (.) détectés',
          titleEn: keepLegacyMerged
              ? 'Dotted (.) tags detected'
              : 'Legacy (;) or dotted (.) tags detected',
          descriptionFr: keepLegacyMerged
              ? 'Ces tags contiennent des points qui isolent l\'appareil. Ils peuvent être normalisés avec des tirets (-) sans casser vos tags Legacy (;).'
              : 'Ces tags datent de l\'ancien moteur ou contiennent des points : ils empêchent une migration propre vers Grants V29 ou isolent l\'appareil. Ils peuvent être convertis au format Standard et répercutés automatiquement dans toutes vos règles.',
          descriptionEn: keepLegacyMerged
              ? 'These tags contain dots that isolate devices. They can be normalized with hyphens (-) while preserving Legacy (;) tags.'
              : 'These tags use the deprecated semicolon format or contain dots, blocking clean Grants V29 migration or isolating the node. They can be converted to Standard tags and updated across all rules.',
          affectedItems: affected.toSet().toList(),
          canAutoFixPolicy: workingPolicy != null,
          canAutoFixNodes: actions.isNotEmpty,
          nodeActions: actions,
        ),
      );
    } else if (keepLegacyMerged && legacyNodesInLegacyMode.isNotEmpty) {
      issues.add(
        AlignmentIssue(
          type: AlignmentIssueType.legacyOrDottedTags,
          severity: AlignmentIssueSeverity.info,
          titleFr: 'Tags fusionnés (;) actifs en mode Legacy',
          titleEn: 'Merged (;) tags active in Legacy mode',
          descriptionFr:
              'Votre serveur utilise actuellement le moteur Legacy : vos tags fusionnés (;) restent conservés. Pensez à migrer vers Standard ou Grants V29 avant l\'arrivée de Headscale 0.30.',
          descriptionEn:
              'Your server is currently using the Legacy engine: merged (;) tags are preserved. Consider migrating to Standard or Grants V29 ahead of Headscale 0.30.',
          affectedItems: legacyNodesInLegacyMode,
        ),
      );
    }
  }

  static List<String> _mapSingleOldTag(
    String rawTag, {
    String fallbackOwnerNorm = 'user',
  }) {
    final cleanDot = rawTag.startsWith('tag:')
        ? 'tag:${rawTag.substring(4).replaceAll('.', '-').toLowerCase()}'
        : rawTag.replaceAll('.', '-').toLowerCase();

    if (!cleanDot.contains(';')) {
      return [cleanDot];
    }

    final result = <String>{};
    final parts = cleanDot.split(';').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return [cleanDot];

    final base = parts.first.startsWith('tag:')
        ? parts.first
        : 'tag:${parts.first}';
    result.add(base);

    final slug = base.contains('-client')
        ? base.replaceFirst('tag:', '').split('-client').first
        : fallbackOwnerNorm;
    for (int i = 1; i < parts.length; i++) {
      result.add('tag:$slug-${parts[i]}');
    }
    return result.toList();
  }

  /// Convertit les tags d'un nœud (points `.` et séparateurs `;`) vers le
  /// format Standard séparé (`tag:<user>-client`, `-exit-node`, `-lan-sharer`).
  static List<String> convertTagsToCleanStandard(Node node) {
    final result = <String>{};
    final ownerNorm = normalizeUserName(node.getNormalizedOwner());
    for (final rawTag in node.tags) {
      result.addAll(_mapSingleOldTag(rawTag, fallbackOwnerNorm: ownerNorm));
    }
    return result.toList();
  }

  static void _checkInvalidDnsNodeNames({
    required List<Node> nodes,
    required bool supportsDns1123,
    required List<AlignmentIssue> issues,
  }) {
    final existingLowerNames = nodes.map((n) => n.name.toLowerCase()).toSet();
    final actions = <AlignmentNodeAction>[];
    final affected = <String>[];

    for (final node in nodes) {
      if (isValidDns1123Subdomain(node.name)) continue;

      var sanitized = sanitizeDns1123Subdomain(node.name);
      if (sanitized.isEmpty) sanitized = 'node-${node.id}';

      var candidate = sanitized;
      int suffix = 2;
      while (existingLowerNames.contains(candidate.toLowerCase()) &&
          candidate.toLowerCase() != node.name.toLowerCase()) {
        final suffixStr = '-$suffix';
        final maxBaseLen = 63 - suffixStr.length;
        final base = sanitized.length > maxBaseLen
            ? sanitized.substring(0, maxBaseLen)
            : sanitized;
        candidate = '$base$suffixStr';
        suffix++;
      }
      existingLowerNames.add(candidate.toLowerCase());

      if (candidate == node.name) continue;
      affected.add('${node.name} → $candidate');
      actions.add(
        AlignmentNodeAction(
          nodeId: node.id,
          nodeName: node.name,
          newNodeName: candidate,
          summaryFr: '${node.name} → $candidate',
          summaryEn: '${node.name} → $candidate',
        ),
      );
    }

    if (actions.isEmpty) return;

    issues.add(
      AlignmentIssue(
        type: AlignmentIssueType.invalidDnsNodeNames,
        severity: supportsDns1123
            ? AlignmentIssueSeverity.warning
            : AlignmentIssueSeverity.info,
        titleFr: supportsDns1123
            ? 'Noms de nœuds non conformes DNS-1123 (>= 0.27)'
            : 'Noms de nœuds à préparer pour DNS-1123 (>= 0.27)',
        titleEn: supportsDns1123
            ? 'Node names non-compliant with DNS-1123 (>= 0.27)'
            : 'Node names to prepare for DNS-1123 (>= 0.27)',
        descriptionFr: supportsDns1123
            ? 'Headscale ≥ 0.27 exige des noms de machines en minuscules alphanumériques/tirets uniquement (RFC 1123). Ces noms seront également indispensables pour les alias "hosts" sans tags.'
            : 'Votre serveur est encore en < 0.27, mais anticiper ces renommages évitera tout blocage lors de la mise à jour vers Headscale ≥ 0.27 ou pour les alias "hosts".',
        descriptionEn: supportsDns1123
            ? 'Headscale ≥ 0.27 requires lowercase alphanumeric/hyphen DNS-1123 node names. Valid names are also required for tagless "hosts" aliases.'
            : 'Your server is below 0.27, but renaming these nodes now prepares cleanly for Headscale ≥ 0.27.',
        affectedItems: affected,
        canAutoFixNodes: true,
        nodeActions: actions,
      ),
    );
  }

  /// Inspecte aussi les références dans les règles (`acls`, `grants`, `ssh`,
  /// `nodeAttrs`, `tests`, `temporaryRules`, `taildriveShares`) pour détecter :
  /// - un `group:<ancien.nom>` dont le nom normalisé existe dans `groups` ou `users`,
  /// - un `tag:<ancien.tag>` contenant `.` ou `;` dont le tag propre existe dans `tagOwners`,
  /// - un nom d'utilisateur nu sans `@` utilisé directement comme sujet/cible.
  static void _discoverRuleLevelRewrites({
    required List<User> users,
    required Map<String, dynamic> workingPolicy,
    required AclEngineMode engineMode,
    required List<Map<String, dynamic>> temporaryRules,
    required List<TaildriveShare> taildriveShares,
    required _CascadeRewrites rewrites,
  }) {
    final groupsMap = (workingPolicy['groups'] is Map)
        ? (workingPolicy['groups'] as Map)
            .keys
            .map((k) => k.toString())
            .toSet()
        : <String>{};
    final tagOwnersMap = (workingPolicy['tagOwners'] is Map)
        ? (workingPolicy['tagOwners'] as Map)
            .keys
            .map((k) => k.toString())
            .toSet()
        : <String>{};
    final hostsMap = (workingPolicy['hosts'] is Map)
        ? (workingPolicy['hosts'] as Map)
            .keys
            .map((k) => k.toString())
            .toSet()
        : <String>{};

    final knownUserGroups = <String>{
      ...groupsMap,
      for (final u in users) 'group:${normalizeUserName(u.name)}',
    };
    final userRawNames = <String>{
      for (final u in users)
        if (!u.name.contains('@') &&
            u.name.isNotEmpty &&
            u.name != 'Unknown User')
          u.name,
    };

    void inspectToken(String raw, {required bool allowPortSuffix}) {
      final split = _splitTargetAndPort(raw, allowPortSuffix: allowPortSuffix);
      final token = split.base;
      if (token.isEmpty) return;

      if (token.startsWith('group:')) {
        if (!groupsMap.contains(token)) {
          final norm = 'group:${normalizeUserName(token.substring(6))}';
          if (norm != token && knownUserGroups.contains(norm)) {
            rewrites.groupRenames.putIfAbsent(token, () => norm);
          }
        }
        return;
      }

      if (token.startsWith('tag:')) {
        final hasDot = token.contains('.');
        final hasSemicolon = token.contains(';');
        final shouldSplit =
            engineMode != AclEngineMode.legacy && hasSemicolon;
        if (!rewrites.tagReplacements.containsKey(token) &&
            (hasDot || shouldSplit)) {
          final mapped = shouldSplit
              ? _mapSingleOldTag(token)
              : [
                  'tag:${token.substring(4).replaceAll('.', '-').toLowerCase()}'
                ];
          if (mapped.any(tagOwnersMap.contains) || mapped.first != token) {
            rewrites.tagReplacements[token] = mapped;
          }
        }
        return;
      }

      if (userRawNames.contains(token) && !hostsMap.contains(token)) {
        rewrites.userMemberRewrites.putIfAbsent(token, () => '$token@');
      }
    }

    void scanList(dynamic list, {required bool allowPortSuffix}) {
      if (list is! List) return;
      for (final item in list) {
        inspectToken(item.toString(), allowPortSuffix: allowPortSuffix);
      }
    }

    final acls = workingPolicy['acls'];
    if (acls is List) {
      for (final rule in acls) {
        if (rule is Map) {
          scanList(rule['src'], allowPortSuffix: false);
          scanList(rule['dst'], allowPortSuffix: true);
        }
      }
    }
    final grants = workingPolicy['grants'];
    if (grants is List) {
      for (final grant in grants) {
        if (grant is Map) {
          scanList(grant['src'], allowPortSuffix: false);
          scanList(grant['dst'], allowPortSuffix: false);
          scanList(grant['via'], allowPortSuffix: false);
        }
      }
    }
    final ssh = workingPolicy['ssh'];
    if (ssh is List) {
      for (final rule in ssh) {
        if (rule is Map) {
          scanList(rule['src'], allowPortSuffix: false);
          scanList(rule['dst'], allowPortSuffix: false);
        }
      }
    }
    final nodeAttrs = workingPolicy['nodeAttrs'];
    if (nodeAttrs is List) {
      for (final attr in nodeAttrs) {
        if (attr is Map) {
          scanList(attr['target'], allowPortSuffix: false);
        }
      }
    }
    final tests = workingPolicy['tests'];
    if (tests is List) {
      for (final testEntry in tests) {
        if (testEntry is Map) {
          final srcVal = testEntry['src'];
          if (srcVal is String) {
            inspectToken(srcVal, allowPortSuffix: false);
          } else {
            scanList(srcVal, allowPortSuffix: false);
          }
          scanList(testEntry['accept'], allowPortSuffix: true);
          scanList(testEntry['deny'], allowPortSuffix: true);
        }
      }
    }
    for (final rule in temporaryRules) {
      final src = rule['src']?.toString() ?? '';
      final dst = rule['dst']?.toString() ?? '';
      if (src.isNotEmpty) inspectToken(src, allowPortSuffix: false);
      for (final part in dst.split(',')) {
        final trimmed = part.trim();
        if (trimmed.isNotEmpty) inspectToken(trimmed, allowPortSuffix: false);
      }
    }
    for (final share in taildriveShares) {
      final recipient = share.recipient.trim();
      if (recipient.isNotEmpty) {
        inspectToken(recipient, allowPortSuffix: false);
      }
    }
  }

  static void _applyCascadeRewritesToPolicy({
    required Map<String, dynamic> workingPolicy,
    required _CascadeRewrites rewrites,
  }) {
    // 1. tagOwners : réécrire aussi les propriétaires si un group:/user a changé
    final tagOwners = workingPolicy['tagOwners'];
    if (tagOwners is Map) {
      for (final key in tagOwners.keys.toList()) {
        final rawList = tagOwners[key];
        if (rawList is! List) continue;
        final rewritten = _rewriteStringList(
          rawList,
          rewrites: rewrites,
          allowPortSuffix: false,
          sectionLabel: 'tagOwners[$key]',
        );
        if (rewritten != null) {
          tagOwners[key] = rewritten;
        }
      }
    }

    // 2. autoApprovers.routes
    final autoApprovers = workingPolicy['autoApprovers'];
    if (autoApprovers is Map && autoApprovers['routes'] is Map) {
      final routes = autoApprovers['routes'] as Map;
      for (final cidr in routes.keys.toList()) {
        final list = routes[cidr];
        if (list is! List) continue;
        final preferCapability = (cidr == '0.0.0.0/0' || cidr == '::/0')
            ? '-exit-node'
            : '-lan-sharer';
        final rewritten = _rewriteStringList(
          list,
          rewrites: rewrites,
          allowPortSuffix: false,
          preferredTagSuffix: preferCapability,
          sectionLabel: 'autoApprovers.routes[$cidr]',
        );
        if (rewritten != null) {
          routes[cidr] = rewritten;
        }
      }
    }

    // 3. acls
    final acls = workingPolicy['acls'];
    if (acls is List) {
      for (int i = 0; i < acls.length; i++) {
        final rule = acls[i];
        if (rule is! Map) continue;
        final ruleMap = Map<String, dynamic>.from(rule);
        final oldSig = HuJsonCommentService.ruleSignature(
          ruleMap,
          isGrant: false,
        );
        var modified = false;
        final newSrc = _rewriteStringList(
          rule['src'],
          rewrites: rewrites,
          allowPortSuffix: false,
          sectionLabel: 'acls[$i].src',
        );
        if (newSrc != null) {
          rule['src'] = newSrc;
          modified = true;
        }
        final newDst = _rewriteStringList(
          rule['dst'],
          rewrites: rewrites,
          allowPortSuffix: true,
          sectionLabel: 'acls[$i].dst',
        );
        if (newDst != null) {
          rule['dst'] = newDst;
          modified = true;
        }
        if (modified) {
          final newSig = HuJsonCommentService.ruleSignature(
            Map<String, dynamic>.from(rule),
            isGrant: false,
          );
          if (oldSig != newSig) {
            rewrites.migratedCommentKeys[oldSig] = newSig;
          }
        }
      }
    }

    // 4. grants
    final grants = workingPolicy['grants'];
    if (grants is List) {
      for (int i = 0; i < grants.length; i++) {
        final grant = grants[i];
        if (grant is! Map) continue;
        final grantMap = Map<String, dynamic>.from(grant);
        final oldSig = HuJsonCommentService.ruleSignature(
          grantMap,
          isGrant: true,
        );
        var modified = false;

        final newSrc = _rewriteStringList(
          grant['src'],
          rewrites: rewrites,
          allowPortSuffix: false,
          sectionLabel: 'grants[$i].src',
        );
        if (newSrc != null) {
          grant['src'] = newSrc;
          modified = true;
        }
        final newDst = _rewriteStringList(
          grant['dst'],
          rewrites: rewrites,
          allowPortSuffix: false,
          sectionLabel: 'grants[$i].dst',
        );
        if (newDst != null) {
          grant['dst'] = newDst;
          modified = true;
        }

        final dstList = (grant['dst'] is List)
            ? (grant['dst'] as List).map((e) => e.toString()).toList()
            : const <String>[];
        final preferredViaSuffix = dstList.contains('autogroup:internet')
            ? '-exit-node'
            : (dstList.any(IpUtils.isCIDR) ? '-lan-sharer' : '-client');

        final newVia = _rewriteStringList(
          grant['via'],
          rewrites: rewrites,
          allowPortSuffix: false,
          preferredTagSuffix: preferredViaSuffix,
          sectionLabel: 'grants[$i].via',
        );
        if (newVia != null) {
          grant['via'] = newVia;
          modified = true;
        }

        if (modified) {
          final newSig = HuJsonCommentService.ruleSignature(
            Map<String, dynamic>.from(grant),
            isGrant: true,
          );
          if (oldSig != newSig) {
            rewrites.migratedCommentKeys[oldSig] = newSig;
          }
        }
      }
    }

    // 5. ssh
    final ssh = workingPolicy['ssh'];
    if (ssh is List) {
      for (int i = 0; i < ssh.length; i++) {
        final rule = ssh[i];
        if (rule is! Map) continue;
        final newSrc = _rewriteStringList(
          rule['src'],
          rewrites: rewrites,
          allowPortSuffix: false,
          sectionLabel: 'ssh[$i].src',
        );
        if (newSrc != null) rule['src'] = newSrc;
        final newDst = _rewriteStringList(
          rule['dst'],
          rewrites: rewrites,
          allowPortSuffix: false,
          sectionLabel: 'ssh[$i].dst',
        );
        if (newDst != null) rule['dst'] = newDst;
      }
    }

    // 6. nodeAttrs
    final nodeAttrs = workingPolicy['nodeAttrs'];
    if (nodeAttrs is List) {
      for (int i = 0; i < nodeAttrs.length; i++) {
        final attr = nodeAttrs[i];
        if (attr is! Map) continue;
        final newTarget = _rewriteStringList(
          attr['target'],
          rewrites: rewrites,
          allowPortSuffix: false,
          sectionLabel: 'nodeAttrs[$i].target',
        );
        if (newTarget != null) attr['target'] = newTarget;
      }
    }

    // 7. tests
    final tests = workingPolicy['tests'];
    if (tests is List) {
      for (int i = 0; i < tests.length; i++) {
        final t = tests[i];
        if (t is! Map) continue;
        if (t['src'] is String) {
          final rewritten = _rewriteSingleToken(
            t['src'] as String,
            rewrites: rewrites,
            allowPortSuffix: false,
          );
          if (rewritten.length == 1 && rewritten.first != t['src']) {
            rewrites.cascadedRuleItems
                .add('tests[$i].src: ${t['src']} → ${rewritten.first}');
            t['src'] = rewritten.first;
          }
        } else {
          final newSrc = _rewriteStringList(
            t['src'],
            rewrites: rewrites,
            allowPortSuffix: false,
            sectionLabel: 'tests[$i].src',
          );
          if (newSrc != null) t['src'] = newSrc;
        }
        final newAccept = _rewriteStringList(
          t['accept'],
          rewrites: rewrites,
          allowPortSuffix: true,
          sectionLabel: 'tests[$i].accept',
        );
        if (newAccept != null) t['accept'] = newAccept;
        final newDeny = _rewriteStringList(
          t['deny'],
          rewrites: rewrites,
          allowPortSuffix: true,
          sectionLabel: 'tests[$i].deny',
        );
        if (newDeny != null) t['deny'] = newDeny;
      }
    }
  }

  static List<Map<String, dynamic>>? _applyCascadeRewritesToTemporaryRules({
    required List<Map<String, dynamic>> temporaryRules,
    required _CascadeRewrites rewrites,
  }) {
    if (temporaryRules.isEmpty) return null;
    var anyChanged = false;
    final updated = <Map<String, dynamic>>[];

    for (int i = 0; i < temporaryRules.length; i++) {
      final copy = Map<String, dynamic>.from(temporaryRules[i]);
      final src = copy['src']?.toString() ?? '';
      if (src.isNotEmpty) {
        final newSrc = _rewriteSingleToken(
          src,
          rewrites: rewrites,
          allowPortSuffix: false,
        );
        if (newSrc.isNotEmpty && newSrc.first != src) {
          rewrites.cascadedRuleItems
              .add('Règle spécifique [$i].src: $src → ${newSrc.first}');
          copy['src'] = newSrc.first;
          anyChanged = true;
        }
      }
      final dst = copy['dst']?.toString() ?? '';
      if (dst.isNotEmpty) {
        final parts = dst.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
        final rebuilt = <String>[];
        var dstChanged = false;
        for (final p in parts) {
          final newParts = _rewriteSingleToken(
            p,
            rewrites: rewrites,
            allowPortSuffix: false,
          );
          if (newParts.join(',') != p) dstChanged = true;
          rebuilt.addAll(newParts);
        }
        if (dstChanged) {
          final joined = rebuilt.toSet().join(',');
          rewrites.cascadedRuleItems
              .add('Règle spécifique [$i].dst: $dst → $joined');
          copy['dst'] = joined;
          anyChanged = true;
        }
      }
      updated.add(copy);
    }

    return anyChanged ? updated : null;
  }

  static List<TaildriveShare>? _applyCascadeRewritesToTaildrive({
    required List<TaildriveShare> taildriveShares,
    required _CascadeRewrites rewrites,
  }) {
    if (taildriveShares.isEmpty) return null;
    var anyChanged = false;
    final updated = <TaildriveShare>[];

    for (final share in taildriveShares) {
      final rec = share.recipient.trim();
      final candidate = rec.startsWith('group:') ? rec : 'group:${normalizeUserName(rec)}';
      var nextRecipient = share.recipient;

      if (rewrites.groupRenames.containsKey(rec)) {
        nextRecipient = rewrites.groupRenames[rec]!;
      } else if (rewrites.groupRenames.containsKey(candidate)) {
        nextRecipient = rewrites.groupRenames[candidate]!;
      } else if (rec.startsWith('group:')) {
        final norm = 'group:${normalizeUserName(rec.substring(6))}';
        if (norm != rec) nextRecipient = norm;
      }

      if (nextRecipient != share.recipient) {
        rewrites.cascadedRuleItems.add(
          'Taildrive "${share.shareName}": ${share.recipient} → $nextRecipient',
        );
        updated.add(share.copyWith(recipient: nextRecipient));
        anyChanged = true;
      } else {
        updated.add(share);
      }
    }

    return anyChanged ? updated : null;
  }

  static List<String>? _rewriteStringList(
    dynamic rawList, {
    required _CascadeRewrites rewrites,
    required bool allowPortSuffix,
    String? preferredTagSuffix,
    required String sectionLabel,
  }) {
    if (rawList is! List) return null;
    var changed = false;
    final result = <String>[];

    for (final item in rawList) {
      final raw = item.toString();
      final replaced = _rewriteSingleToken(
        raw,
        rewrites: rewrites,
        allowPortSuffix: allowPortSuffix,
        preferredTagSuffix: preferredTagSuffix,
      );
      if (replaced.length != 1 || replaced.first != raw) {
        changed = true;
        rewrites.cascadedRuleItems
            .add('$sectionLabel: $raw → ${replaced.join(", ")}');
      }
      for (final val in replaced) {
        if (!result.contains(val)) {
          result.add(val);
        }
      }
    }

    return changed ? result : null;
  }

  static List<String> _rewriteSingleToken(
    String raw, {
    required _CascadeRewrites rewrites,
    required bool allowPortSuffix,
    String? preferredTagSuffix,
  }) {
    final split = _splitTargetAndPort(raw, allowPortSuffix: allowPortSuffix);
    final base = split.base;
    final portSuffix = split.portSuffix;

    if (rewrites.groupRenames.containsKey(base)) {
      return ['${rewrites.groupRenames[base]!}$portSuffix'];
    }
    if (rewrites.userMemberRewrites.containsKey(base)) {
      return ['${rewrites.userMemberRewrites[base]!}$portSuffix'];
    }
    if (rewrites.tagReplacements.containsKey(base)) {
      final candidates = rewrites.tagReplacements[base]!;
      if (preferredTagSuffix != null) {
        final match = candidates.where((t) => t.endsWith(preferredTagSuffix));
        if (match.isNotEmpty) {
          return ['${match.first}$portSuffix'];
        }
      }
      return candidates.map((t) => '$t$portSuffix').toList();
    }
    return [raw];
  }

  static ({String base, String portSuffix}) _splitTargetAndPort(
    String raw, {
    required bool allowPortSuffix,
  }) {
    final trimmed = raw.trim();
    if (!allowPortSuffix || trimmed.isEmpty) {
      return (base: trimmed, portSuffix: '');
    }

    if (trimmed.startsWith('[')) {
      final closeIdx = trimmed.indexOf(']');
      if (closeIdx != -1 &&
          closeIdx + 1 < trimmed.length &&
          trimmed[closeIdx + 1] == ':') {
        return (
          base: trimmed.substring(0, closeIdx + 1),
          portSuffix: trimmed.substring(closeIdx + 1),
        );
      }
      return (base: trimmed, portSuffix: '');
    }

    if (trimmed.startsWith('tag:') ||
        trimmed.startsWith('group:') ||
        trimmed.startsWith('autogroup:')) {
      final firstColon = trimmed.indexOf(':');
      final secondColon = trimmed.indexOf(':', firstColon + 1);
      if (secondColon != -1) {
        return (
          base: trimmed.substring(0, secondColon),
          portSuffix: trimmed.substring(secondColon),
        );
      }
      return (base: trimmed, portSuffix: '');
    }

    final firstColon = trimmed.indexOf(':');
    final lastColon = trimmed.lastIndexOf(':');
    if (firstColon != -1 && firstColon == lastColon) {
      return (
        base: trimmed.substring(0, firstColon),
        portSuffix: trimmed.substring(firstColon),
      );
    }

    return (base: trimmed, portSuffix: '');
  }

  static void _checkBrokenRuleReferences({
    required List<User> users,
    required List<Node> nodes,
    required Map<String, dynamic> workingPolicy,
    required List<Map<String, dynamic>> temporaryRules,
    required List<TaildriveShare> taildriveShares,
    required List<AlignmentIssue> issues,
  }) {
    final validGroups = <String>{
      if (workingPolicy['groups'] is Map)
        ...(workingPolicy['groups'] as Map).keys.map((k) => k.toString()),
    };
    final validTags = <String>{
      if (workingPolicy['tagOwners'] is Map)
        ...(workingPolicy['tagOwners'] as Map).keys.map((k) => k.toString()),
      for (final n in nodes) ...n.tags,
    };

    final broken = <String>[];

    void inspectRef(String raw, String where, {required bool allowPortSuffix}) {
      final token =
          _splitTargetAndPort(raw, allowPortSuffix: allowPortSuffix).base;
      if (token.startsWith('group:') && !validGroups.contains(token)) {
        broken.add('$where: $token introuvable dans "groups"');
      } else if (token.startsWith('tag:') && !validTags.contains(token)) {
        broken.add('$where: $token introuvable dans "tagOwners"');
      }
    }

    void inspectList(dynamic list, String where,
        {required bool allowPortSuffix}) {
      if (list is! List) return;
      for (final item in list) {
        inspectRef(item.toString(), where, allowPortSuffix: allowPortSuffix);
      }
    }

    final grants = workingPolicy['grants'];
    if (grants is List) {
      for (int i = 0; i < grants.length; i++) {
        final g = grants[i];
        if (g is! Map) continue;
        inspectList(g['src'], 'grants[$i]', allowPortSuffix: false);
        inspectList(g['dst'], 'grants[$i]', allowPortSuffix: false);
        inspectList(g['via'], 'grants[$i]', allowPortSuffix: false);
      }
    }

    final acls = workingPolicy['acls'];
    if (acls is List) {
      for (int i = 0; i < acls.length; i++) {
        final a = acls[i];
        if (a is! Map) continue;
        inspectList(a['src'], 'acls[$i]', allowPortSuffix: false);
        inspectList(a['dst'], 'acls[$i]', allowPortSuffix: true);
      }
    }

    final ssh = workingPolicy['ssh'];
    if (ssh is List) {
      for (int i = 0; i < ssh.length; i++) {
        final s = ssh[i];
        if (s is! Map) continue;
        inspectList(s['src'], 'ssh[$i]', allowPortSuffix: false);
        inspectList(s['dst'], 'ssh[$i]', allowPortSuffix: false);
      }
    }

    for (final share in taildriveShares) {
      final rec = share.recipient.trim();
      final groupKey =
          rec.startsWith('group:') ? rec : 'group:${normalizeUserName(rec)}';
      if (!validGroups.contains(groupKey)) {
        broken.add(
            'Taildrive "${share.shareName}": $groupKey introuvable dans "groups"');
      }
    }

    for (int i = 0; i < temporaryRules.length; i++) {
      final r = temporaryRules[i];
      final src = r['src']?.toString() ?? '';
      final dst = r['dst']?.toString() ?? '';
      if (src.isNotEmpty) {
        inspectRef(src, 'Règle spécifique [$i]', allowPortSuffix: false);
      }
      for (final p in dst.split(',')) {
        final trimmed = p.trim();
        if (trimmed.isNotEmpty) {
          inspectRef(trimmed, 'Règle spécifique [$i]', allowPortSuffix: false);
        }
      }
    }

    if (broken.isEmpty) return;

    issues.add(
      AlignmentIssue(
        type: AlignmentIssueType.brokenRuleReferences,
        severity: AlignmentIssueSeverity.warning,
        titleFr:
            'Références inconnues dans vos règles spécifiques (${broken.length})',
        titleEn:
            'Unknown references in your specific rules (${broken.length})',
        descriptionFr:
            'Certaines règles manuelles (grants, acls, ssh, Taildrive…) pointent vers un groupe ou tag absent (ex: ancien nom ou compte OIDC différent). Vérifiez ces règles avant régénération.',
        descriptionEn:
            'Some manual rules (grants, acls, ssh, Taildrive…) point to a missing group or tag (e.g. old name or separate OIDC account). Review these rules.',
        affectedItems: broken.toSet().toList(),
      ),
    );
  }
}

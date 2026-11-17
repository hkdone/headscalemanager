import 'dart:convert';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/services/acl/policy_infrastructure_builder.dart';
import 'package:headscalemanager/services/acl/policy_preserver.dart';
import 'package:headscalemanager/utils/string_utils.dart';

enum AlignmentIssueSeverity { critical, warning, info }

enum AlignmentIssueType {
  doubleProfileLocalOidc,
  malformedGroupMembers,
  invalidOrMissingTagOwners,
  legacyAutoApproversExitNodes,
  legacyOrDottedTags,
  invalidDnsNodeNames,
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

/// Résultat complet du diagnostic d'alignement ACL + nœuds.
class AlignmentReport {
  final List<AlignmentIssue> issues;
  final Map<String, dynamic>? alignedPolicy;
  final bool policyHasChanges;

  const AlignmentReport({
    required this.issues,
    required this.alignedPolicy,
    required this.policyHasChanges,
  });

  bool get isClean => issues.isEmpty;

  bool get hasPolicyFix => policyHasChanges && alignedPolicy != null;

  bool get hasNodeFixes => issues.any(
        (i) => i.canAutoFixNodes && i.nodeActions.isNotEmpty,
      );

  List<AlignmentNodeAction> get allNodeActions =>
      issues.expand((i) => i.nodeActions).toList();

  int get criticalCount =>
      issues.where((i) => i.severity == AlignmentIssueSeverity.critical).length;
}

/// Service d'audit intelligent détectant les désalignements entre les comptes
/// (locaux, OIDC mobiles), les nœuds (tags legacy, noms DNS-1123) et la
/// politique ACL serveur (>= 0.26 Policy v2 / 0.29 Grants).
class AlignmentDiagnosticService {
  static AlignmentReport inspect({
    required List<User> users,
    required List<Node> nodes,
    Map<String, dynamic>? serverPolicy,
    String? serverVersion,
  }) {
    final issues = <AlignmentIssue>[];
    final workingPolicy = serverPolicy != null
        ? PolicyPreserver.deepCopyMap(serverPolicy)
        : null;
    final originalEncoded =
        serverPolicy != null ? jsonEncode(serverPolicy) : null;

    // 1. Double profil Local + OIDC ou nœuds OIDC sans tags à côté de tagués
    _checkDoubleProfileLocalOidc(
      users: users,
      nodes: nodes,
      workingPolicy: workingPolicy,
      issues: issues,
    );

    // 2. Membres de "groups" mal formés pour Policy v2 (>= 0.26)
    if (workingPolicy != null) {
      _checkMalformedGroupMembers(
        users: users,
        workingPolicy: workingPolicy,
        issues: issues,
      );
    }

    // 3. Propriétaires "tagOwners" invalides ou tags actifs manquants
    if (workingPolicy != null) {
      _checkTagOwners(
        users: users,
        nodes: nodes,
        workingPolicy: workingPolicy,
        issues: issues,
      );
    }

    // 4. Ancien bloc autoApprovers.exitNodes (pré-0.26)
    if (workingPolicy != null) {
      _checkLegacyAutoApproversExitNodes(
        workingPolicy: workingPolicy,
        issues: issues,
      );
    }

    // 5. Tags fusionnés (;) ou contenant des points (.)
    _checkLegacyOrDottedTags(
      users: users,
      nodes: nodes,
      workingPolicy: workingPolicy,
      issues: issues,
    );

    // 6. Noms de machines non conformes RFC 1123 (0.27+)
    _checkInvalidDnsNodeNames(
      nodes: nodes,
      issues: issues,
    );

    final policyChanged = workingPolicy != null &&
        originalEncoded != null &&
        jsonEncode(workingPolicy) != originalEncoded;

    return AlignmentReport(
      issues: issues,
      alignedPolicy: policyChanged ? workingPolicy : null,
      policyHasChanges: policyChanged,
    );
  }

  static void _checkDoubleProfileLocalOidc({
    required List<User> users,
    required List<Node> nodes,
    required Map<String, dynamic>? workingPolicy,
    required List<AlignmentIssue> issues,
  }) {
    final bySlug = <String, List<User>>{};
    for (final user in users) {
      final slug = normalizeUserName(user.name);
      bySlug.putIfAbsent(slug, () => []).add(user);
    }

    // Détecter aussi les utilisateurs liés par local-part d'email
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

      if (workingPolicy != null && groupsMap != null) {
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

      if (workingPolicy != null && groupsMap != null && hasDistinctOidcEmail) {
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

        // Assurer que tagOwners du tag client accepte aussi l'email OIDC + le groupe
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

  static void _checkMalformedGroupMembers({
    required List<User> users,
    required Map<String, dynamic> workingPolicy,
    required List<AlignmentIssue> issues,
  }) {
    final groupsRaw = workingPolicy['groups'];
    if (groupsRaw is! Map) return;

    final userByGroupName = <String, User>{};
    for (final u in users) {
      userByGroupName['group:${normalizeUserName(u.name)}'] = u;
    }

    final affected = <String>[];
    final fixedGroups = Map<String, dynamic>.from(groupsRaw);
    var changed = false;

    for (final entry in groupsRaw.entries) {
      final groupKey = entry.key.toString();
      if (entry.value is! List) continue;
      final members =
          (entry.value as List).map((e) => e.toString().trim()).toList();
      final updated = <String>[];
      var groupModified = false;

      final matchedUser = userByGroupName[groupKey];
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
          // Format pré-0.26 sans '@' -> corriger en 'member@'
          updated.add('$member@');
          affected.add('$groupKey: "$member" → "$member@"');
          groupModified = true;
          continue;
        }
        // Si utilisateur local CLI pur ("jean") mais membre pollué par un domaine
        // inventé ("jean@headscale.local" ou "jean@synology.me")
        if (isPureLocalCliUser) {
          final prefix = member.split('@').first;
          final suffix = member.split('@').last;
          if (prefix == matchedUser.name && suffix.isNotEmpty) {
            final canonical = '${matchedUser.name}@';
            updated.add(canonical);
            affected.add('$groupKey: "$member" → "$canonical"');
            groupModified = true;
            continue;
          }
        }
        updated.add(member);
      }

      if (isPureLocalCliUser &&
          !updated.contains('${matchedUser.name}@')) {
        updated.add('${matchedUser.name}@');
        affected.add('$groupKey: + "${matchedUser.name}@"');
        groupModified = true;
      }

      if (groupModified) {
        changed = true;
        fixedGroups[groupKey] = updated.toSet().toList();
      }
    }

    if (!changed) return;

    workingPolicy['groups'] = fixedGroups;
    issues.add(
      AlignmentIssue(
        type: AlignmentIssueType.malformedGroupMembers,
        severity: AlignmentIssueSeverity.critical,
        titleFr: 'Membres de groupes incompatibles Policy v2 (>= 0.26)',
        titleEn: 'Group members incompatible with Policy v2 (>= 0.26)',
        descriptionFr:
            'Headscale ≥ 0.26 exige un "@" dans chaque membre de groupe, et attend "nom@" (avec @ final) pour les utilisateurs locaux sans email afin de reconnaître leurs appareils sans tag.',
        descriptionEn:
            'Headscale ≥ 0.26 requires "@" in every group member and expects "username@" for local users without an email so their untagged devices match ACLs.',
        affectedItems: affected,
        canAutoFixPolicy: true,
      ),
    );
  }

  static void _checkTagOwners({
    required List<User> users,
    required List<Node> nodes,
    required Map<String, dynamic> workingPolicy,
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

    // A. Nettoyer les propriétaires invalides (ex: "jean" sans group:/autogroup:/@)
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
          final replacement = userByNorm.containsKey(norm)
              ? 'group:$norm'
              : '$owner@';
          cleaned.add(replacement);
          affected.add('$key: "$owner" → "$replacement"');
          tagChanged = true;
        }
      }
      if (tagChanged) {
        tagOwners[key] = cleaned.toSet().toList();
        changed = true;
      }
    }

    // B. Vérifier que tous les tags portés par des nœuds actifs existent dans tagOwners
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
    required List<AlignmentIssue> issues,
  }) {
    final autoApproversRaw = workingPolicy['autoApprovers'];
    if (autoApproversRaw is! Map || !autoApproversRaw.containsKey('exitNodes')) {
      return;
    }

    final autoApprovers = Map<String, dynamic>.from(autoApproversRaw);
    final oldExitNodes = autoApprovers['exitNodes'];
    final routes = (autoApprovers['routes'] is Map)
        ? Map<String, dynamic>.from(autoApprovers['routes'] as Map)
        : <String, dynamic>{};

    final migratedApprovers = <String>[];
    if (oldExitNodes is List) {
      for (final item in oldExitNodes) {
        final str = item.toString().trim();
        if (str.isNotEmpty) migratedApprovers.add(str);
      }
    }

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
    required List<AlignmentIssue> issues,
  }) {
    final actions = <AlignmentNodeAction>[];
    final affected = <String>[];

    Map<String, dynamic>? tagOwners;
    if (workingPolicy != null) {
      tagOwners = (workingPolicy['tagOwners'] is Map)
          ? Map<String, dynamic>.from(workingPolicy['tagOwners'] as Map)
          : <String, dynamic>{};
    }

    for (final node in nodes) {
      final needsFix =
          node.tags.any((t) => t.contains(';') || t.contains('.'));
      if (!needsFix) continue;

      final converted = convertTagsToCleanStandard(node);
      if (jsonEncode(converted) == jsonEncode(node.tags)) continue;

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

    if (actions.isEmpty) return;

    if (workingPolicy != null && tagOwners != null) {
      workingPolicy['tagOwners'] = tagOwners;
    }

    issues.add(
      AlignmentIssue(
        type: AlignmentIssueType.legacyOrDottedTags,
        severity: AlignmentIssueSeverity.warning,
        titleFr: 'Tags legacy (;) ou avec points (.) détectés',
        titleEn: 'Legacy (;) or dotted (.) tags detected',
        descriptionFr:
            'Ces tags datent de l\'ancien moteur ou contiennent des points : ils empêchent une migration propre vers Grants V29 ou isolent l\'appareil. Ils peuvent être convertis au format Standard et déclarés dans tagOwners.',
        descriptionEn:
            'These tags use the deprecated semicolon format or contain dots, blocking clean Grants V29 migration or isolating the node. They can be converted to Standard tags and declared in tagOwners.',
        affectedItems: affected,
        canAutoFixPolicy: workingPolicy != null,
        canAutoFixNodes: true,
        nodeActions: actions,
      ),
    );
  }

  /// Convertit les tags d'un nœud (points `.` et séparateurs `;`) vers le
  /// format Standard séparé (`tag:<user>-client`, `-exit-node`, `-lan-sharer`).
  static List<String> convertTagsToCleanStandard(Node node) {
    final result = <String>{};
    final ownerNorm = normalizeUserName(node.getNormalizedOwner());

    for (final rawTag in node.tags) {
      final cleanDot = rawTag.startsWith('tag:')
          ? 'tag:${rawTag.substring(4).replaceAll('.', '-').toLowerCase()}'
          : rawTag.replaceAll('.', '-').toLowerCase();

      if (cleanDot.contains(';')) {
        final parts = cleanDot.split(';').where((p) => p.isNotEmpty).toList();
        if (parts.isEmpty) continue;
        final base = parts.first.startsWith('tag:')
            ? parts.first
            : 'tag:${parts.first}';
        result.add(base);

        final slug = base.contains('-client')
            ? base.replaceFirst('tag:', '').split('-client').first
            : ownerNorm;
        for (int i = 1; i < parts.length; i++) {
          final cap = parts[i];
          result.add('tag:$slug-$cap');
        }
      } else {
        result.add(cleanDot);
      }
    }
    return result.toList();
  }

  static void _checkInvalidDnsNodeNames({
    required List<Node> nodes,
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
        severity: AlignmentIssueSeverity.warning,
        titleFr: 'Noms de nœuds non conformes DNS-1123 (>= 0.27)',
        titleEn: 'Node names non-compliant with DNS-1123 (>= 0.27)',
        descriptionFr:
            'Headscale ≥ 0.27 exige des noms de machines en minuscules alphanumériques/tirets uniquement (RFC 1123). Ces noms seront également indispensables pour les alias "hosts" sans tags.',
        descriptionEn:
            'Headscale ≥ 0.27 requires lowercase alphanumeric/hyphen DNS-1123 node names. Valid names are also required for tagless "hosts" aliases.',
        affectedItems: affected,
        canAutoFixNodes: true,
        nodeActions: actions,
      ),
    );
  }
}

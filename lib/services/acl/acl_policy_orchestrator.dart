import 'package:headscalemanager/models/acl_engine_mode.dart';
import 'package:headscalemanager/models/node.dart';
import 'package:headscalemanager/models/taildrive_share.dart';
import 'package:headscalemanager/models/user.dart';
import 'package:headscalemanager/models/version_info.dart';
import 'package:headscalemanager/services/acl/grants_v29_generator.dart';
import 'package:headscalemanager/services/new_acl_generator_service.dart';
import 'package:headscalemanager/services/standard_acl_generator_service.dart';

/// Point d'entrée unique pour la génération de politiques ACL.
class AclPolicyOrchestrator {
  final NewAclGeneratorService _legacyEngine = NewAclGeneratorService();
  final StandardAclGeneratorService _standardEngine =
      StandardAclGeneratorService();
  final GrantsV29GeneratorService _grantsV29Engine = GrantsV29GeneratorService();

  Map<String, dynamic> generatePolicy({
    required AclEngineMode engineMode,
    required List<User> users,
    required List<Node> nodes,
    List<Map<String, dynamic>> temporaryRules = const [],
    List<TaildriveShare> taildriveShares = const [],
    String? serverVersion,
  }) {
    switch (engineMode) {
      case AclEngineMode.grantsV29:
        if (serverVersion == null ||
            !VersionInfo.checkVersionAtLeast(serverVersion, '0.29.0')) {
          return _standardEngine.generatePolicy(
            users: users,
            nodes: nodes,
            temporaryRules: temporaryRules,
            taildriveShares: taildriveShares,
            serverVersion: serverVersion,
          );
        }
        return _grantsV29Engine.generatePolicy(
          users: users,
          nodes: nodes,
          temporaryRules: temporaryRules,
          taildriveShares: taildriveShares,
          serverVersion: serverVersion,
        );
      case AclEngineMode.standard:
        return _standardEngine.generatePolicy(
          users: users,
          nodes: nodes,
          temporaryRules: temporaryRules,
          taildriveShares: taildriveShares,
          serverVersion: serverVersion,
        );
      case AclEngineMode.legacy:
        return _legacyEngine.generatePolicy(
          users: users,
          nodes: nodes,
          temporaryRules: temporaryRules,
          taildriveShares: taildriveShares,
          serverVersion: serverVersion,
        );
    }
  }

  /// Compatibilité ascendante avec l'API booléenne.
  Map<String, dynamic> generatePolicyFromLegacyFlag({
    required bool useStandardEngine,
    required List<User> users,
    required List<Node> nodes,
    List<Map<String, dynamic>> temporaryRules = const [],
    List<TaildriveShare> taildriveShares = const [],
    String? serverVersion,
  }) {
    return generatePolicy(
      engineMode:
          useStandardEngine ? AclEngineMode.standard : AclEngineMode.legacy,
      users: users,
      nodes: nodes,
      temporaryRules: temporaryRules,
      taildriveShares: taildriveShares,
      serverVersion: serverVersion,
    );
  }
}

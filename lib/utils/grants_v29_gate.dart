import 'package:headscalemanager/models/acl_engine_mode.dart';
import 'package:headscalemanager/models/version_info.dart';

/// Vérifie si les fonctionnalités Grants V29 UI (composeur, édition inline…) sont disponibles.
class GrantsV29Gate {
  GrantsV29Gate._();

  static bool isAvailable({
    required AclEngineMode engineMode,
    required String serverVersion,
  }) {
    return engineMode == AclEngineMode.grantsV29 &&
        VersionInfo.checkVersionAtLeast(serverVersion, '0.29.0');
  }
}

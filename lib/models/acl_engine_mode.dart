/// Mode de génération des politiques ACL Headscale.
enum AclEngineMode {
  /// Tags fusionnés legacy (`tag:user-client;exit-node`).
  legacy,

  /// Tags séparés (`tag:user-client`, `tag:user-exit-node`, …).
  standard,

  /// Grants Headscale 0.29+ avec routage `via` (recommandé si serveur >= 0.29).
  grantsV29,
}

extension AclEngineModeStorage on AclEngineMode {
  String get storageKey => name;

  static AclEngineMode fromStorageKey(String? key) {
    if (key == null) return AclEngineMode.standard;
    return AclEngineMode.values.firstWhere(
      (m) => m.name == key,
      orElse: () => AclEngineMode.standard,
    );
  }
}

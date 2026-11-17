class VersionInfo {
  /// Version majeure/mineure de référence courante de Headscale supportée par l'app.
  static const String currentReferenceVersion = '0.29.0';
  static const String currentReferenceShort = '0.29';

  /// Seuil minimal activement supporté sans avertissement (fenêtre N et N-1).
  static const String minActivelySupportedVersion = '0.28.0';

  final String version;
  final String commit;
  final String buildTime;
  final bool dirty;
  final GoInfo go;

  VersionInfo({
    required this.version,
    required this.commit,
    required this.buildTime,
    required this.dirty,
    required this.go,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    return VersionInfo(
      version: json['version'] ?? 'unknown',
      commit: json['commit'] ?? 'unknown',
      buildTime: json['buildTime'] ?? 'unknown',
      dirty: json['dirty'] ?? false,
      go: GoInfo.fromJson(json['go'] ?? {}),
    );
  }

  /// Indique si la version serveur connectée a au moins 2 versions de retard
  /// (<= N-2, soit < 0.28.0 par rapport à la référence 0.29).
  static bool isServerDeprecated(String? serverVersion) {
    if (serverVersion == null) return false;
    final trimmed = serverVersion.trim();
    if (trimmed.isEmpty || trimmed == 'unknown') return false;
    return !checkVersionAtLeast(trimmed, minActivelySupportedVersion);
  }

  /// Indique si le serveur est antérieur à Headscale 0.26.0 (palier déjà échu).
  static bool isPreV26(String? serverVersion) {
    if (serverVersion == null) return false;
    final trimmed = serverVersion.trim();
    if (trimmed.isEmpty || trimmed == 'unknown') return false;
    return !checkVersionAtLeast(trimmed, '0.26.0');
  }

  /// Helper statique pour vérifier une version sans instancier l'objet.
  static bool checkVersionAtLeast(String currentVersion, String minVersion) {
    if (currentVersion == 'unknown') return false;

    // Nettoyage de la version (v0.22.1 -> 0.22.1, 0.23.0-rc1 -> 0.23.0)
    final cleanCurrent =
        currentVersion.replaceAll(RegExp(r'^v'), '').split('-').first;
    final cleanTarget =
        minVersion.replaceAll(RegExp(r'^v'), '').split('-').first;

    final partsCurrent =
        cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final partsTarget =
        cleanTarget.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Normalisation des longueurs (0.28 vs 0.28.0.1)
    final maxLength = partsCurrent.length > partsTarget.length
        ? partsCurrent.length
        : partsTarget.length;
    while (partsCurrent.length < maxLength) {
      partsCurrent.add(0);
    }
    while (partsTarget.length < maxLength) {
      partsTarget.add(0);
    }

    for (int i = 0; i < maxLength; i++) {
      if (partsCurrent[i] < partsTarget[i]) return false;
      if (partsCurrent[i] > partsTarget[i]) return true;
    }
    return true; // Égaux ou supérieur
  }

  /// Vérifie si la version actuelle est supérieure ou égale à [minVersion].
  bool isAtLeast(String minVersion) {
    return checkVersionAtLeast(version, minVersion);
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'commit': commit,
      'buildTime': buildTime,
      'dirty': dirty,
      'go': go.toJson(),
    };
  }
}

class GoInfo {
  final String version;
  final String os;
  final String arch;

  GoInfo({
    required this.version,
    required this.os,
    required this.arch,
  });

  factory GoInfo.fromJson(Map<String, dynamic> json) {
    return GoInfo(
      version: json['version'] ?? 'unknown',
      os: json['os'] ?? 'unknown',
      arch: json['arch'] ?? 'unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'os': os,
      'arch': arch,
    };
  }
}

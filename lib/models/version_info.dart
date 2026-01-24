class VersionInfo {
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

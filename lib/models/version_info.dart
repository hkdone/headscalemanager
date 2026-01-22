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

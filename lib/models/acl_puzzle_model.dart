import 'package:uuid/uuid.dart';

enum PuzzleEntityType { user, group, tag, host, cidr, internet }

class PuzzleEntity {
  final String id;
  final PuzzleEntityType type;
  final String value;
  final String displayLabel;

  PuzzleEntity({
    required this.id,
    required this.type,
    required this.value,
    required this.displayLabel,
  });

  factory PuzzleEntity.fromJson(Map<String, dynamic> json) {
    return PuzzleEntity(
      id: json['id'],
      type: PuzzleEntityType.values
          .firstWhere((e) => e.toString() == json['type']),
      value: json['value'],
      displayLabel: json['displayLabel'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString(),
      'value': value,
      'displayLabel': displayLabel,
    };
  }
}

class PuzzleRule {
  final String id;
  final List<PuzzleEntity> sources;
  final List<PuzzleEntity> destinations;
  final String action;

  PuzzleRule({
    String? id,
    required this.sources,
    required this.destinations,
    this.action = 'accept',
  }) : id = id ?? const Uuid().v4();

  factory PuzzleRule.fromJson(Map<String, dynamic> json) {
    return PuzzleRule(
      id: json['id'],
      sources: (json['sources'] as List)
          .map((e) => PuzzleEntity.fromJson(e))
          .toList(),
      destinations: (json['destinations'] as List)
          .map((e) => PuzzleEntity.fromJson(e))
          .toList(),
      action: json['action'] ?? 'accept',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sources': sources.map((e) => e.toJson()).toList(),
      'destinations': destinations.map((e) => e.toJson()).toList(),
      'action': action,
    };
  }
}

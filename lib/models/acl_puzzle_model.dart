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
  final List<PuzzleEntity> via;
  final List<PuzzleEntity> destinations;
  final String action;
  final bool isGrant;

  PuzzleRule({
    String? id,
    required this.sources,
    this.via = const [],
    required this.destinations,
    this.action = 'accept',
    this.isGrant = false,
  }) : id = id ?? const Uuid().v4();

  String get signature {
    final srcValues = sources.map((e) => e.value).toList()..sort();
    final viaValues = via.map((e) => e.value).toList()..sort();
    final dstValues = destinations.map((e) => e.value).toList()..sort();
    return 'src:${srcValues.join(",")}|via:${viaValues.join(",")}|dst:${dstValues.join(",")}';
  }

  factory PuzzleRule.fromJson(Map<String, dynamic> json) {
    return PuzzleRule(
      id: json['id'],
      sources: (json['sources'] as List)
          .map((e) => PuzzleEntity.fromJson(e))
          .toList(),
      via: json['via'] != null
          ? (json['via'] as List)
              .map((e) => PuzzleEntity.fromJson(e))
              .toList()
          : const [],
      destinations: (json['destinations'] as List)
          .map((e) => PuzzleEntity.fromJson(e))
          .toList(),
      action: json['action'] ?? 'accept',
      isGrant: json['isGrant'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sources': sources.map((e) => e.toJson()).toList(),
      'via': via.map((e) => e.toJson()).toList(),
      'destinations': destinations.map((e) => e.toJson()).toList(),
      'action': action,
      'isGrant': isGrant,
    };
  }
}

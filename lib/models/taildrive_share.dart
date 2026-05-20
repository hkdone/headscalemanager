import 'package:uuid/uuid.dart';

enum TaildriveAccessMode {
  ro, // Read-only
  rw, // Read-write
}

class TaildriveShare {
  final String id;
  final String sourceNodeId;
  final String shareName;
  final String localPath;
  final String recipient; // Can be a user (e.g., "alice") or a group (e.g., "group:admin")
  final TaildriveAccessMode accessMode;

  TaildriveShare({
    String? id,
    required this.sourceNodeId,
    required this.shareName,
    required this.localPath,
    required this.recipient,
    required this.accessMode,
  }) : id = id ?? const Uuid().v4();

  factory TaildriveShare.fromJson(Map<String, dynamic> json) {
    return TaildriveShare(
      id: json['id'] as String,
      sourceNodeId: json['sourceNodeId'] as String,
      shareName: json['shareName'] as String,
      localPath: json['localPath'] as String,
      recipient: json['recipient'] as String,
      accessMode: json['accessMode'] == 'rw'
          ? TaildriveAccessMode.rw
          : TaildriveAccessMode.ro,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sourceNodeId': sourceNodeId,
      'shareName': shareName,
      'localPath': localPath,
      'recipient': recipient,
      'accessMode': accessMode == TaildriveAccessMode.rw ? 'rw' : 'ro',
    };
  }

  TaildriveShare copyWith({
    String? sourceNodeId,
    String? shareName,
    String? localPath,
    String? recipient,
    TaildriveAccessMode? accessMode,
  }) {
    return TaildriveShare(
      id: id,
      sourceNodeId: sourceNodeId ?? this.sourceNodeId,
      shareName: shareName ?? this.shareName,
      localPath: localPath ?? this.localPath,
      recipient: recipient ?? this.recipient,
      accessMode: accessMode ?? this.accessMode,
    );
  }
}

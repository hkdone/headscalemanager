import 'package:uuid/uuid.dart';

class Server {
  final String id;
  final String name;
  final String url;
  final String apiKey;
  final String? version;

  Server({
    String? id,
    required this.name,
    required this.url,
    required this.apiKey,
    this.version,
  }) : id = id ?? const Uuid().v4();

  factory Server.fromJson(Map<String, dynamic> json) {
    return Server(
      id: json['id'],
      name: json['name'],
      url: json['url'],
      apiKey: json['apiKey'],
      version: json['version'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'apiKey': apiKey,
      'version': version,
    };
  }

  Server copyWith({
    String? name,
    String? url,
    String? apiKey,
    String? version,
  }) {
    return Server(
      id: id,
      name: name ?? this.name,
      url: url ?? this.url,
      apiKey: apiKey ?? this.apiKey,
      version: version ?? this.version,
    );
  }
}

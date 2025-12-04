import 'dart:convert';
import 'package:uuid/uuid.dart';

class Server {
  final String id;
  final String name;
  final String url;
  final String apiKey;

  Server({
    String? id,
    required this.name,
    required this.url,
    required this.apiKey,
  }) : id = id ?? const Uuid().v4();

  factory Server.fromJson(Map<String, dynamic> json) {
    return Server(
      id: json['id'],
      name: json['name'],
      url: json['url'],
      apiKey: json['apiKey'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'apiKey': apiKey,
    };
  }
}

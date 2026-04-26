import 'dart:convert';

enum PathEntryType {
  local,
  webdav
}

class SearchPathEntry {
  final PathEntryType type;
  final String path;
  final String? username;
  final String? password;

  SearchPathEntry({
    required this.type,
    required this.path,
    this.username,
    this.password,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'path': path,
      'username': username,
      'password': password,
    };
  }

  factory SearchPathEntry.fromJson(Map<String, dynamic> json) {
    return SearchPathEntry(
      type: json['type'] == 'webdav' ? PathEntryType.webdav : PathEntryType.local,
      path: json['path'] as String,
      username: json['username'] as String?,
      password: json['password'] as String?,
    );
  }

  String encode() => jsonEncode(toJson());

  factory SearchPathEntry.decode(String source) => SearchPathEntry.fromJson(jsonDecode(source));

  @override
  String toString() {
    if (type == PathEntryType.webdav) {
      return '(WebDAV) $path';
    }
    return '(Local) $path';
  }
}

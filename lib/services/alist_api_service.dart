import 'dart:convert';
import 'dart:io';

import '../models/search_path_entry.dart';

class AlistResolvedLink {
  final String url;
  final Map<String, String> headers;

  const AlistResolvedLink({required this.url, this.headers = const {}});
}

class AlistApiService {
  AlistApiService._();

  static final AlistApiService instance = AlistApiService._();

  final HttpClient _httpClient = HttpClient();
  final Map<String, String> _tokenCache = {};

  Future<AlistResolvedLink?> resolveSignedLink({
    required SearchPathEntry entry,
    required String remoteUrlWithoutUserInfo,
  }) async {
    if (entry.type != PathEntryType.webdav) {
      return null;
    }

    final rootUrl = _normalizeComparableUrl(entry.path);
    final remoteUrl = _normalizeComparableUrl(remoteUrlWithoutUserInfo);
    if (!remoteUrl.startsWith(rootUrl)) {
      return null;
    }

    final rootUri = Uri.parse(rootUrl);
    var relativePath = remoteUrl.substring(rootUrl.length);
    if (!relativePath.startsWith('/')) {
      relativePath = '/$relativePath';
    }

    final mountPath = _extractMountPath(rootUri.path);
    final filePath = _joinPosix(mountPath, relativePath);
    final token = await _login(
      rootUri,
      entry.username ?? '',
      entry.password ?? '',
    );
    final response = await _postJson(
      rootUri.replace(path: '/api/fs/get', query: '').toString(),
      body: {
        'path': filePath,
        'password': '',
        'page': 1,
        'per_page': 0,
        'refresh': false,
      },
      headers: {'Authorization': token},
    );

    if (response['code'] != 200 || response['data'] is! Map<String, dynamic>) {
      throw Exception(
        'AList fs/get failed: ${response['message'] ?? response['code']}',
      );
    }

    final data = response['data'] as Map<String, dynamic>;
    final rawUrl = data['raw_url'] as String?;
    if (rawUrl == null || rawUrl.isEmpty) {
      throw Exception('AList fs/get returned empty raw_url');
    }

    final responseHeaders = _parseHeaderMap(data['header']);
    return AlistResolvedLink(url: rawUrl, headers: responseHeaders);
  }

  Future<String> _login(Uri rootUri, String username, String password) async {
    final cacheKey = '${rootUri.origin}|$username|$password';
    final cached = _tokenCache[cacheKey];
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final response = await _postJson(
      rootUri.replace(path: '/api/auth/login', query: '').toString(),
      body: {'username': username, 'password': password},
    );

    if (response['code'] != 200 || response['data'] is! Map<String, dynamic>) {
      throw Exception(
        'AList login failed: ${response['message'] ?? response['code']}',
      );
    }

    final data = response['data'] as Map<String, dynamic>;
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('AList login returned empty token');
    }
    _tokenCache[cacheKey] = token;
    return token;
  }

  Future<Map<String, dynamic>> _postJson(
    String url, {
    required Map<String, dynamic> body,
    Map<String, String> headers = const {},
  }) async {
    final request = await _httpClient.postUrl(Uri.parse(url));
    request.headers.contentType = ContentType.json;
    headers.forEach(request.headers.set);
    request.write(jsonEncode(body));

    final response = await request.close();
    final responseBody = await utf8.decodeStream(response);
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected AList response shape');
    }
    return decoded;
  }

  String _extractMountPath(String webdavPath) {
    var path = webdavPath.replaceAll(RegExp(r'/$'), '');
    if (path == '/dav') {
      return '/';
    }
    if (path.startsWith('/dav/')) {
      path = path.substring(4);
    }
    if (!path.startsWith('/')) {
      path = '/$path';
    }
    return path;
  }

  String _joinPosix(String base, String child) {
    final normalizedBase = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final normalizedChild = child.startsWith('/') ? child : '/$child';
    return normalizedBase.isEmpty
        ? normalizedChild
        : '$normalizedBase$normalizedChild';
  }

  String _normalizeComparableUrl(String url) {
    return url
        .replaceAll(RegExp(r'^(https?://)([^@]+)@'), r'$1')
        .replaceAll(RegExp(r'/$'), '');
  }

  Map<String, String> _parseHeaderMap(dynamic rawHeader) {
    if (rawHeader is Map) {
      return rawHeader.map((key, value) => MapEntry('$key', '$value'));
    }
    if (rawHeader is String && rawHeader.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawHeader);
        if (decoded is Map) {
          return decoded.map((key, value) => MapEntry('$key', '$value'));
        }
      } catch (_) {
        return {};
      }
    }
    return {};
  }
}

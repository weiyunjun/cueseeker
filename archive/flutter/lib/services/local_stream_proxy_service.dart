import 'dart:async';
import 'dart:convert';
import 'dart:io';

class LocalStreamProxyService {
  LocalStreamProxyService._();

  static final LocalStreamProxyService instance = LocalStreamProxyService._();

  HttpServer? _server;
  final HttpClient _httpClient = HttpClient()..autoUncompress = false;
  final Map<String, _ProxyTarget> _targets = {};

  Future<String> register({
    required String remoteUrl,
    Map<String, String>? headers,
  }) async {
    await _ensureServer();
    final token = base64Url
        .encode(
          utf8.encode('${DateTime.now().microsecondsSinceEpoch}:$remoteUrl'),
        )
        .replaceAll('=', '');
    _targets[token] = _ProxyTarget(
      remoteUrl: remoteUrl,
      headers: headers ?? const {},
    );
    return 'http://${_server!.address.host}:${_server!.port}/stream/$token';
  }

  Future<void> _ensureServer() async {
    if (_server != null) {
      return;
    }
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(
      _server!.forEach((request) async {
        try {
          await _handleRequest(request);
        } catch (e) {
          request.response.statusCode = HttpStatus.badGateway;
          await request.response.close();
        }
      }),
    );
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final segments = request.uri.pathSegments;
    if (segments.length != 2 || segments.first != 'stream') {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final target = _targets[segments[1]];
    if (target == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final remoteUri = Uri.parse(target.remoteUrl);
    final remoteRequest = await _httpClient.openUrl(request.method, remoteUri);

    target.headers.forEach(remoteRequest.headers.set);

    final forwardedHeaders = [
      HttpHeaders.rangeHeader,
      HttpHeaders.userAgentHeader,
      HttpHeaders.acceptHeader,
      HttpHeaders.acceptEncodingHeader,
      HttpHeaders.ifModifiedSinceHeader,
      HttpHeaders.ifRangeHeader,
    ];

    for (final name in forwardedHeaders) {
      final value = request.headers.value(name);
      if (value != null && value.isNotEmpty) {
        remoteRequest.headers.set(name, value);
      }
    }

    final remoteResponse = await remoteRequest.close();
    request.response.statusCode = remoteResponse.statusCode;

    final passthroughHeaders = [
      HttpHeaders.contentTypeHeader,
      HttpHeaders.contentLengthHeader,
      HttpHeaders.contentRangeHeader,
      HttpHeaders.acceptRangesHeader,
      HttpHeaders.etagHeader,
      HttpHeaders.lastModifiedHeader,
      HttpHeaders.cacheControlHeader,
    ];

    for (final name in passthroughHeaders) {
      final values = remoteResponse.headers[name];
      if (values != null) {
        for (final value in values) {
          request.response.headers.add(name, value);
        }
      }
    }

    if (request.method == 'HEAD') {
      await request.response.close();
      return;
    }

    await remoteResponse.pipe(request.response);
  }
}

class _ProxyTarget {
  final String remoteUrl;
  final Map<String, String> headers;

  const _ProxyTarget({required this.remoteUrl, required this.headers});
}

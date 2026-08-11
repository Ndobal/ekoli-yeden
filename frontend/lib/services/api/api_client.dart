import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import '../../core/errors/app_exception.dart';
import '../storage/token_storage.dart';
import 'api_response.dart';

/// HTTP status codes used below.
///
/// Written out rather than imported from `dart:io`, which does not exist on
/// web — and web is this application's only target.
class _Status {
  const _Status._();

  static const int ok = 200;
  static const int unauthorized = 401;
  static const int forbidden = 403;
  static const int notFound = 404;
  static const int payloadTooLarge = 413;
  static const int unprocessable = 422;
}

/// The one door to the backend.
///
/// Every read and write in the application goes through this client to the
/// Cloudflare Worker. Nothing in the Flutter bundle talks to D1, R2, YouTube's
/// API or any Cloudflare endpoint directly — the client has no credentials to
/// do so, which is the point of the architecture.
class ApiClient {
  ApiClient({http.Client? httpClient, TokenStorage? tokenStorage})
    : _http = httpClient ?? http.Client(),
      _tokens = tokenStorage;

  final http.Client _http;
  TokenStorage? _tokens;

  /// Called when the session cannot be recovered, so the app can sign out.
  VoidCallback? onSessionExpired;

  /// Guards against a burst of 401s all trying to refresh at once.
  Future<bool>? _refreshInFlight;

  Future<TokenStorage> _storage() async {
    return _tokens ??= await TokenStorage.instance();
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final Uri base = Uri.parse(AppConfig.apiBaseUrl);
    final Map<String, String> params = <String, String>{};
    query?.forEach((String key, dynamic value) {
      if (value == null) return;
      params[key] = value.toString();
    });
    return base.replace(
      path: '${base.path}$path'.replaceAll('//', '/'),
      queryParameters: params.isEmpty ? null : params,
    );
  }

  Future<Map<String, String>> _headers({bool authenticated = true, bool json = true}) async {
    final Map<String, String> headers = <String, String>{'accept': 'application/json'};
    if (json) headers['content-type'] = 'application/json';

    if (authenticated) {
      final TokenStorage storage = await _storage();
      final String? token = storage.accessToken;
      if (token != null && token.isNotEmpty) headers['authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // --- Verbs ----------------------------------------------------------------

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    bool authenticated = true,
  }) {
    return _send(
      () async => _http.get(_uri(path, query), headers: await _headers(authenticated: authenticated)),
      retryOn401: authenticated,
    );
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
    bool authenticated = true,
  }) {
    return _send(
      () async => _http.post(
        _uri(path, query),
        headers: await _headers(authenticated: authenticated),
        body: jsonEncode(body ?? const <String, dynamic>{}),
      ),
      retryOn401: authenticated,
    );
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) {
    return _send(
      () async => _http.put(
        _uri(path),
        headers: await _headers(authenticated: authenticated),
        body: jsonEncode(body ?? const <String, dynamic>{}),
      ),
      retryOn401: authenticated,
    );
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) {
    return _send(
      () async => _http.patch(
        _uri(path),
        headers: await _headers(authenticated: authenticated),
        body: jsonEncode(body ?? const <String, dynamic>{}),
      ),
      retryOn401: authenticated,
    );
  }

  Future<Map<String, dynamic>> delete(String path, {bool authenticated = true}) {
    return _send(
      () async => _http.delete(_uri(path), headers: await _headers(authenticated: authenticated)),
      retryOn401: authenticated,
    );
  }

  /// Uploads a file as `multipart/form-data`.
  ///
  /// Bytes are passed rather than a path because this is a web application:
  /// there is no filesystem path for a file the visitor picked in a browser.
  Future<Map<String, dynamic>> upload({
    required String path,
    required Uint8List bytes,
    required String filename,
    required String folder,
    Map<String, String> fields = const <String, String>{},
    bool authenticated = true,
  }) async {
    final http.MultipartRequest request = http.MultipartRequest('POST', _uri(path))
      ..fields['folder'] = folder
      ..fields.addAll(fields)
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

    request.headers.addAll(await _headers(authenticated: authenticated, json: false));

    try {
      final http.StreamedResponse streamed = await request
          .send()
          .timeout(const Duration(minutes: 3));
      final http.Response response = await http.Response.fromStream(streamed);
      return _decode(response);
    } on TimeoutException {
      throw const UploadException(
        'The upload took too long. Please check your connection and try a smaller file.',
      );
    } on http.ClientException catch (error) {
      throw NetworkException(debugDetail: error.message);
    }
  }

  // --- Paginated helper -----------------------------------------------------

  Future<PaginatedResult<T>> list<T>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    Map<String, dynamic>? query,
    bool authenticated = true,
  }) async {
    final Map<String, dynamic> data = await get(path, query: query, authenticated: authenticated);
    return PaginatedResult<T>.fromJson(data, parse);
  }

  // --- Transport ------------------------------------------------------------

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request, {
    required bool retryOn401,
  }) async {
    try {
      http.Response response = await request().timeout(AppConfig.requestTimeout);

      // One transparent refresh-and-retry. An editor part-way through writing a
      // history entry should not lose it because a token expired.
      if (response.statusCode == _Status.unauthorized && retryOn401) {
        final bool refreshed = await _refreshSession();
        if (refreshed) {
          response = await request().timeout(AppConfig.requestTimeout);
        } else {
          onSessionExpired?.call();
        }
      }

      return _decode(response);
    } on TimeoutException catch (error) {
      throw RequestTimeoutException(debugDetail: error.toString());
    } on http.ClientException catch (error) {
      throw NetworkException(debugDetail: error.message);
    } on FormatException catch (error) {
      throw UnexpectedException(debugDetail: 'Malformed response: ${error.message}');
    }
  }

  Future<bool> _refreshSession() {
    // Concurrent callers share one refresh rather than each spending a token.
    return _refreshInFlight ??= _performRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<bool> _performRefresh() async {
    final TokenStorage storage = await _storage();
    final String? refreshToken = storage.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final http.Response response = await _http
          .post(
            _uri('/api/auth/refresh'),
            headers: <String, String>{'content-type': 'application/json'},
            body: jsonEncode(<String, String>{'refreshToken': refreshToken}),
          )
          .timeout(AppConfig.requestTimeout);

      if (response.statusCode != _Status.ok) {
        await storage.clear();
        return false;
      }

      final Map<String, dynamic> decoded = _decode(response);
      await storage.save(
        accessToken: decoded['accessToken'] as String,
        refreshToken: decoded['refreshToken'] as String,
        expiresInSeconds: (decoded['expiresIn'] as num).toInt(),
      );
      return true;
    } catch (_) {
      await storage.clear();
      return false;
    }
  }

  /// Unwraps the API envelope and converts failures into typed exceptions.
  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body;
    try {
      final dynamic parsed = jsonDecode(utf8.decode(response.bodyBytes));
      body = parsed is Map<String, dynamic> ? parsed : <String, dynamic>{};
    } catch (_) {
      // A non-JSON body means something in front of the Worker answered — a
      // proxy error page, most likely.
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return <String, dynamic>{};
      }
      throw ApiException(
        'The archive returned an unexpected response.',
        response.statusCode,
        debugDetail: 'Non-JSON body (${response.body.length} bytes)',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body['success'] == false) throw _toException(response.statusCode, body);
      final dynamic data = body['data'];
      if (data is Map<String, dynamic>) return data;
      // `/api/health` answers flat rather than enveloped.
      return body;
    }

    throw _toException(response.statusCode, body);
  }

  AppException _toException(int statusCode, Map<String, dynamic> body) {
    final Map<String, dynamic>? error = body['error'] as Map<String, dynamic>?;
    final String message = (error?['message'] as String?) ?? 'The request could not be completed.';
    final String? code = error?['code'] as String?;
    final String? requestId = body['requestId'] as String?;

    switch (statusCode) {
      case _Status.unauthorized:
        return UnauthorizedException(message, requestId);
      case _Status.forbidden:
        return ForbiddenException(message, requestId);
      case _Status.notFound:
        return NotFoundException(message, requestId);
      case _Status.payloadTooLarge:
        return UploadException(message, debugDetail: requestId);
      case _Status.unprocessable:
        return ValidationException(message, _fieldErrors(error), debugDetail: requestId);
      default:
        return ApiException(message, statusCode, code: code, debugDetail: requestId);
    }
  }

  Map<String, List<String>> _fieldErrors(Map<String, dynamic>? error) {
    final dynamic details = error?['details'];
    if (details is! Map<String, dynamic>) return const <String, List<String>>{};

    return details.map<String, List<String>>((String field, dynamic messages) {
      final List<String> list = messages is List
          ? messages.map((dynamic item) => item.toString()).toList(growable: false)
          : <String>[messages.toString()];
      return MapEntry<String, List<String>>(field, list);
    });
  }

  void dispose() => _http.close();
}

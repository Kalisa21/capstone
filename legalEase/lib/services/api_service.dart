import 'dart:convert';

import 'package:http/http.dart' as http;

/// Simple API service wrapper providing GET/POST with timeout, JSON decoding,
/// and basic error normalization. Extend as needed.
class ApiService {
  ApiService({required this.baseUrl, this.defaultHeaders});

  final String baseUrl;
  final Map<String, String>? defaultHeaders;

  Map<String, String> _composeHeaders([Map<String, String>? extra]) {
    return {
      'Content-Type': 'application/json',
      ...?defaultHeaders,
      ...?extra,
    };
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    return Uri.parse(baseUrl + (path.startsWith('/') ? path : '/$path'))
        .replace(queryParameters: query?.map((k, v) => MapEntry(k, '$v')));
  }

  Future<ApiResponse> get(String path, {Map<String, dynamic>? query, Map<String, String>? headers, Duration timeout = const Duration(seconds: 15)}) async {
    final uri = _uri(path, query);
    try {
      final resp = await http.get(uri, headers: _composeHeaders(headers)).timeout(timeout);
      return _toApiResponse(resp);
    } catch (e) {
      return ApiResponse(error: 'GET failed: $e');
    }
  }

  Future<ApiResponse> post(String path, {Object? body, Map<String, String>? headers, Duration timeout = const Duration(seconds: 20)}) async {
    final uri = _uri(path);
    try {
      final jsonBody = body == null ? null : jsonEncode(body);
      final resp = await http.post(uri, headers: _composeHeaders(headers), body: jsonBody).timeout(timeout);
      return _toApiResponse(resp);
    } catch (e) {
      return ApiResponse(error: 'POST failed: $e');
    }
  }

  ApiResponse _toApiResponse(http.Response resp) {
    dynamic decoded;
    try {
      decoded = jsonDecode(resp.body);
    } catch (_) {
      decoded = resp.body;
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return ApiResponse(data: decoded, statusCode: resp.statusCode);
    }
    return ApiResponse(data: decoded, statusCode: resp.statusCode, error: 'HTTP ${resp.statusCode}: ${resp.reasonPhrase}');
  }
}

class ApiResponse {
  final dynamic data;
  final int? statusCode;
  final String? error;
  bool get isOk => error == null;
  ApiResponse({this.data, this.statusCode, this.error});
}

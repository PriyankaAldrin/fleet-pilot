import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config.dart';
import 'token_storage.dart';

/// Error shown to the user. Built from the API's problem details response.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.fieldErrors = const {}});

  final String message;
  final int? statusCode;
  final Map<String, List<String>> fieldErrors;

  /// True when the request never reached the server (no signal, server down).
  bool get isNetwork => statusCode == null;

  /// True for 4xx answers: retrying the same request will not help.
  bool get isRejected => statusCode != null && statusCode! >= 400 && statusCode! < 500 && statusCode != 401;

  @override
  String toString() => message;

  factory ApiException.from(Object error) {
    if (error is ApiException) return error;
    if (error is DioException) {
      final res = error.response;
      if (res == null) {
        return ApiException('Cannot reach the server. Check your connection.');
      }
      final data = res.data;
      if (data is Map) {
        final errors = <String, List<String>>{};
        final raw = data['errors'];
        if (raw is Map) {
          raw.forEach((k, v) => errors[k.toString()] = (v as List).map((e) => e.toString()).toList());
        }
        final detail = data['detail'] ?? data['title'];
        final first = errors.values.expand((e) => e).firstOrNull;
        return ApiException(
          errors.isNotEmpty && first != null ? first : (detail?.toString() ?? 'Request failed (${res.statusCode}).'),
          statusCode: res.statusCode,
          fieldErrors: errors,
        );
      }
      return ApiException('Request failed (${res.statusCode}).', statusCode: res.statusCode);
    }
    return ApiException(error.toString());
  }
}

/// Called when the refresh token is no longer valid, so the app can return to the login screen.
typedef SessionExpired = void Function();

/// Dio configured for the API: adds the bearer token and refreshes it once on a 401.
class ApiClient {
  ApiClient(this._tokens, {String baseUrl = AppConfig.apiBaseUrl}) : baseUrl = baseUrl {
    dio = Dio(BaseOptions(
      baseUrl: '$baseUrl/api/v1',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 60),
    ));
    _refreshDio = Dio(BaseOptions(baseUrl: '$baseUrl/api/v1'));
    dio.interceptors.add(QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _tokens.accessToken();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (error, handler) async {
        final req = error.requestOptions;
        final is401 = error.response?.statusCode == 401;
        if (!is401 || req.extra['retried'] == true || req.path.startsWith('/auth/')) {
          return handler.next(error);
        }
        final refreshed = await _refresh();
        if (!refreshed) {
          onSessionExpired?.call();
          return handler.next(error);
        }
        // A multipart body cannot be sent twice; [multipart] rebuilds it and retries.
        if (req.data is FormData) return handler.next(error);
        try {
          req.extra['retried'] = true;
          req.headers['Authorization'] = 'Bearer ${await _tokens.accessToken()}';
          final response = await dio.fetch<dynamic>(req);
          handler.resolve(response);
        } on DioException catch (e) {
          handler.next(e);
        }
      },
    ));
  }

  final TokenStorage _tokens;
  final String baseUrl;
  late final Dio dio;
  late final Dio _refreshDio;
  SessionExpired? onSessionExpired;
  Future<bool>? _refreshing;

  /// Headers to load protected images (odometer photos).
  Future<Map<String, String>> authHeaders() async {
    final token = await _tokens.accessToken();
    return token == null ? {} : {'Authorization': 'Bearer $token'};
  }

  String absolute(String path) => path.startsWith('http') ? path : '$baseUrl$path';

  Future<bool> _refresh() => _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<bool> _doRefresh() async {
    final refresh = await _tokens.refreshToken();
    if (refresh == null) return false;
    try {
      final res = await _refreshDio.post<Map<String, dynamic>>('/auth/refresh', data: {'refreshToken': refresh});
      final data = res.data!;
      await _tokens.save(data['accessToken'] as String, data['refreshToken'] as String);
      return true;
    } on DioException catch (e) {
      // Only a definite "no" from the server ends the session; offline keeps the tokens.
      if (e.response?.statusCode == 401) await _tokens.clear();
      return false;
    }
  }

  /// Posts a multipart form. [build] is called again if the token had to be refreshed.
  Future<Response<T>> multipart<T>(String path, Future<FormData> Function() build) async {
    try {
      return await dio.post<T>(path, data: await build());
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 && await _tokens.accessToken() != null) {
        try {
          return await dio.post<T>(path, data: await build(), options: Options(extra: {'retried': true}));
        } catch (e2) {
          throw ApiException.from(e2);
        }
      }
      throw ApiException.from(e);
    } catch (e) {
      throw ApiException.from(e);
    }
  }

  Future<T> call<T>(Future<T> Function(Dio dio) request) async {
    try {
      return await request(dio);
    } catch (e) {
      throw ApiException.from(e);
    }
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref.watch(tokenStorageProvider)));

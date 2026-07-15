import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

/// Thrown when a request is attempted while the device has no route to the
/// local backend. Callers should catch this and fall back to Hive cache.
class OfflineException implements Exception {
  final String message;
  OfflineException([this.message = 'No connection to local backend']);
  @override
  String toString() => message;
}

class DioClient {
  final Dio dio;
  final FlutterSecureStorage _secureStorage;
  final String baseUrl;

  DioClient({
    String? baseUrl,
    FlutterSecureStorage? secureStorage,
  })  : baseUrl = baseUrl ?? AppConfig.defaultBaseUrl,
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? AppConfig.defaultBaseUrl,
            connectTimeout: AppConfig.connectTimeout,
            receiveTimeout: AppConfig.receiveTimeout,
            headers: {'Content-Type': 'application/json'},
          ),
        ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _secureStorage.read(key: AppConfig.keyAccessToken);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // 401 -> attempt a single refresh, then retry once.
          if (error.response?.statusCode == 401) {
            final refreshed = await _tryRefreshToken();
            if (refreshed) {
              final retryReq = error.requestOptions;
              final token = await _secureStorage.read(key: AppConfig.keyAccessToken);
              retryReq.headers['Authorization'] = 'Bearer $token';
              try {
                final response = await dio.fetch(retryReq);
                return handler.resolve(response);
              } catch (_) {
                // fall through to original error
              }
            }
          }

          if (error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.connectionTimeout) {
            return handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                error: OfflineException(),
                type: error.type,
              ),
            );
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<bool> _tryRefreshToken() async {
    final refreshToken = await _secureStorage.read(key: AppConfig.keyRefreshToken);
    if (refreshToken == null) return false;
    try {
      final response = await Dio(BaseOptions(baseUrl: baseUrl)).post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final newAccess = response.data['accessToken'] as String?;
      final newRefresh = response.data['refreshToken'] as String?;
      if (newAccess == null) return false;
      await _secureStorage.write(key: AppConfig.keyAccessToken, value: newAccess);
      if (newRefresh != null) {
        await _secureStorage.write(key: AppConfig.keyRefreshToken, value: newRefresh);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}

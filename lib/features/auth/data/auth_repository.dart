import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../domain/user.dart';

class AuthRepository {
  final DioClient _client;
  final FlutterSecureStorage _secureStorage;

  AuthRepository(this._client, {FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  Future<User> login({required String email, required String password}) async {
    final response = await _client.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    await _persistTokens(response.data);
    return User.fromJson(response.data['user'] as Map<String, dynamic>);
  }

  Future<User> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _client.dio.post('/auth/register', data: {
      'name': name,
      'email': email,
      'password': password,
    });
    await _persistTokens(response.data);
    return User.fromJson(response.data['user'] as Map<String, dynamic>);
  }

  Future<void> forgotPassword(String email) async {
    await _client.dio.post('/auth/forgot-password', data: {'email': email});
  }

  Future<void> logout() async {
    try {
      await _client.dio.post('/auth/logout');
    } on DioException {
      // best-effort — clear local tokens regardless
    }
    await _secureStorage.delete(key: AppConfig.keyAccessToken);
    await _secureStorage.delete(key: AppConfig.keyRefreshToken);
  }

  Future<bool> hasSession() async {
    final token = await _secureStorage.read(key: AppConfig.keyAccessToken);
    return token != null;
  }

  Future<void> _persistTokens(Map<String, dynamic> data) async {
    final access = data['accessToken'] as String?;
    final refresh = data['refreshToken'] as String?;
    if (access != null) {
      await _secureStorage.write(key: AppConfig.keyAccessToken, value: access);
    }
    if (refresh != null) {
      await _secureStorage.write(key: AppConfig.keyRefreshToken, value: refresh);
    }
  }
}

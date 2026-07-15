import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/network/dio_client.dart';
import '../data/auth_repository.dart';
import '../domain/user.dart';

final dioClientProvider = Provider<DioClient>((ref) => DioClient());

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(dioClientProvider)),
);

enum AuthStatus { unknown, authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({AuthStatus? status, User? user, String? errorMessage}) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(const AuthState()) {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final hasSession = await _repository.hasSession();
    state = state.copyWith(
      status: hasSession
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated,
    );
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final user = await _repository.login(email: email, password: password);
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } on DioException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: _messageFor(e),
      );
    }
  }

  Future<void> register(String name, String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final user = await _repository.register(
        name: name,
        email: email,
        password: password,
      );
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } on DioException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: _messageFor(e),
      );
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  String _messageFor(DioException e) {
    if (e.error is OfflineException) {
      return "Can't reach your local backend. Make sure the Docker Compose "
          "stack is running, then try again.";
    }
    final data = e.response?.data;
    if (data is Map && data['message'] is String)
      return data['message'] as String;
    return 'Something went wrong. Please try again.';
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.watch(authRepositoryProvider)),
);

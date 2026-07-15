import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/chat/presentation/screens/chat_list_screen.dart';
import '../../features/chat/presentation/screens/chat_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/splash_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authProvider.notifier);

  return GoRouter(
    initialLocation: '/chats',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final status = ref.read(authProvider).status;
      final loc = state.matchedLocation;
      final onAuthPages = loc == '/login' || loc == '/register' || loc == '/forgot-password';

      if (status == AuthStatus.unknown || status == AuthStatus.loading) {
        return null; // splash / let current page render, no redirect yet
      }
      if (status == AuthStatus.unauthenticated && !onAuthPages) {
        return '/login';
      }
      if (status == AuthStatus.authenticated && onAuthPages) {
        return '/chats';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: '/chats', builder: (context, state) => const ChatListScreen()),
      GoRoute(
        path: '/chats/:id',
        builder: (context, state) => ChatScreen(conversationId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    ],
  );
});

/// Bridges Riverpod's AuthState into a Listenable so GoRouter re-evaluates
/// its redirect() whenever auth status changes (login/logout/token expiry).
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authProvider, (previous, next) {
      if (previous?.status != next.status) notifyListeners();
    });
  }
}

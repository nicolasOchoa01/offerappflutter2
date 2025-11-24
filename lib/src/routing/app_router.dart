import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:myapp/src/presentation/screens/auth/forgot_password_screen.dart';
import 'package:myapp/src/presentation/screens/auth/login_screen.dart';
import 'package:myapp/src/presentation/screens/auth/register_screen.dart';
import 'package:myapp/src/presentation/screens/home_screen.dart';
import 'package:myapp/src/services/auth_service.dart';

class AppRouter {
  final BuildContext context;

  AppRouter(this.context);

  late final GoRouter router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
       GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
    ],
    redirect: (BuildContext context, GoRouterState state) {
       final authService = Provider.of<AuthService>(context, listen: false);
      final bool loggedIn = authService.currentUser != null;
      final bool loggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register' || state.matchedLocation == '/forgot-password';

      if (!loggedIn) {
        return loggingIn ? null : '/login';
      }

      if (loggingIn) {
        return '/';
      }

      return null;
    },
     refreshListenable: GoRouterRefreshStream(context.read<AuthService>().authStateChanges),
  );
}

// Esta clase ayuda a go_router a escuchar los cambios de estado de autenticación
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

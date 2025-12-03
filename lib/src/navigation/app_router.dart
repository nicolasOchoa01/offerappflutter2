import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/src/application/auth/auth_notifier.dart';
import 'package:myapp/src/application/auth/auth_state.dart';
import 'package:myapp/src/domain/entities/post.dart';

import 'package:myapp/src/presentation/screens/auth/forgot_password_screen.dart';
import 'package:myapp/src/presentation/screens/auth/login_screen.dart';
import 'package:myapp/src/presentation/screens/auth/register_screen.dart';

import 'package:myapp/src/presentation/screens/create_post_screen.dart';
import 'package:myapp/src/presentation/screens/home_screen.dart';
import 'package:myapp/src/presentation/screens/main_screen.dart';
import 'package:myapp/src/presentation/screens/post_detail_screen.dart';
import 'package:myapp/src/presentation/screens/profile_screen.dart';

class AppRouter {
  final AuthNotifier authNotifier;

  AppRouter({required this.authNotifier});

  late final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: _routes,
    redirect: _redirect,
    refreshListenable: authNotifier,
  );

  List<RouteBase> get _routes => [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainScreen(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) {
                final authState = authNotifier.state;
                if (authState is AuthSuccess) {
                  return ProfileScreen(userId: authState.user.id);
                }
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              },
              routes: [
                GoRoute(
                  path: ':userId',
                  builder: (context, state) {
                    final userId = state.pathParameters['userId']!;
                    return ProfileScreen(userId: userId);
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    ),

    GoRoute(
      path: '/post/:postId',
      builder: (context, state) {
        final post = state.extra as Post?;
        if (post != null) {
          return PostDetailScreen(post: post);
        }
        return const Scaffold(
          body: Center(child: Text("Post not found or ID is missing")),
        );
      },
    ),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/create_post',
      builder: (context, state) {
        
        return const CreatePostScreen();
      },
    ),
  ];

  String? _redirect(BuildContext context, GoRouterState state) {
    final loggedIn = authNotifier.state is AuthSuccess;
    final location = state.uri.toString();

    final isPublicPath =
        location == '/login' ||
        location == '/register' ||
        location == '/forgot-password';

    if (!loggedIn && !isPublicPath) {
      return '/login';
    }

    if (loggedIn && isPublicPath) {
      return '/';
    }

    return null;
  }
}

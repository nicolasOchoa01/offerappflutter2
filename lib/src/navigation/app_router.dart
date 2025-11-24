import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/src/data/repositories/auth_repository.dart';
import 'package:myapp/src/domain/entities/post.dart';
import 'package:myapp/src/domain/entities/user.dart';
import 'package:myapp/src/presentation/screens/create_post_screen.dart';
import 'package:myapp/src/presentation/screens/home_screen.dart';
import 'package:myapp/src/presentation/screens/login_screen.dart';
import 'package:myapp/src/presentation/screens/main_screen.dart';
import 'package:myapp/src/presentation/screens/post_detail_screen.dart';
import 'package:myapp/src/presentation/screens/profile_screen.dart';
import 'package:myapp/src/presentation/screens/register_screen.dart';

class AppRouter {
  final AuthRepository authRepository;

  AppRouter({required this.authRepository});

  late final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: _routes,
    redirect: _redirect,
    refreshListenable: GoRouterRefreshStream(authRepository.userChanges),
  );

  List<RouteBase> get _routes => [
        // Main navigation shell with tabs
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainScreen(navigationShell: navigationShell);
          },
          branches: [
            // Branch for the home tab
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => const HomeScreen(),
                ),
              ],
            ),
            // Branch for the profile tab
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (context, state) {
                    final userId = authRepository.currentUser?.uid;
                    // This should be handled by the redirect, but as a fallback:
                    return userId != null ? ProfileScreen(userId: userId) : const Center(child: CircularProgressIndicator());
                  },
                  routes: [
                     GoRoute(
                        path: ':userId', // e.g., /profile/123
                        builder: (context, state) {
                          final userId = state.pathParameters['userId']!;
                          return ProfileScreen(userId: userId);
                        },
                      ),
                  ]
                ),
              ],
            ),
          ],
        ),
        // Top-level route for post details
        GoRoute(
          path: '/post/:postId',
          builder: (context, state) {
            final post = state.extra as Post?;
            if (post != null) {
              return PostDetailScreen(post: post);
            }
            return const Scaffold(body: Center(child: Text("Post not found or ID is missing")));
          },
        ),
        // Top-level route for login
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        // Top-level route for register
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        // Top-level route for creating a post
         GoRoute(
          path: '/create_post',
           builder: (context, state) {
             return StreamBuilder<User?>(
                stream: authRepository.userChanges,
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return CreatePostScreen(user: snapshot.data!); // Pass the domain User
                  }                  
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                },
              );
           }
        ),
      ];

  String? _redirect(BuildContext context, GoRouterState state) {
    final bool loggedIn = authRepository.currentUser != null;
    final String location = state.uri.toString();

    // If user is not logged in and not on login/register, redirect to login.
    if (!loggedIn && location != '/login' && location != '/register') {
      return '/login';
    }

    // If user is logged in and tries to access login/register, redirect to home.
    if (loggedIn && (location == '/login' || location == '/register')) {
      return '/';
    }

    // No redirect needed
    return null;
  }
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

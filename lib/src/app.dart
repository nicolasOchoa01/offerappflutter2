import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:myapp/src/navigation/app_router.dart';
import 'package:myapp/src/data/repositories/auth_repository.dart';
import 'package:myapp/src/data/services/session_manager.dart';
import 'package:myapp/src/application/auth/auth_notifier.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>(
          create: (_) => AuthRepository(),
        ),
        Provider<SessionManager>(
          create: (_) => SessionManager(),
        ),
        Provider<FirebaseMessaging>(
          create: (_) => FirebaseMessaging.instance,
        ),
        ChangeNotifierProvider<AuthNotifier>(
          create: (context) => AuthNotifier(
            context.read<AuthRepository>(),
            context.read<SessionManager>(),
            context.read<FirebaseMessaging>(),
          ),
        ),
      ],
      child: Builder(
        builder: (context) {
          final authNotifier = context.watch<AuthNotifier>();
          final router = AppRouter(authNotifier: authNotifier).router;
          return MaterialApp.router(
            routerConfig: router,
            title: 'Flutter App',
            theme: ThemeData(
              primarySwatch: Colors.blue,
              visualDensity: VisualDensity.adaptivePlatformDensity,
            ),
          );
        },
      ),
    );
  }
}

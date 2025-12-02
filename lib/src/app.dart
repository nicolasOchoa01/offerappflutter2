import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:myapp/src/navigation/app_router.dart';
import 'services/auth_service.dart';
import 'package:myapp/src/application/auth/auth_notifier.dart';



class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => AuthService(),
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

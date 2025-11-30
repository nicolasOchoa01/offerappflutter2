import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:myapp/firebase_options.dart';
import 'package:myapp/src/application/auth/auth_notifier.dart';
import 'package:myapp/src/application/auth/auth_state.dart';
import 'package:myapp/src/application/main/main_notifier.dart';
import 'package:myapp/src/application/theme/theme_notifier.dart';
import 'package:myapp/src/data/repositories/auth_repository.dart';
import 'package:myapp/src/data/repositories/post_repository.dart';
import 'package:myapp/src/data/services/session_manager.dart';
import 'package:myapp/src/navigation/app_router.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('es_ES', null);
  

  final authRepository = AuthRepository();
  final postRepository = PostRepository();
  final sessionManager = SessionManager();
  final firebaseMessaging = FirebaseMessaging.instance;

  runApp(MyApp(
    authRepository: authRepository,
    postRepository: postRepository,
    sessionManager: sessionManager,
    firebaseMessaging: firebaseMessaging,
  ));
}

class MyApp extends StatelessWidget {
  final AuthRepository authRepository;
  final PostRepository postRepository;
  final SessionManager sessionManager;
  final FirebaseMessaging firebaseMessaging;

  const MyApp({
    super.key,
    required this.authRepository,
    required this.postRepository,
    required this.sessionManager,
    required this.firebaseMessaging,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [

        Provider.value(value: authRepository),
        Provider.value(value: postRepository),
        Provider.value(value: sessionManager),
        Provider.value(value: firebaseMessaging),
        

        ChangeNotifierProvider(
          create: (context) => ThemeNotifier(sessionManager),
        ),
        ChangeNotifierProvider(
          create: (context) => AuthNotifier(
            authRepository,
            sessionManager,
            firebaseMessaging,
          ),
        ),
        

        ChangeNotifierProxyProvider<AuthNotifier, MainNotifier?>(
          create: (_) => null, // Initially null, created on auth success.
          update: (context, authNotifier, previousMainNotifier) {
            final authState = authNotifier.state;
            if (authState is AuthSuccess) {
              // When authenticated, create/update MainNotifier.
              if (previousMainNotifier == null || previousMainNotifier.user.id != authState.user.id) {
                return MainNotifier(
                  authState.user,
                  context.read<PostRepository>(),
                  context.read<AuthRepository>(),
                );
              }
              return previousMainNotifier;
            }
            return null;
          },
        ),
      ],
      child: Builder(
        builder: (context) {

          final authNotifier = context.watch<AuthNotifier>();
          final appRouter = AppRouter(authNotifier: authNotifier);

          return MaterialApp.router(
            title: 'OfferApp',

            themeMode: context.watch<ThemeNotifier>().themeMode,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.light),
              visualDensity: VisualDensity.adaptivePlatformDensity,
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
            ),
            routerConfig: appRouter.router,
          );
        },
      ),
    );
  }
}

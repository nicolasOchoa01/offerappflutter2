import 'package:flutter/material.dart';
import 'package:myapp/src/data/repositories/auth_repository.dart';
import 'package:myapp/src/domain/entities/user.dart';
import 'package:myapp/src/presentation/screens/create_post_screen.dart';
import 'package:myapp/src/presentation/screens/home_screen.dart';
import 'package:myapp/src/presentation/screens/login_screen.dart';
import 'package:myapp/src/presentation/screens/profile_screen.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: context.watch<AuthRepository>().userChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snapshot.data;
        final authRepo = context.read<AuthRepository>();
        final currentUser = authRepo.currentUser;

        if (user == null) {
          return const LoginScreen();
        }

        final List<Widget> screens = [
          const HomeScreen(),
          const CreatePostScreen(),
          currentUser != null
              ? ProfileScreen(userId: currentUser.uid) // Corrected from .id to .uid
              : const Scaffold(body: Center(child: Text("Inicia sesión para ver tu perfil."))),
        ];

        final List<String> titles = [
          'OfferApp',
          'Crear Oferta',
          currentUser != null ? 'Mi Perfil' : 'Perfil'
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text(titles[_selectedIndex]),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await authRepo.signOut();
                },
              )
            ],
          ),
          body: IndexedStack(
            index: _selectedIndex,
            children: screens,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
              BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Crear'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
            ],
          ),
          floatingActionButton: _selectedIndex == 0 ? FloatingActionButton(
            onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreatePostScreen()));
            },
            child: const Icon(Icons.add),
          ) : null,
        );
      },
    );
  }
}

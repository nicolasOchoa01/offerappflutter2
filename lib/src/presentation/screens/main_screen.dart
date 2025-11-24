import 'package:flutter/material.dart';
import 'package:myapp/src/data/repositories/auth_repository.dart';
import 'package:myapp/src/domain/entities/user.dart';
import 'package:myapp/src/presentation/screens/create_post_screen.dart';
import 'package:myapp/src/presentation/screens/home_screen.dart';
import 'package:myapp/src/presentation/screens/login_screen.dart';
import 'package:myapp/src/presentation/screens/profile_screen.dart';
import 'package:myapp/src/presentation/widgets/custom_header.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  String _searchQuery = '';

  void _onItemTapped(int index, User user) {
    if (index == 1) { // Index 1 is for creating a post
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => CreatePostScreen(user: user)));
    } else {
      // Adjust index for the screens list (0 -> Home, 2 -> Profile)
      setState(() {
        _selectedIndex = (index == 2) ? 1 : 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: context.watch<AuthRepository>().userChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        final authRepo = context.read<AuthRepository>();

        final List<Widget> screens = [
          HomeScreen(searchQuery: _searchQuery),
          ProfileScreen(userId: user.id),
        ];

        final List<String> titles = ['OfferApp', 'Mi Perfil'];

        return Scaffold(
          appBar: CustomHeader(
            username: user.username,
            title: _selectedIndex == 0 ? null : titles[_selectedIndex],
            query: _selectedIndex == 0 ? _searchQuery : null,
            onQueryChange: (query) => setState(() => _searchQuery = query),
            onLogoClick: () => _onItemTapped(0, user),
            onBackClicked: _selectedIndex != 0 ? () => _onItemTapped(0, user) : null,
            onProfileClick: () => _onItemTapped(2, user), // Navigate to profile
            onSessionClicked: () => authRepo.signOut(),
          ),
          body: IndexedStack(
            index: _selectedIndex,
            children: screens,
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: (_selectedIndex == 1) ? 2 : 0, // Highlight correct item
            onTap: (index) => _onItemTapped(index, user),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
              BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Crear'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
            ],
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/src/data/repositories/auth_repository.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainScreen({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {

    const int homeBranchIndex = 0;
    const int profileBranchIndex = 1;

    return Scaffold(

      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(

        currentIndex: navigationShell.currentIndex == profileBranchIndex ? 2 : navigationShell.currentIndex,


        type: BottomNavigationBarType.fixed,

        onTap: (index) {
          if (index == 1) {
            context.push('/create_post');
          } else {

            int targetBranchIndex = index == 0 ? homeBranchIndex : profileBranchIndex;


            navigationShell.goBranch(
              targetBranchIndex,

              initialLocation: targetBranchIndex == navigationShell.currentIndex,
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Crear'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
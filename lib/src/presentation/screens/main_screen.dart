import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/src/data/repositories/auth_repository.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainScreen({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;
    
    // Altura compacta y deseada (70.0)
    final double footerHeight = isTablet ? 64.0 : 70.0; 
    
    // Obtener el tema para los colores (para la selección de íconos)
    final theme = Theme.of(context);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: navigationShell,

      // FloatingActionButton que sobresale
      floatingActionButton: Transform.translate(
        // Desplazamiento ajustado (5.0)
        offset: const Offset(0, 12), 
        child: FloatingActionButton(
          onPressed: () => context.push('/create_post'),
          backgroundColor: theme.colorScheme.primary,
          // Forma circular
          shape: const CircleBorder(), 
          child: const Icon(Icons.add, size: 30, color: Colors.white), 
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // Footer compacto con muesca y texto
      bottomNavigationBar: SizedBox(
        height: footerHeight, 
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(), 
          notchMargin: 8.0, 
          elevation: 4,
          
          child: Padding(
            padding: const EdgeInsets.only(left: 8, right: 8, top: 4), 
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start, 
              children: [
                // Ícono 1: Home (Inicio)
                _buildNavItem(
                  context, 
                  navigationShell, 
                  branchIndex: 0,
                  icon: Icons.home,
                  label: 'Inicio',
                ),

                // Espacio para el FAB con el texto "Publicar" debajo
                SizedBox(
                  width: isTablet ? 80 : 72, 
                  child: Center(
                    child: Padding(
                      // 🔧 AJUSTE: Reducción del padding para que el texto sea visible
                      padding: const EdgeInsets.only(top: 30.0), 
                      child: Text(
                        'Publicar', // Nombre del botón
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)
                      ),
                    ),
                  ),
                ), 

                // Ícono 2: Person (Perfil)
                _buildNavItem(
                  context, 
                  navigationShell, 
                  branchIndex: 1,
                  icon: Icons.person,
                  label: 'Perfil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Función de ayuda: Usa parámetros, reduce el padding y añade selección de color.
  Widget _buildNavItem(BuildContext context, StatefulNavigationShell navigationShell, {required int branchIndex, required IconData icon, required String label}) {
    // Determina si el ícono está seleccionado
    final bool isSelected = navigationShell.currentIndex == branchIndex;
    final Color itemColor = isSelected 
        ? Theme.of(context).colorScheme.primary 
        : Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: () => navigationShell.goBranch(branchIndex),
      // Padding vertical a 1.0 para evitar desbordamiento
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.0, horizontal: 8.0), 
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start, 
          children: [
            Icon(icon, size: 24, color: itemColor), 
            const SizedBox(height: 2), 
            Text(label, style: TextStyle(fontSize: 10, color: itemColor)), 
          ],
        ),
      ),
    );
  }
}
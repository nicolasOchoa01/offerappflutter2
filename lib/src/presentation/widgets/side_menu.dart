import 'package:flutter/material.dart';
import 'package:myapp/src/application/main/main_notifier.dart';
import 'package:myapp/src/application/theme/theme_notifier.dart';
import 'package:provider/provider.dart';

class SideMenu extends StatelessWidget {
  const SideMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final mainNotifier = context.watch<MainNotifier?>();
    final themeNotifier = context.watch<ThemeNotifier>();
    
    
    final categories = [
      "Todos", "Alimentos", "Tecnología", "Moda", "Deportes", "Construcción",
      "Animales", "Electrodomésticos", "Servicios", "Educación",
      "Juguetes", "Vehículos", "Otros"
    ];

    if (mainNotifier == null) {
      return const Drawer(); 
    }

    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.primary,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
            child: Center(
              child: Text(
                "Filtros",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  child: Text(
                    'Categorías',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                
                ...categories.map((category) {
                  final isSelected = mainNotifier.selectedCategory == category;
                  return ListTile(
                    dense: true,
                    title: Text(
                      category,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Theme.of(context).colorScheme.primary : null,
                      ),
                    ),
                    tileColor: isSelected ? Theme.of(context).colorScheme.primary.withAlpha(25) : null,
                    onTap: () {
                      mainNotifier.filterByCategory(category);
                      Navigator.of(context).pop(); // Close the drawer
                    },
                  );
                }),
                const Divider(height: 20),
                
                SwitchListTile(
                  title: Text(
                    'Modo Oscuro',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  value: themeNotifier.isDarkMode ?? false,
                  onChanged: (bool value) {
                    themeNotifier.setTheme(value);
                  },
                   secondary: Icon(
                    themeNotifier.isDarkMode ?? false ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

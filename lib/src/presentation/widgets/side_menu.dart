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

    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.primary,
            padding: const EdgeInsets.symmetric(vertical: 32.0),
            child: Center(
              child: Text(
                "Filtros",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 20,
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
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                  child: Text(
                    'Categorías',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                ...categories.map((category) {
                  final isSelected = mainNotifier?.selectedCategory == category;
                  return ListTile(
                    title: Text(
                      category,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    tileColor: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.12) : null,
                    onTap: () {
                      mainNotifier?.filterByCategory(category);
                      Navigator.of(context).pop();
                    },
                  );
                }).toList(),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(
                    'Modo Oscuro',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  value: themeNotifier.isDarkMode ?? false,
                  onChanged: (bool value) {
                    themeNotifier.setTheme(value);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
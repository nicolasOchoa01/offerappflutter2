import 'package:flutter/material.dart';
import 'package:myapp/src/application/main/main_notifier.dart'; // Asegúrate de que la ruta sea correcta

class SideMenu extends StatelessWidget {
  final MainNotifier mainNotifier; 

  const SideMenu({super.key, required this.mainNotifier});
  
  // ⚠️ LISTA DE CATEGORÍAS ACTUALIZADA (Basada en tus imágenes)
  final List<String> categories = const [
    'Todos', // Opción para quitar el filtro
    'Alimentos',
    'Tecnología',
    'Moda',
    'Deportes',
    'Construcción',
    'Animales',
    'Electrodomésticos',
    'Servicios',
    'Educación',
    'Juguetes',
    'Vehículos',
    'Otros',
  ];

  // 🛠️ Mapeo de categorías a íconos contextualmente relevantes
  final Map<String, IconData> categoryIcons = const {
    'Todos': Icons.list,
    'Alimentos': Icons.restaurant_menu, // O Icons.local_grocery_store
    'Tecnología': Icons.computer, // O Icons.phone_android
    'Moda': Icons.checkroom, // O Icons.shopping_bag
    'Deportes': Icons.sports_soccer, // O Icons.fitness_center
    'Construcción': Icons.construction,
    'Animales': Icons.pets,
    'Electrodomésticos': Icons.kitchen, // O Icons.electrical_services
    'Servicios': Icons.business_center, // O Icons.design_services
    'Educación': Icons.school,
    'Juguetes': Icons.toys,
    'Vehículos': Icons.directions_car,
    'Otros': Icons.category,
  };
  
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text(
              'Categorías',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          
          // Construimos los elementos del menú usando el mapeo de categorías
          ...categories.map((category) {
            return _buildMenuItem(
              categoryIcons[category] ?? Icons.category, 
              category,
              mainNotifier, 
              context,
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, MainNotifier mainNotifier, BuildContext context) {
    // Usamos mainNotifier.activeCategory para resaltar la categoría seleccionada
    final bool isSelected = mainNotifier.activeCategory == title;
    
    return ListTile(
      leading: Icon(
        icon, 
        color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      ),
      onTap: () {
        // Aplica el filtro de categoría y cierra el menú
        mainNotifier.setCategoryFilter(title);
        Navigator.pop(context); 
      },
    );
  }
}
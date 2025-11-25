import 'package:flutter/material.dart';

class SideMenu extends StatelessWidget {
  const SideMenu({super.key});
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text(
              'Categorías',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          _buildMenuItem(Icons.card_giftcard, 'Festividades'),
          _buildMenuItem(Icons.store, 'Almacén'),
          _buildMenuItem(
            Icons.restaurant,
            'Carnicería, Pescadería y Verdulería',
          ),
          _buildMenuItem(Icons.ac_unit, 'Frescos y Congelados'),
          _buildMenuItem(Icons.local_drink, 'Bebidas'),
          _buildMenuItem(Icons.spa, 'Perfumería'),
          _buildMenuItem(Icons.face, 'Belleza'),
          _buildMenuItem(Icons.cleaning_services, 'Limpieza'),
          _buildMenuItem(Icons.child_care, 'Bebés y Niños'),
          _buildMenuItem(Icons.pets, 'Mascotas'),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        // Navegación o lógica según categoría
      },
    );
  }
}

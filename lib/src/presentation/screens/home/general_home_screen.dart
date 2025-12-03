import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/src/presentation/widgets/side_menu.dart';
import 'package:myapp/src/presentation/widgets/custom_header.dart';
import 'package:myapp/src/application/auth/auth_notifier.dart';
import 'package:provider/provider.dart';

class GeneralHomeScreen extends StatefulWidget {
  const GeneralHomeScreen({super.key});

  @override
  State<GeneralHomeScreen> createState() => _GeneralHomeScreenState();
}

class _GeneralHomeScreenState extends State<GeneralHomeScreen> {
  String sortOption = 'fecha';

  final List<_BannerItem> banners = const [
    _BannerItem(
      imagePath: 'assets/banners/electro.jpg',
      label: 'Electrodomésticos',
      filter: 'electrodomesticos',
    ),
    _BannerItem(
      imagePath: 'assets/banners/alimentos.jpg',
      label: 'Alimentos',
      filter: 'alimentos',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final authNotifier = context.read<AuthNotifier>();

    return Scaffold(
      drawer: const SideMenu(),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: CustomHeader(
          username: 'Gastón', 
          query: '',
          onQueryChange: (value) {
            context.push('/home?filter=$value&order=$sortOption');
          },
          onProfileClick: () => context.go('/profile'),
          onSessionClicked: () => authNotifier.logout(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 20),
          const Text(
            'Explorá las mejores ofertas del día',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _buildSortDropdown(),
          const SizedBox(height: 12),
          _buildBannerCarousel(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSortDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text('Ordenar por: ',
              style: TextStyle(fontWeight: FontWeight.bold)),
          DropdownButton<String>(
            value: sortOption,
            items: const [
              DropdownMenuItem(
                  value: 'fecha', child: Text('Fecha (más recientes)')),
              DropdownMenuItem(value: 'precio', child: Text('Precio')),
              DropdownMenuItem(value: 'popularidad', child: Text('Popularidad')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => sortOption = value);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBannerCarousel() {
    return SizedBox(
      height: 180,
      child: PageView.builder(
        itemCount: banners.length,
        itemBuilder: (context, index) {
          final banner = banners[index];
          return GestureDetector(
            onTap: () => context.push('/home?filter=${banner.filter}&order=$sortOption'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(banner.imagePath, fit: BoxFit.cover),
            ),
          );
        },
      ),
    );
  }
}

class _BannerItem {
  final String imagePath;
  final String label;
  final String filter;

  const _BannerItem({
    required this.imagePath,
    required this.label,
    required this.filter,
  });
}

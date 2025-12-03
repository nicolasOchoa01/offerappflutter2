import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/src/application/auth/auth_notifier.dart';
import 'package:myapp/src/application/main/main_notifier.dart';
import 'package:myapp/src/presentation/widgets/custom_header.dart';
import 'package:myapp/src/presentation/widgets/post_card.dart';
import 'package:provider/provider.dart';
import 'package:myapp/src/presentation/widgets/side_menu.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mainNotifier = context.read<MainNotifier?>();
      _scrollController.addListener(() {

        if (_scrollController.position.maxScrollExtent ==
            _scrollController.position.pixels) {
          mainNotifier?.loadMorePosts();
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final mainNotifier = context.watch<MainNotifier?>();
    // Read the AuthNotifier to perform actions like logging out.
    final authNotifier = context.read<AuthNotifier>();

    // This should ideally not happen due to the router redirect, but it's a safe fallback.
    if (mainNotifier == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: CustomHeader(
          username: mainNotifier.user.username,
          query: mainNotifier.searchQuery,
          onQueryChange: mainNotifier.updateSearchQuery, // Directly use the method from the notifier
          onProfileClick: () => context.go('/profile'),
          onSessionClicked: () => authNotifier.logout(), // Use the correct notifier and method
        ),
      ),
      drawer: const SideMenu(), // ← Sidebar integrado
      body: Column(
        children: [
          Padding(padding: const EdgeInsetsGeometry.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
                // Botón ORDENAR POR
                _buildFilterButton(
                context,
                label: 'ORDENAR POR',
                icon: Icons.sort,
                onTap: () => _showSortOptions(context, mainNotifier), // Lógica para el modal
                ),

                const SizedBox(width: 20),

                // Botón FILTRAR
                _buildFilterButton(
                context,
                label: 'FILTRAR',
                icon: Icons.filter_list,
                onTap: () => _showFilterOptions(context, mainNotifier), // Lógica para el modal
                ),
              ],
            ),
          ),

          const Divider(height: 1), // Separador visual

          // Sección 2: Lista de Posts (Expandida para ocupar el resto del espacio)
          Expanded(
              child: RefreshIndicator(
              onRefresh: () => Future.sync(mainNotifier.refreshPosts),
              child: ListView.builder(
              controller: _scrollController,
              itemCount: mainNotifier.posts.length + 1,
              itemBuilder: (context, index) {

                    if (index == mainNotifier.posts.length) {
                    if (mainNotifier.isLoading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (mainNotifier.posts.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Text('No se encontraron ofertas. ¡Intenta con otra búsqueda!'),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }

                  // Build the regular PostCard
                  final post = mainNotifier.posts[index];
                  final isFavorite = mainNotifier.user.favorites.contains(post.id);
  
                  return PostCard(
                    post: post,
                    isFavorite: isFavorite,
                    onToggleFavorite: () => mainNotifier.toggleFavorite(post.id),
                    onClick: () {
                  context.push('/post/${post.id}', extra: post);
                },
               );
              },
            ),
          ),
        ),
        ],
      ),
    );
  }

  // ------------------------------------------
  // WIDGETS DE AYUDA (Fuera del método build)
  // ----
Widget _buildFilterButton(BuildContext context, {required String label, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Lógica de Modal (Placeholder para Ordenar Por)
  void _showSortOptions(BuildContext context, MainNotifier mainNotifier) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Ordenar por',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              title: const Text('Más Recientes'),
              onTap: () {
                // Suponemos que tienes un método para ordenar en MainNotifier
                // mainNotifier.setSortOption('timestamp_desc'); 
                Navigator.pop(context);
                mainNotifier.refreshPosts(); 
              },
            ),
            ListTile(
              title: const Text('Precio Más Bajo'),
              onTap: () {
                // Suponemos que tienes un método para ordenar en MainNotifier
                // mainNotifier.setSortOption('price_asc');
                Navigator.pop(context);
                mainNotifier.refreshPosts();
              },
            ),
            // Puedes añadir más opciones aquí...
          ],
        );
      },
    );
  }

  // Lógica de Modal (Placeholder para Filtrar por Categoría/Estado)
  void _showFilterOptions(BuildContext context, MainNotifier mainNotifier) {
     showModalBottomSheet(
      context: context,
      builder: (context) {
        // En una aplicación real, los filtros complejos se harían en otra pantalla (context.push)
        return Container(
          height: 300, // Altura fija
          padding: const EdgeInsets.all(16.0),
          child: const Center(
            child: Text('Aquí se abriría el formulario de Filtros (Categoría, Ubicación, etc.)'),
          ),
        );
      },
    );
  }
}
/*
        onRefresh: () => Future.sync(mainNotifier.refreshPosts), // Use the notifier's refresh method
        child: ListView.builder(
          controller: _scrollController,

          itemCount: mainNotifier.posts.length + 1,
          itemBuilder: (context, index) {

            if (index == mainNotifier.posts.length) {
              if (mainNotifier.isLoading) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (mainNotifier.posts.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text('No se encontraron ofertas. ¡Intenta con otra búsqueda!'),
                  ),
                );
              }

              return const SizedBox.shrink();
            }

            // Build the regular PostCard
            final post = mainNotifier.posts[index];
            final isFavorite = mainNotifier.user.favorites.contains(post.id);
            
            return PostCard(
              post: post,
              isFavorite: isFavorite,
              onToggleFavorite: () => mainNotifier.toggleFavorite(post.id),
              onClick: () {
                context.push('/post/${post.id}', extra: post);
              },
            );
          },
        ),
      ),
    );
  }
}
*/
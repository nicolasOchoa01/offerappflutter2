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

    final authNotifier = context.read<AuthNotifier>();



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

          onQueryChange: mainNotifier.updateSearchQuery,

          onProfileClick: () => context.go('/profile'),

          onSessionClicked: () => authNotifier.logout(),

        ),

      ),

      // ⚠️ IMPORTANTE: SideMenu debe poder acceder al MainNotifier

      drawer: SideMenu(mainNotifier: mainNotifier),

      body: Column(

        children: [

          // ----------------------------------------------------

          // Sección 1: Botones Ordenar/Filtrar

          // ----------------------------------------------------

          Padding(

            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),

            child: Row(

              children: [

                // Botón ORDENAR POR

                _buildFilterButton(

                  context,

                  label: 'ORDENAR POR',

                  icon: Icons.sort,

                  onTap: () => _showSortOptions(context, mainNotifier),

                ),

               

                const SizedBox(width: 20),

               

                // Botón FILTRAR (Por defecto se usa el SideMenu para filtrar por categoría,

                // pero si quieres más filtros, puedes usar este modal).

                _buildFilterButton(

                  context,

                  label: 'FILTRAR',

                  icon: Icons.filter_list,

                  onTap: () => _showActiveFilter(context, mainNotifier), // Muestra el filtro activo

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

                      return Center(

                        child: Padding(

                          padding: const EdgeInsets.all(20.0),

                          child: Text(

                            mainNotifier.activeCategory == null || mainNotifier.activeCategory == 'Todos'

                              ? 'No se encontraron ofertas. ¡Intenta con otra búsqueda!'

                              : 'No se encontraron ofertas en "${mainNotifier.activeCategory}".'

                          ),

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

  // ------------------------------------------



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



  // Lógica de Modal para Ordenar Por

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

              trailing: mainNotifier.orderByField == 'timestamp' && mainNotifier.descending

                ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,

              onTap: () {

                mainNotifier.setSortOption('timestamp', true);

                Navigator.pop(context);

              },

            ),

            ListTile(

              title: const Text('Precio Más Bajo'),

              trailing: mainNotifier.orderByField == 'discountPrice' && !mainNotifier.descending

                ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,

              onTap: () {

                mainNotifier.setSortOption('discountPrice', false);

                Navigator.pop(context);

              },

            ),

             ListTile(

              title: const Text('Precio Más Alto'),

              trailing: mainNotifier.orderByField == 'discountPrice' && mainNotifier.descending

                ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,

              onTap: () {

                mainNotifier.setSortOption('discountPrice', true);

                Navigator.pop(context);

              },

            ),

          ],

        );

      },

    );

  }

 

  // Lógica de Modal para mostrar el Filtro Activo

  void _showActiveFilter(BuildContext context, MainNotifier mainNotifier) {

    final activeCategory = mainNotifier.activeCategory ?? 'Todos';

    showModalBottomSheet(

      context: context,

      builder: (context) {

        return Column(

          mainAxisSize: MainAxisSize.min,

          children: [

            ListTile(

              title: const Text('Filtro Actual'),

              subtitle: Text(activeCategory),

              trailing: activeCategory != 'Todos' ? TextButton(

                onPressed: () {

                  mainNotifier.setCategoryFilter('Todos');

                  Navigator.pop(context);

                },

                child: const Text('LIMPIAR FILTRO'),

              ) : null,

            ),

            ListTile(

              title: const Text('Cambiar Categoría (Abrir Menú Lateral)'),

              onTap: () {

                Navigator.pop(context);

                Scaffold.of(context).openDrawer(); // Abre el menú lateral

              },

            ),

          ],

        );

      },

    );

  }

}
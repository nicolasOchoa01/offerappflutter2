import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
        if (_scrollController.position.maxScrollExtent == _scrollController.position.pixels) {
          mainNotifier?.loadMorePosts();
        }
      });
      // Initial load
      mainNotifier?.refreshPosts();
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
          onProfileClick: () => context.go('/profile/${mainNotifier.user.id}'),
          onSessionClicked: mainNotifier.logout,
        ),
      ),
      drawer: const SideMenu(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _buildSortButton(
                  context,
                  label: mainNotifier.currentSortOption, // DYNAMIC LABEL
                  icon: Icons.sort,
                  onTap: () => _showSortOptions(context, mainNotifier),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => mainNotifier.refreshPosts(),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: mainNotifier.posts.length + (mainNotifier.isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == mainNotifier.posts.length) {
                    if (mainNotifier.posts.isEmpty && !mainNotifier.isLoading) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: Text('No se encontraron ofertas. ¡Intenta con otra búsqueda!'),
                        ),
                      );
                    }
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

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

  Widget _buildSortButton(
      BuildContext context, {required String label, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(), // Display current sort option
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

  void _showSortOptions(BuildContext context, MainNotifier mainNotifier) {
    // Updated map without score options
    final sortOptions = {
      'Fecha (más reciente)': 'timestamp_desc',
      'Precio (mayor a menor)': 'price_desc',
      'Precio (menor a mayor)': 'price_asc',
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Ordenar por',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              ...sortOptions.entries.map((entry) {
                final isSelected = mainNotifier.currentSortOption == entry.key;
                return ListTile(
                  title: Text(
                    entry.key,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Theme.of(context).colorScheme.primary : null,
                    ),
                  ),
                  trailing: isSelected ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
                  onTap: () {
                    mainNotifier.setSortOption(entry.key);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

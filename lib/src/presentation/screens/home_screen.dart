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
      body: RefreshIndicator(
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

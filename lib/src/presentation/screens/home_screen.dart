import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/src/data/repositories/auth_repository.dart';
import 'package:myapp/src/data/repositories/post_repository.dart';
import 'package:myapp/src/domain/entities/post.dart';
import 'package:myapp/src/domain/entities/user.dart';
import 'package:myapp/src/presentation/widgets/custom_header.dart';
import 'package:myapp/src/presentation/widgets/post_card.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final postRepository = context.watch<PostRepository>();
    final authRepo = context.watch<AuthRepository>();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: StreamBuilder<User?>(
          stream: authRepo.userChanges,
          builder: (context, snapshot) {
            final user = snapshot.data;
            if (user == null) {
              // This case should be handled by redirects, but as a fallback:
              return AppBar(title: const Text('OfferApp'));
            }
            return CustomHeader(
              username: user.username,
              query: _searchQuery,
              onQueryChange: (query) => setState(() => _searchQuery = query),
              onProfileClick: () => context.go('/profile'),
              onSessionClicked: () => authRepo.signOut(),
            );
          },
        ),
      ),
      body: StreamBuilder<List<Post>>(
        stream: postRepository.getAllPostsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final allPosts = snapshot.data ?? [];
          final filteredPosts = allPosts.where((post) {
            final query = _searchQuery.toLowerCase();
            return post.description.toLowerCase().contains(query) ||
                   post.category.toLowerCase().contains(query) ||
                   post.store.toLowerCase().contains(query) ||
                   post.user!.username.toLowerCase().contains(query);
          }).toList();

          if (filteredPosts.isEmpty) {
            return const Center(child: Text('No se encontraron ofertas.'));
          }

          return ListView.builder(
            itemCount: filteredPosts.length,
            itemBuilder: (context, index) {
              final post = filteredPosts[index];
              return PostCard(
                post: post,
                onClick: () {
                  context.push('/post/${post.id}', extra: post);
                },
              );
            },
          );
        },
      ),
    );
  }
}

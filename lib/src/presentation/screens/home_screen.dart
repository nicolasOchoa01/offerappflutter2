import 'package:flutter/material.dart';
import 'package:myapp/src/data/repositories/post_repository.dart';
import 'package:myapp/src/domain/entities/post.dart';
import 'package:myapp/src/presentation/screens/post_detail_screen.dart';
import 'package:myapp/src/presentation/widgets/post_card.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  final String searchQuery;

  const HomeScreen({super.key, this.searchQuery = ''});

  @override
  Widget build(BuildContext context) {
    final postRepository = Provider.of<PostRepository>(context, listen: false);

    return StreamBuilder<List<Post>>(
      stream: postRepository.getAllPostsStream(), // We get all posts first
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar las ofertas: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'No hay ofertas publicadas todavía. \n¡Sé el primero!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          );
        }

        // Filter posts based on search query
        final allPosts = snapshot.data!;
        final filteredPosts = searchQuery.isEmpty
            ? allPosts
            : allPosts.where((post) =>
                post.description.toLowerCase().contains(searchQuery.toLowerCase()) ||
                post.category.toLowerCase().contains(searchQuery.toLowerCase()) ||
                post.store.toLowerCase().contains(searchQuery.toLowerCase()) ||
                post.user!.username.toLowerCase().contains(searchQuery.toLowerCase()) 
              ).toList();

        if (filteredPosts.isEmpty) {
          return const Center(
            child: Text(
              'No se encontraron ofertas con ese criterio.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          itemCount: filteredPosts.length,
          itemBuilder: (context, index) {
            final post = filteredPosts[index];
            return PostCard(
              post: post,
              onClick: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PostDetailScreen(post: post),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

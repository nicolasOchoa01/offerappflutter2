import 'package:flutter/material.dart';
import 'package:myapp/src/data/repositories/post_repository.dart';
import 'package:myapp/src/domain/entities/post.dart';
import 'package:myapp/src/presentation/widgets/post_card.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtenemos la instancia del repositorio a través de Provider.
    final postRepository = Provider.of<PostRepository>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ofertas'),
        // Aquí puedes añadir acciones como un filtro o un botón de búsqueda más adelante
      ),
      body: StreamBuilder<List<Post>>(
        // CONECTADO: Ahora el stream apunta al método del repositorio
        stream: postRepository.getPostsStream(),
        builder: (context, snapshot) {
          // El resto del widget maneja los diferentes estados del stream
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar las ofertas: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No hay ofertas publicadas todavía. ¡Sé el primero!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          final posts = snapshot.data!;

          // Usamos un ListView para mostrar las tarjetas
          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return PostCard(
                post: post,
                onClick: () {
                  // TODO: Implementar la navegación a la pantalla de detalles de la publicación.
                  // Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(postId: post.id)));
                  print("Tocado el post con ID: ${post.id}");
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implementar la navegación a la pantalla para crear una nueva publicación.
          // Navigator.push(context, MaterialPageRoute(builder: (_) => CreatePostScreen()));
        },
        child: const Icon(Icons.add),
        tooltip: 'Añadir nueva oferta',
      ),
    );
  }
}

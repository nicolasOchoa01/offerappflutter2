import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:myapp/src/domain/entities/post.dart';
import 'package:myapp/src/domain/entities/user.dart';
import 'package:myapp/src/data/repositories/auth_repository.dart';
import 'package:myapp/src/data/repositories/user_repository.dart';
import 'package:provider/provider.dart';

@immutable
class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onClick;

  const PostCard({
    super.key,
    required this.post,
    required this.onClick,
  });

  @override
  Widget build(BuildContext context) {
    final score = post.scores.fold<int>(0, (total, item) => total + item.value);
    final Color scoreColor;
    if (score > 0) {
      scoreColor = const Color(0xFF4CAF50); // Verde
    } else if (score < 0) {
      scoreColor = Theme.of(context).colorScheme.error;
    } else {
      scoreColor = Colors.grey;
    }

    final String valuation;
    if (score > 10) {
      valuation = "Ofertón";
    } else if (score > 5) {
      valuation = "Buena oferta";
    } else if (score >= -5) {
      valuation = "Oferta";
    } else if (score >= -10) {
      valuation = "Mala oferta";
    } else {
      valuation = "Estafa";
    }

    final bool isNew = post.timestamp != null &&
        DateTime.now().difference(post.timestamp!.toDate()).inHours < 24;

    final Color cardBackgroundColor;
     if (post.status.toLowerCase() == "vencida") {
      cardBackgroundColor = Theme.of(context).colorScheme.error.withAlpha(25); // ~10% opacity
    } else if (post.status.toLowerCase() == "activa") {
      cardBackgroundColor = const Color(0xFF4CAF50).withAlpha(25); // ~10% opacity
    } else {
      cardBackgroundColor = Theme.of(context).colorScheme.primary.withAlpha(12); // ~5% opacity
    }
    
    return StreamBuilder<User?>(
      stream: context.watch<AuthRepository>().userChanges, // Correct: Stream is in AuthRepository
      builder: (context, snapshot) {
        final currentUser = snapshot.data;
        final bool isFavorite = currentUser?.favorites.contains(post.id) ?? false;
        final userRepo = context.read<UserRepository>();

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          color: cardBackgroundColor,
          elevation: 2.0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onClick,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Imagen
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: CachedNetworkImage(
                      imageUrl: post.imageUrl.replaceFirst("http://", "https://"),
                      width: 88.0,
                      height: 120.0,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[300],
                        child: const Center(child: Icon(Icons.image, color: Colors.grey)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300],
                        child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  // Contenido principal
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.description,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8.0),
                        // Fila de estado, valoración y etiqueta "NEW"
                        Row(
                          children: [
                            Text(
                              post.status.toUpperCase(),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: post.status.toLowerCase() == "activa"
                                        ? const Color(0xFF4CAF50)
                                        : Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(width: 8.0),
                            Text(
                              valuation,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            if (isNew) ...[
                              const SizedBox(width: 8.0),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                                child: Text(
                                  "NEW",
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          post.store,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                        ),
                        const SizedBox(height: 8.0),
                        // Precios
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              "${post.discountPrice.toStringAsFixed(2)} €",
                               style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                               ),
                            ),
                            const SizedBox(width: 8.0),
                            Text(
                              "${post.price.toStringAsFixed(2)} €",
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Puntuación y favorito
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        score.toString(),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: scoreColor,
                            ),
                      ),
                      IconButton(
                        icon: Icon(isFavorite ? Icons.star : Icons.star_border, color: isFavorite ? Colors.amber : Colors.grey, size: 32.0),
                        tooltip: 'Marcar como favorito',
                        onPressed: () {
                          if (currentUser != null) {
                            userRepo.toggleFavorite(currentUser.id, post.id, isFavorite);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:myapp/src/domain/entities/post.dart';
import 'dart:math' as math;

@immutable
class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onClick;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  const PostCard({
    super.key,
    required this.post,
    required this.onClick,
    required this.isFavorite,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = post.scores.fold<int>(0, (total, item) => total + item.value);

    final Color scoreColor;
    if (score > 0) {
      scoreColor = const Color(0xFF4CAF50); // Green for positive score
    } else if (score < 0) {
      scoreColor = theme.colorScheme.error; // Error color for negative score
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
      cardBackgroundColor = theme.colorScheme.error.withOpacity(0.1);
    } else if (post.status.toLowerCase() == "activa") {
      cardBackgroundColor = const Color(0xFF4CAF50).withOpacity(0.1);
    } else {
      cardBackgroundColor = theme.colorScheme.primary.withOpacity(0.05);
    }
    
    final favoriteColor = isFavorite ? const Color(0xFFFFC107) : Colors.grey;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      color: cardBackgroundColor,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onClick,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: CachedNetworkImage(
                    imageUrl: post.imageUrl.replaceFirst("http://", "https://"),
                    width: 88.0,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[200]),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 16.0),
                // Main Content Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.description,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8.0),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                           Text(
                            post.status.toUpperCase(),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: post.status.toLowerCase() == "activa"
                                  ? const Color(0xFF4CAF50)
                                  : theme.colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(valuation, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                          if(isNew)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                                child: Text(
                                  "NEW",
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                              ),
                            )
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        post.location,
                        style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(), // Pushes prices to the bottom
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            "\$${post.discountPrice.toStringAsFixed(2)}",
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w900, // ExtraBold equivalent
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Text(
                            "\$${post.price.toStringAsFixed(2)}",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.grey,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8.0),
                // Score and Favorite Column
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      score.toString(),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.star, color: favoriteColor, size: 32.0),
                      tooltip: 'Marcar como favorito',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: onToggleFavorite,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

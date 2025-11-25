import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:myapp/src/application/main/main_notifier.dart';
import 'package:myapp/src/domain/entities/post.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class PostDetailScreen extends StatefulWidget {
  // The post is passed, but we will primarily rely on the notifier for the most up-to-date state.
  final Post post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Use a post-frame callback to safely interact with the notifier.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Tell the notifier which post is currently being viewed.
      // This triggers loading comments for this post.
      context.read<MainNotifier>().selectPost(widget.post.id);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    // Clean up by deselecting the post, which cancels comment streams.
    // Use a post-frame callback as it's good practice when interacting with notifiers in dispose.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Check if the notifier is still available before using it.
      if (mounted) {
        context.read<MainNotifier>().selectPost(null);
      }
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mainNotifier = context.watch<MainNotifier>();
    // Get the most up-to-date version of the post from the notifier.
    final post = mainNotifier.selectedPost;

    // If the post is not found (e.g., during a state transition), show a loading indicator.
    if (post == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentUser = mainNotifier.user;
    final isFavorite = currentUser.favorites.contains(post.id);
    final sdf = DateFormat('dd MMM yyyy, hh:mm a', 'es_ES');

    return Scaffold(
      appBar: AppBar(
        title: Text(post.description),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.red : null),
            onPressed: () => mainNotifier.toggleFavorite(post.id),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // Corrected to use the static Share.share method, which is the correct API.
              Share.share(
                  '¡Mira esta oferta que encontré en OfferApp! ${post.description} por solo ${post.discountPrice}€ en ${post.store}',
                  subject: 'Oferta increíble: ${post.description}');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPostHeader(context, post),
            const SizedBox(height: 16),
            _buildPostImage(post),
            const SizedBox(height: 16),
            _buildPricingAndVoting(context, mainNotifier, post),
            const SizedBox(height: 8),
            if (post.timestamp != null)
              Text(
                'Publicado: ${sdf.format(post.timestamp!.toDate())}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const Divider(height: 32),
            _buildMap(post),
            const Divider(height: 32),
            _buildCommentsSection(context, mainNotifier, post),
          ],
        ),
      ),
    );
  }

  Widget _buildPostHeader(BuildContext context, Post post) {
    return InkWell(
      onTap: () => context.push('/profile/${post.user!.id}'),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: post.user?.profileImageUrl != null
                ? CachedNetworkImageProvider(post.user!.profileImageUrl!)
                : null,
            child: post.user?.profileImageUrl == null
                ? const Icon(Icons.person, size: 24)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post.user?.username ?? 'Usuario Anónimo',
                    style: Theme.of(context).textTheme.titleMedium),
                Text(post.store, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostImage(Post post) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.0),
      child: CachedNetworkImage(
        imageUrl: post.imageUrl,
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => const Icon(Icons.error),
        fit: BoxFit.cover,
        width: double.infinity,
        height: 250,
      ),
    );
  }

  Widget _buildPricingAndVoting(BuildContext context, MainNotifier notifier, Post post) {
    // Corrected lint warning by renaming 'sum' to 'total'
    final totalScore =
        post.scores.fold<int>(0, (total, item) => total + item.value);
    final currentUser = notifier.user;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${post.discountPrice.toStringAsFixed(2)}€',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.green)),
            Text('${post.price.toStringAsFixed(2)}€',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    decoration: TextDecoration.lineThrough)),
          ],
        ),
        Row(
          children: [
            IconButton(
                icon: const Icon(Icons.thumb_up),
                onPressed: () => notifier.voteOnPost(post.id, 1),
                color: post.scores
                        .any((s) => s.userId == currentUser.id && s.value == 1)
                    ? Colors.green
                    : null),
            Text(totalScore.toString(),
                style: Theme.of(context).textTheme.titleLarge),
            IconButton(
                icon: const Icon(Icons.thumb_down),
                onPressed: () => notifier.voteOnPost(post.id, -1),
                color: post.scores
                        .any((s) => s.userId == currentUser.id && s.value == -1)
                    ? Colors.red
                    : null),
          ],
        )
      ],
    );
  }

  Widget _buildMap(Post post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ubicación', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(post.latitude, post.longitude),
              zoom: 15,
            ),
            markers: {
              Marker(
                markerId: MarkerId(post.id),
                position: LatLng(post.latitude, post.longitude),
              ),
            },
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.directions),
          label: const Text('Cómo llegar'),
          onPressed: () async {
            final uri = Uri.parse(
                'https://www.google.com/maps/dir/?api=1&destination=${post.latitude},${post.longitude}');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            }
          },
          style:
              ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
        ),
      ],
    );
  }

  Widget _buildCommentsSection(BuildContext context, MainNotifier notifier, Post post) {
    final comments = notifier.comments; // Get comments from the notifier

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Comentarios', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: TextField(
                    controller: _commentController,
                    decoration:
                        const InputDecoration(hintText: 'Añadir un comentario...'))),
            IconButton(
                icon: const Icon(Icons.send),
                onPressed: () {
                  if (_commentController.text.isNotEmpty) {
                    notifier.addComment(post.id, _commentController.text);
                    _commentController.clear();
                  }
                }),
          ],
        ),
        const SizedBox(height: 16),
        if (comments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(child: Text('No hay comentarios todavía.')),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: comments.length,
            itemBuilder: (context, index) {
              final comment = comments[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: comment.user?.profileImageUrl != null
                      ? CachedNetworkImageProvider(comment.user!.profileImageUrl!)
                      : null,
                  child: comment.user?.profileImageUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                title: Text(comment.user?.username ?? 'Anónimo'),
                subtitle: Text(comment.text),
              );
            },
          ),
      ],
    );
  }
}

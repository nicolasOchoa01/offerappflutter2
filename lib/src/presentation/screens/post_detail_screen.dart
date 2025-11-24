import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:myapp/src/data/repositories/auth_repository.dart';
import 'package:myapp/src/data/repositories/post_repository.dart';
import 'package:myapp/src/data/repositories/user_repository.dart';
import 'package:myapp/src/domain/entities/comment.dart';
import 'package:myapp/src/domain/entities/post.dart';
import 'package:myapp/src/domain/entities/score.dart';
import 'package:myapp/src/domain/entities/user.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Post _currentPost;
  final TextEditingController _commentController = TextEditingController();
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
    _loadCurrentUser();
  }

  void _loadCurrentUser() {
     context.read<AuthRepository>().userChanges.listen((user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
      }
    });
  }

  void _addComment() async {
    if (_commentController.text.isNotEmpty && _currentUser != null) {
      final postRepo = context.read<PostRepository>();
      final newComment = Comment(
        id: '', // Firestore will generate this
        postId: _currentPost.id,
        userId: _currentUser!.id,
        user: _currentUser,
        text: _commentController.text,
        timestamp: Timestamp.now(), // Use Firestore Timestamp
      );
      await postRepo.addCommentToPost(postId: _currentPost.id, comment: newComment);
      _commentController.clear();
    }
  }

  void _toggleFavorite() async {
    if (_currentUser != null) {
      final userRepo = context.read<UserRepository>();
      final isCurrentlyFavorited = _currentUser!.favorites.contains(_currentPost.id);
      
      // Optimistic UI update
      setState(() {
        if (isCurrentlyFavorited) {
          _currentUser!.favorites.remove(_currentPost.id);
        } else {
          _currentUser!.favorites.add(_currentPost.id);
        }
      });

      await userRepo.toggleFavorite(_currentUser!.id, _currentPost.id, isCurrentlyFavorited);
    }
  }

    void _vote(int value) async {
    if (_currentUser == null) return;
    final postRepo = context.read<PostRepository>();

    await postRepo.updatePostScore(
      postId: _currentPost.id, 
      userId: _currentUser!.id, 
      value: value
    );

    // Fetch the updated post to reflect score changes
    final updatedPost = await postRepo.getPostFuture(_currentPost.id);
    if (updatedPost != null && mounted) {
      setState(() {
        _currentPost = updatedPost;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = _currentUser?.favorites.contains(_currentPost.id) ?? false;
    final sdf = DateFormat('dd MMM yyyy, hh:mm a', 'es_ES');

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPost.description),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : null),
            onPressed: _toggleFavorite,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
                Share.share(
                  '¡Mira esta oferta que encontré en OfferApp! ${_currentPost.description} por solo ${_currentPost.discountPrice}€ en ${_currentPost.store}',
                   subject: 'Oferta increíble: ${_currentPost.description}'
                );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPostHeader(),
            const SizedBox(height: 16),
            _buildPostImage(),
            const SizedBox(height: 16),
            _buildPricingAndVoting(),
            const SizedBox(height: 8),
            if (_currentPost.timestamp != null)
              Text(
                'Publicado: ${sdf.format(_currentPost.timestamp!.toDate())}',
                 style: Theme.of(context).textTheme.bodySmall,
              ),
            const Divider(height: 32),
            _buildMap(),
            const Divider(height: 32),
            _buildCommentsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildPostHeader() {
    return InkWell(
      onTap: () => context.push('/profile/${_currentPost.user!.id}'),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: _currentPost.user?.profileImageUrl != null
                ? CachedNetworkImageProvider(_currentPost.user!.profileImageUrl!)
                : null,
            child: _currentPost.user?.profileImageUrl == null ? const Icon(Icons.person, size: 24) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_currentPost.user?.username ?? 'Usuario Anónimo', style: Theme.of(context).textTheme.titleMedium),
                Text(_currentPost.store, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.0),
      child: CachedNetworkImage(
        imageUrl: _currentPost.imageUrl,
        placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => const Icon(Icons.error),
        fit: BoxFit.cover,
        width: double.infinity,
        height: 250,
      ),
    );
  }

  Widget _buildPricingAndVoting() {
    final totalScore = _currentPost.scores.fold<int>(0, (sum, item) => sum + item.value);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_currentPost.discountPrice.toStringAsFixed(2)}€', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.green)),
            Text('${_currentPost.price.toStringAsFixed(2)}€', style: Theme.of(context).textTheme.bodyLarge?.copyWith(decoration: TextDecoration.lineThrough)),
          ],
        ),
        Row(
          children: [
            IconButton(icon: const Icon(Icons.thumb_up), onPressed: () => _vote(1), color: _currentPost.scores.any((s) => s.userId == _currentUser?.id && s.value == 1) ? Colors.green : null),
            Text(totalScore.toString(), style: Theme.of(context).textTheme.titleLarge),
            IconButton(icon: const Icon(Icons.thumb_down), onPressed: () => _vote(-1), color: _currentPost.scores.any((s) => s.userId == _currentUser?.id && s.value == -1) ? Colors.red : null),
          ],
        )
      ],
    );
  }

  Widget _buildMap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ubicación', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(_currentPost.latitude, _currentPost.longitude),
              zoom: 15,
            ),
            markers: {
              Marker(
                markerId: MarkerId(_currentPost.id),
                position: LatLng(_currentPost.latitude, _currentPost.longitude),
              ),
            },
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.directions),
          label: const Text('Cómo llegar'),
          onPressed: () async {
            final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${_currentPost.latitude},${_currentPost.longitude}');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            }
          },
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
        ),
      ],
    );
  }

  Widget _buildCommentsSection() {
    final postRepo = context.read<PostRepository>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Comentarios', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        if (_currentUser != null)
          Row(
            children: [
              Expanded(child: TextField(controller: _commentController, decoration: const InputDecoration(hintText: 'Añadir un comentario...'))),
              IconButton(icon: const Icon(Icons.send), onPressed: _addComment),
            ],
          ),
        const SizedBox(height: 16),
        StreamBuilder<List<Comment>>(
          stream: postRepo.getCommentsForPost(_currentPost.id),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Text('Error al cargar los comentarios.');
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final comments = snapshot.data!;
            if (comments.isEmpty) return const Text('No hay comentarios todavía.');

            return ListView.builder(
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
                     child: comment.user?.profileImageUrl == null ? const Icon(Icons.person) : null,
                  ),
                  title: Text(comment.user?.username ?? 'Anónimo'),
                  subtitle: Text(comment.text),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

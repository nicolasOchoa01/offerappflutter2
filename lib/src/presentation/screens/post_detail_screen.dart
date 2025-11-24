import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:myapp/src/data/repositories/auth_repository.dart';
import 'package:myapp/src/data/repositories/post_repository.dart';
import 'package:myapp/src/data/repositories/user_repository.dart';
import 'package:myapp/src/domain/entities/comment.dart';
import 'package:myapp/src/domain/entities/post.dart';
import 'package:myapp/src/domain/entities/user.dart';
import 'package:myapp/src/presentation/screens/profile_screen.dart';
import 'package:myapp/src/presentation/widgets/custom_header.dart';
import 'package:provider/provider.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  bool _isSendingComment = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment(User currentUser) async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() {
      _isSendingComment = true;
    });

    final postRepo = context.read<PostRepository>();
    try {
      await postRepo.addComment(
        postId: widget.post.id,
        userId: currentUser.id,
        text: _commentController.text.trim(),
        user: currentUser,
      );
      _commentController.clear();
    } catch (e) {
      // Handle error appropriately
    } finally {
      if (mounted) {
        setState(() {
          _isSendingComment = false;
        });
      }
    }
  }

  Future<void> _openMap(double latitude, double longitude) async {
    final Uri googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl);
    } else {
      throw 'Could not open the map.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authRepo = context.watch<AuthRepository>();
    final userRepo = context.watch<UserRepository>();
    final postRepo = context.watch<PostRepository>();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: StreamBuilder<User?>(
          stream: authRepo.userChanges,
          builder: (context, snapshot) {
            final currentUser = snapshot.data;
            return CustomHeader(
              username: currentUser?.username ?? 'Anónimo',
              title: 'Publicación',
              onBackClicked: () => Navigator.of(context).pop(),
              onProfileClick: () {
                if (currentUser != null) {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(userId: currentUser.id)));
                }
              },
              onSessionClicked: () {
                authRepo.signOut();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            );
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Post content
              Text(widget.post.description, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (widget.post.user != null) {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(userId: widget.post.user!.id)));
                      }
                    },
                    child: CircleAvatar(
                      radius: 12,
                      backgroundImage: widget.post.user?.profileImageUrl != null
                          ? NetworkImage(widget.post.user!.profileImageUrl!)
                          : null,
                      child: widget.post.user?.profileImageUrl == null ? const Icon(Icons.person, size: 12) : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(widget.post.user?.username ?? 'Anónimo', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(widget.post.imageUrl, fit: BoxFit.cover, width: double.infinity, height: 300),
              ),
              const SizedBox(height: 16),
              // Action Buttons
              StreamBuilder<User?>(
                stream: authRepo.userChanges,
                builder: (context, snapshot) {
                  final currentUser = snapshot.data;
                  if (currentUser == null) return const SizedBox.shrink();

                  final isFavorited = currentUser.favorites.contains(widget.post.id);

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(
                        icon: Icon(
                          isFavorited ? Icons.favorite : Icons.favorite_border,
                          color: isFavorited ? Colors.red : null,
                        ),
                        onPressed: () {
                          userRepo.toggleFavorite(currentUser.id, widget.post.id, isFavorited);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: () {
                          Share.share('Mira esta increíble oferta: ${widget.post.description}');
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.location_on),
                        onPressed: () => _openMap(widget.post.latitude, widget.post.longitude),
                      ),
                    ],
                  );
                },
              ),
              const Divider(height: 32),
              // Comments section
              Text('Comentarios', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              StreamBuilder<List<Comment>>(
                stream: postRepo.getCommentsStream(widget.post.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final comments = snapshot.data ?? [];
                  if (comments.isEmpty) {
                    return const Center(child: Text('No hay comentarios todavía.'));
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: comments.length,
                    itemBuilder: (context, index) {
                      final comment = comments[index];
                      return _buildCommentItem(comment);
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              // Add comment
              StreamBuilder<User?>(
                stream: authRepo.userChanges,
                builder: (context, snapshot) {
                  final currentUser = snapshot.data;
                  if (currentUser == null) return const SizedBox.shrink();

                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: const InputDecoration(
                            hintText: 'Añade un comentario...',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _sendComment(currentUser),
                        ),
                      ),
                      IconButton(
                        icon: _isSendingComment
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.send),
                        onPressed: _isSendingComment ? null : () => _sendComment(currentUser),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentItem(Comment comment) {
    final sdf = DateFormat('dd MMM yyyy, hh:mm a', 'es_ES');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              if (comment.user != null) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen(userId: comment.user!.id)));
              }
            },
            child: CircleAvatar(
              radius: 20,
              backgroundImage: comment.user?.profileImageUrl != null ? NetworkImage(comment.user!.profileImageUrl!) : null,
              child: comment.user?.profileImageUrl == null ? const Icon(Icons.person) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comment.user?.username ?? 'Anónimo', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(comment.text, style: Theme.of(context).textTheme.bodyMedium),
                if (comment.timestamp != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      sdf.format(comment.timestamp!.toDate()),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

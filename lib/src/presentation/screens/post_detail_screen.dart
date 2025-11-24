import 'package:flutter/material.dart';
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

class PostDetailScreen extends StatefulWidget {
  final Post post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    final authRepo = context.read<AuthRepository>();
    if (authRepo.currentUser != null) {
      context
          .read<UserRepository>()
          .getUserStream(authRepo.currentUser!.uid)
          .listen((user) {
            if (mounted) {
              setState(() {
                _currentUser = user;
              });
            }
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    final postRepo = context.watch<PostRepository>();
    final userRepo = context.watch<UserRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de la Oferta'),
        actions: [
          if (_currentUser?.id == widget.post.userId)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _confirmDelete(context, postRepo),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPostHeader(),
              const SizedBox(height: 16),
              _buildPostImage(),
              const SizedBox(height: 16),
              _buildPostActions(userRepo),
              const SizedBox(height: 16),
              _buildPostDetails(),
              const SizedBox(height: 24),
              _buildCommentSection(postRepo),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, PostRepository postRepo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Borrado'),
        content: const Text(
          '¿Estás seguro de que quieres borrar esta publicación? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(ctx);
              final mainNavigator = Navigator.of(context);
              await postRepo.deletePost(widget.post.id);
              if (mounted) {
                navigator.pop();
                mainNavigator.pop();
              }
            },
            child: const Text('Borrar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildPostHeader() {
    final postUser = widget.post.user;
    if (postUser == null) return const SizedBox.shrink();

    return Row(
      children: [
        CircleAvatar(
          backgroundImage: postUser.profileImageUrl != null
              ? NetworkImage(postUser.profileImageUrl!)
              : null,
          child: postUser.profileImageUrl == null
              ? const Icon(Icons.person)
              : null,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              postUser.username,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (widget.post.timestamp != null)
              Text(
                DateFormat(
                  'dd MMM yyyy',
                  'es_ES',
                ).format(widget.post.timestamp!.toDate()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPostImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12.0),
      child: Image.network(
        widget.post.imageUrl,
        width: double.infinity,
        height: 250,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildPostActions(UserRepository userRepo) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ScoreButtons(post: widget.post, currentUser: _currentUser),
        Row(
          children: [
            if (_currentUser != null)
              IconButton(
                icon: Icon(
                  _currentUser!.favorites.contains(widget.post.id)
                      ? Icons.favorite
                      : Icons.favorite_border,
                ),
                onPressed: () =>
                    userRepo.toggleFavorite(_currentUser!.id, widget.post.id),
              ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                Share.share(
                  '¡Mira esta oferta en OfferApp! ${widget.post.description}',
                  subject: 'Oferta increíble',
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPostDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.post.description,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              '${widget.post.discountPrice.toStringAsFixed(2)} €',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Text(
              '${widget.post.price.toStringAsFixed(2)} €',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Chip(label: Text(widget.post.category)),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.store, size: 16),
            const SizedBox(width: 4),
            Text(widget.post.store),
          ],
        ),
      ],
    );
  }

  Widget _buildCommentSection(PostRepository postRepo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Comentarios', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (_currentUser != null)
          _CommentInputField(post: widget.post, currentUser: _currentUser!),
        StreamBuilder<List<Comment>>(
          stream: postRepo.getCommentsForPost(widget.post.id),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final comments = snapshot.data!;
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: comments.length,
              itemBuilder: (context, index) =>
                  _CommentItem(comment: comments[index]),
            );
          },
        ),
      ],
    );
  }
}

class _ScoreButtons extends StatelessWidget {
  final Post post;
  final User? currentUser;

  const _ScoreButtons({required this.post, this.currentUser});

  @override
  Widget build(BuildContext context) {
    final postRepo = context.read<PostRepository>();
    final currentVote = post.scores.firstWhere(
      (s) => s.userId == currentUser?.id,
      orElse: () => const Score(userId: '', value: 0),
    );

    return Row(
      children: [
        IconButton(
          icon: Icon(
            Icons.thumb_up,
            color: currentVote.value == 1 ? Colors.green : null,
          ),
          onPressed: () {
            if (currentUser != null) {
              postRepo.updatePostScore(
                postId: post.id,
                userId: currentUser!.id,
                value: 1,
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Debes iniciar sesión para votar.'),
                ),
              );
            }
          },
        ),
        Text(
          post.scores.fold<int>(0, (sum, item) => sum + item.value).toString(),
        ),
        IconButton(
          icon: Icon(
            Icons.thumb_down,
            color: currentVote.value == -1 ? Colors.red : null,
          ),
          onPressed: () {
            if (currentUser != null) {
              postRepo.updatePostScore(
                postId: post.id,
                userId: currentUser!.id,
                value: -1,
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Debes iniciar sesión para votar.'),
                ),
              );
            }
          },
        ),
      ],
    );
  }
}

class _CommentInputField extends StatefulWidget {
  final Post post;
  final User currentUser;

  const _CommentInputField({required this.post, required this.currentUser});

  @override
  State<_CommentInputField> createState() => _CommentInputFieldState();
}

class _CommentInputFieldState extends State<_CommentInputField> {
  final _commentController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final postRepo = context.read<PostRepository>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                hintText: 'Añade un comentario...',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () async {
              if (_commentController.text.isNotEmpty) {
                final newComment = Comment(
                  id: '',
                  userId: widget.currentUser.id,
                  text: _commentController.text,
                  user: widget.currentUser,
                  postId: widget.post.id,
                );
                await postRepo.addCommentToPost(
                  postId: widget.post.id,
                  comment: newComment,
                );
                _commentController.clear();
              }
            },
          ),
        ],
      ),
    );
  }
}

class _CommentItem extends StatelessWidget {
  final Comment comment;

  const _CommentItem({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: comment.user?.profileImageUrl != null
                ? NetworkImage(comment.user!.profileImageUrl!)
                : null,
            child: comment.user?.profileImageUrl == null
                ? const Icon(Icons.person, size: 18)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.user?.username ?? 'Anónimo',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  comment.text,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (comment.timestamp != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      DateFormat(
                        'hh:mm a, dd MMM',
                        'es_ES',
                      ).format(comment.timestamp!.toDate()),
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

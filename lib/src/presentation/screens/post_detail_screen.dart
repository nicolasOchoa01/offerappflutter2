import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:myapp/src/application/main/main_notifier.dart';
import 'package:myapp/src/domain/entities/comment.dart';
import 'package:myapp/src/domain/entities/post.dart';
import 'package:myapp/src/domain/entities/score.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  late TabController _tabController;
  bool _isMapInteracting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MainNotifier>().selectPost(widget.post.id);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _tabController.dispose();
    context.read<MainNotifier>().selectPost(null);
    super.dispose();
  }

  void _onSendComment(MainNotifier notifier, String postId) {
    if (_commentController.text.trim().isEmpty) return;
    notifier.addComment(postId, _commentController.text.trim());
    _commentController.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final mainNotifier = context.watch<MainNotifier>();
    final post = mainNotifier.selectedPost;

    if (post == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isAuthor = mainNotifier.user.id == post.user?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(post.description, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.pop();
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Foto'),
            Tab(text: 'Mapa'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: _isMapInteracting
                  ? const NeverScrollableScrollPhysics()
                  : const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  SizedBox(
                    height: 350,
                    child: TabBarView(
                      controller: _tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildPhotoView(post.imageUrl),
                        _buildMapView(post),
                      ],
                    ),
                  ),
                  _PostInfoSection(
                    post: post,
                    onDelete: () => _showDeleteDialog(context, mainNotifier, post.id),
                    onEdit: () => _showEditDialog(context, mainNotifier, post),
                    isAuthor: isAuthor,
                  ),
                  _CommentsSection(
                    comments: mainNotifier.comments,
                    onProfileClick: (userId) => context.push('/profile/$userId'),
                  )
                ],
              ),
            ),
          ),
          if (!isAuthor)
            _AddCommentSection(
              controller: _commentController,
              onSend: () => _onSendComment(mainNotifier, post.id),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoView(String imageUrl) {
    return CachedNetworkImage(
      imageUrl: imageUrl.replaceFirst("http://", "https://"),
      fit: BoxFit.cover,
      width: double.infinity,
      placeholder: (context, url) =>
          const Center(child: CircularProgressIndicator()),
      errorWidget: (context, url, error) =>
          const Center(child: Icon(Icons.error)),
    );
  }

  Widget _buildMapView(Post post) {
    return Listener(
      onPointerDown: (_) => setState(() => _isMapInteracting = true),
      onPointerUp: (_) => setState(() => _isMapInteracting = false),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(post.latitude, post.longitude),
          initialZoom: 15.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
          ),
          MarkerLayer(
            markers: [
              Marker(
                width: 80.0,
                height: 80.0,
                point: LatLng(post.latitude, post.longitude),
                child: const Icon(Icons.location_pin,
                    color: Colors.red, size: 40.0),
              ),
            ],
          ),
        ],
      ),
    );
  }

    Future<void> _showDeleteDialog(BuildContext context, MainNotifier notifier, String postId) {
    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: const Text('¿Estás seguro de que quieres eliminar este post? Esta acción no se puede deshacer.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
              onPressed: () {
                notifier.deletePost(postId);
                Navigator.of(dialogContext).pop();
                context.pop(); 
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditDialog(BuildContext context, MainNotifier notifier, Post post) {
    final descriptionController = TextEditingController(text: post.description);
    final priceController = TextEditingController(text: post.price.toString());
    final discountController = TextEditingController(text: post.discountPrice.toString());

    return showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Editar Publicación'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Descripción')),
                TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Precio'), keyboardType: TextInputType.number),
                TextField(controller: discountController, decoration: const InputDecoration(labelText: 'Precio con Descuento'), keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancelar')),
            TextButton(
              onPressed: () {
                final newDesc = descriptionController.text;
                final newPrice = double.tryParse(priceController.text) ?? post.price;
                final newDiscount = double.tryParse(discountController.text) ?? post.discountPrice;
                notifier.updatePostDetails(post.id, newDesc, newPrice, newDiscount, post.category, post.store);
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }
}

class _PostInfoSection extends StatelessWidget {
  final Post post;
  final bool isAuthor;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _PostInfoSection({required this.post, required this.isAuthor, required this.onDelete, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifier = context.read<MainNotifier>();
    final score = post.scores.fold<int>(0, (t, e) => t + e.value);
    final userVote = post.scores.firstWhere((s) => s.userId == notifier.user.id, orElse: () => const Score(userId: '', value: 0)).value;
    final isFavorite = notifier.user.favorites.contains(post.id);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAuthorInfo(context, post),
          const Divider(height: 24),
          _buildStatusAndValuation(theme, post, score),
          const SizedBox(height: 12),
          Text(post.description, style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          _buildPricesAndScore(theme, post, score),
          const SizedBox(height: 16),
          _buildInfoRows(theme, post),
          const SizedBox(height: 20),
          _buildActionButtons(context, notifier, post, isAuthor, userVote, isFavorite),
        ],
      ),
    );
  }

    Widget _buildAuthorInfo(BuildContext context, Post post) {
    final sdf = DateFormat('dd MMM yyyy', 'es_ES');
    final String authorId = post.user?.id ?? '';
    return InkWell(
      onTap: () {

        if (authorId.isNotEmpty) {
          GoRouter.of(context).go('/profile/$authorId');
        }
      },
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: post.user?.profileImageUrl != null
                ? CachedNetworkImageProvider(post.user!.profileImageUrl!)
                : null,
            child: post.user?.profileImageUrl == null ? const Icon(Icons.person, size: 20) : null,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(post.user?.username ?? 'Usuario desconocido', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              if (post.timestamp != null)
                Text('Publicado el ${sdf.format(post.timestamp!.toDate())}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusAndValuation(ThemeData theme, Post post, int score) {
    final bool isNew = post.timestamp != null && DateTime.now().difference(post.timestamp!.toDate()).inHours < 24;
    final String valuation = score > 10 ? "Ofertón" : score > 5 ? "Buena oferta" : score >= -5 ? "Oferta" : "Mala oferta";

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          post.status.toUpperCase(),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: post.status.toLowerCase() == "activa" ? Colors.green : theme.colorScheme.error,
            fontWeight: FontWeight.bold,
          ),
        ),
        if(isNew)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(4)),
            child: Text("NEW", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold)),
          ),
        Row(
          children: [
            Icon(Icons.star, color: theme.colorScheme.primary, size: 20),
            const SizedBox(width: 4),
            Text(valuation, style: theme.textTheme.bodyLarge),
          ],
        ),
      ],
    );
  }

    Widget _buildPricesAndScore(ThemeData theme, Post post, int score) {
    final Color scoreColor = score > 0 ? Colors.green : score < 0 ? theme.colorScheme.error : Colors.grey;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '\$${post.discountPrice.toStringAsFixed(2)}',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '\$${post.price.toStringAsFixed(2)}',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.grey,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Text('$score', style: theme.textTheme.titleLarge?.copyWith(color: scoreColor, fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            Icon(Icons.star, color: scoreColor, size: 24),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoRows(ThemeData theme, Post post) {
    return Column(
      children: [
        _InfoRow(icon: Icons.category, text: post.category),
        const SizedBox(height: 8),
        _InfoRow(icon: Icons.location_on, text: post.location),
        if(post.store.isNotEmpty) ...[
            const SizedBox(height: 8),
           _InfoRow(icon: Icons.store, text: post.store),
        ]
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, MainNotifier notifier, Post post, bool isAuthor, int userVote, bool isFavorite) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      alignment: WrapAlignment.spaceEvenly,
      children: [
        if (!isAuthor) ...[
          OutlinedButton.icon(
            onPressed: () => notifier.voteOnPost(post.id, 1),
            icon: Icon(Icons.thumb_up, color: userVote == 1 ? Colors.green : Colors.grey),
            label: const Text('Like'),
          ),
          OutlinedButton.icon(
            onPressed: () => notifier.voteOnPost(post.id, -1),
            icon: Icon(Icons.thumb_down, color: userVote == -1 ? Theme.of(context).colorScheme.error : Colors.grey),
            label: const Text('Dislike'),
          ),
        ],
        OutlinedButton.icon(
          onPressed: () => notifier.toggleFavorite(post.id),
          icon: Icon(Icons.star, color: isFavorite ? Colors.amber : Colors.grey),
          label: const Text('Favorito'),
        ),
        OutlinedButton.icon(
          onPressed: () => SharePlus.instance.share('¡Mira esta oferta en OfferApp! ${post.description} por solo \$${post.discountPrice}' as ShareParams),
          icon: const Icon(Icons.share),
          label: const Text('Compartir'),
        ),
        if (isAuthor) ...[
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit),
            label: const Text('Editar'),
          ),
          OutlinedButton.icon(
            onPressed: onDelete,
            icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
            label: Text('Eliminar', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            style: OutlinedButton.styleFrom(side: BorderSide(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyLarge)),
      ],
    );
  }
}

class _CommentsSection extends StatelessWidget {
  final List<Comment> comments;
  final ValueChanged<String> onProfileClick;

  const _CommentsSection({required this.comments, required this.onProfileClick});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Comentarios", style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          if (comments.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text("Aún no hay comentarios. ¡Sé el primero!"),
            ))
          else
            ListView.separated(
              itemCount: comments.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return _CommentItem(comment: comments[index], onProfileClick: onProfileClick);
              },
            ),
        ],
      ),
    );
  }
}

class _CommentItem extends StatelessWidget {
  final Comment comment;
  final ValueChanged<String> onProfileClick;

  const _CommentItem({required this.comment, required this.onProfileClick});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sdf = DateFormat('dd MMM yyyy, HH:mm', 'es_ES');
    final String userId = comment.user?.id ?? '';
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(128),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                final String userId = comment.user?.id ?? '';
                if (userId.isNotEmpty) {
                  onProfileClick(userId);
                }
              },
              child: CircleAvatar(
                radius: 20,
                backgroundImage: comment.user?.profileImageUrl != null
                    ? CachedNetworkImageProvider(comment.user!.profileImageUrl!)
                    : null,
                child: comment.user?.profileImageUrl == null ? const Icon(Icons.person, size: 20) : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => onProfileClick(comment.user?.id ?? ''),
                    child: Text(
                      comment.user?.username ?? 'Anónimo',
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (comment.timestamp != null)
                    Text(sdf.format(comment.timestamp!.toDate()), style: theme.textTheme.bodySmall),
                  const SizedBox(height: 6),
                  Text(comment.text, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCommentSection extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _AddCommentSection({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8.0,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Añadir un comentario...',
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: onSend,
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

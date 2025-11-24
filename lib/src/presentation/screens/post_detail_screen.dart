import 'package:flutter/material.dart';
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

class PostDetailScreen extends StatelessWidget {
  final Post post;

  const PostDetailScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final authRepo = Provider.of<AuthRepository>(context, listen: false);

    return StreamProvider<User?>.value(
      value: authRepo.onAuthStateChanged,
      initialData: authRepo.currentUser,
      child: Consumer<User?>(
        builder: (context, currentUser, _) {
          if (currentUser == null) {
            return const Scaffold(
              body: Center(child: Text("Usuario no autenticado")),
            );
          }
          return StreamBuilder<Post?>(
            stream: Provider.of<PostRepository>(
              context,
              listen: false,
            ).getPostStream(post.id),
            builder: (context, snapshot) {
              final livePost = snapshot.data ?? post;
              return Scaffold(
                appBar: AppBar(title: Text(livePost.description)),
                body: PostDetailContent(
                  post: livePost,
                  currentUser: currentUser,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class PostDetailContent extends StatefulWidget {
  final Post post;
  final User currentUser;

  const PostDetailContent({
    super.key,
    required this.post,
    required this.currentUser,
  });

  @override
  State<PostDetailContent> createState() => _PostDetailContentState();
}

class _PostDetailContentState extends State<PostDetailContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isAuthor = widget.post.user?.uid == widget.currentUser.uid;

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Foto'),
            Tab(text: 'Mapa'),
          ],
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: 350,
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    Image.network(
                      widget.post.imageUrl.replaceFirst("http://", "https://"),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.image_not_supported,
                        size: 50,
                        color: Colors.grey,
                      ),
                    ),
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          widget.post.latitude,
                          widget.post.longitude,
                        ),
                        zoom: 15,
                      ),
                      markers: {
                        Marker(
                          markerId: MarkerId(widget.post.id),
                          position: LatLng(
                            widget.post.latitude,
                            widget.post.longitude,
                          ),
                          infoWindow: InfoWindow(
                            title: widget.post.description,
                            snippet: widget.post.location,
                          ),
                        ),
                      },
                    ),
                  ],
                ),
              ),
              _PostInfoSection(
                post: widget.post,
                currentUser: widget.currentUser,
                isAuthor: isAuthor,
                onDelete: () => _showDeleteDialog(context),
                onEdit: () => _showEditDialog(context),
              ),
              const Divider(height: 16),
              _CommentsSection(
                post: widget.post,
                currentUser: widget.currentUser,
              ),
            ],
          ),
        ),
        if (!isAuthor)
          _AddCommentSection(
            commentController: _commentController,
            onSend: () {
              final postRepo = Provider.of<PostRepository>(
                context,
                listen: false,
              );
              if (_commentController.text.trim().isNotEmpty) {
                final comment = Comment(
                  id: '',
                  postId: widget.post.id,
                  userId: widget.currentUser.uid,
                  user: widget.currentUser,
                  text: _commentController.text.trim(),
                );
                postRepo.addCommentToPost(
                  postId: widget.post.id,
                  comment: comment,
                );
                _commentController.clear();
                FocusScope.of(context).unfocus();
              }
            },
          ),
      ],
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: const Text(
          '¿Estás seguro de que quieres eliminar este post? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Provider.of<PostRepository>(
                context,
                listen: false,
              ).deletePost(widget.post.id);
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final postRepo = Provider.of<PostRepository>(context, listen: false);

    var editedDescription = widget.post.description;
    var editedPrice = widget.post.price.toString();
    var editedDiscountPrice = widget.post.discountPrice.toString();
    var editedStore = widget.post.store;
    var editedCategory = widget.post.category;
    var editedStatus = widget.post.status;

    final categories = [
      "Alimentos",
      "Tecnología",
      "Moda",
      "Deportes",
      "Construcción",
      "Animales",
      "Electrodomésticos",
      "Servicios",
      "Educación",
      "Juguetes",
      "Vehículos",
      "Otros",
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Publicación'),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: TextEditingController(text: editedDescription),
                    onChanged: (v) => editedDescription = v,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                  ),
                  TextField(
                    controller: TextEditingController(text: editedPrice),
                    onChanged: (v) => editedPrice = v,
                    decoration: const InputDecoration(labelText: 'Precio'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: TextEditingController(
                      text: editedDiscountPrice,
                    ),
                    onChanged: (v) => editedDiscountPrice = v,
                    decoration: const InputDecoration(
                      labelText: 'Precio con Descuento',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: TextEditingController(text: editedStore),
                    onChanged: (v) => editedStore = v,
                    decoration: const InputDecoration(labelText: 'Tienda'),
                  ),
                  DropdownButtonFormField<String>(
                    items: categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    initialValue: editedCategory,
                    onChanged: (v) => editedCategory = v!,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text('Activa'),
                          selected: editedStatus == 'activa',
                          onSelected: (selected) {
                            if (selected)
                              setState(() => editedStatus = 'activa');
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Vencida'),
                          selected: editedStatus == 'vencida',
                          onSelected: (selected) {
                            if (selected)
                              setState(() => editedStatus = 'vencida');
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              postRepo.updatePostDetails(
                postId: widget.post.id,
                description: editedDescription,
                price: double.tryParse(editedPrice) ?? 0.0,
                discountPrice: double.tryParse(editedDiscountPrice) ?? 0.0,
                category: editedCategory,
                store: editedStore,
              );
              postRepo.updatePostStatus(widget.post.id, editedStatus);
              Navigator.of(ctx).pop();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _PostInfoSection extends StatelessWidget {
  final Post post;
  final User currentUser;
  final bool isAuthor;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _PostInfoSection({
    required this.post,
    required this.currentUser,
    required this.isAuthor,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final postRepo = Provider.of<PostRepository>(context, listen: false);
    final userRepo = Provider.of<UserRepository>(context, listen: false);
    final score = post.scores.fold<int>(0, (total, s) => total + s.value);

    final userVote = post.scores
        .firstWhere(
          (s) => s.userId == currentUser.uid,
          orElse: () => Score(userId: '', value: 0),
        )
        .value;

    return StreamBuilder<User?>(
      stream: userRepo.getUserStream(currentUser.uid),
      builder: (context, snapshot) {
        final liveUser = snapshot.data ?? currentUser;
        final isFavorite = liveUser.favorites.contains(post.id);

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _AuthorInfo(post: post),
              const Divider(height: 24),
              _StatusAndValuation(post: post, score: score),
              const SizedBox(height: 12),
              Text(
                post.description,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _PricesAndScore(post: post, score: score),
              const SizedBox(height: 16),
              _InfoRow(icon: Icons.category, text: post.category),
              const SizedBox(height: 8),
              _InfoRow(icon: Icons.location_on, text: post.location),
              if (post.store.isNotEmpty) ...[
                const SizedBox(height: 8),
                _InfoRow(icon: Icons.store, text: post.store),
              ],
              const SizedBox(height: 20),
              _ActionButtons(
                isAuthor: isAuthor,
                onVote: (value) => postRepo.updatePostScore(
                  postId: post.id,
                  userId: currentUser.uid,
                  value: value,
                ),
                userVote: userVote,
                isFavorite: isFavorite,
                onFavorite: () =>
                    userRepo.toggleFavorite(currentUser.uid, post.id),
                onShare: () {
                  final shareText =
                      '¡Mira esta oferta en OfferApp!\n\n${post.description} por solo \$${post.discountPrice}\n\n${post.imageUrl}';
                  Share.share(shareText);
                },
                onEdit: onEdit,
                onDelete: onDelete,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AuthorInfo extends StatelessWidget {
  final Post post;
  const _AuthorInfo({required this.post});

  @override
  Widget build(BuildContext context) {
    final imageUrl = post.user?.profileImageUrl;

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundImage: imageUrl != null && imageUrl.isNotEmpty
              ? NetworkImage(imageUrl)
              : null,
          child: imageUrl == null || imageUrl.isEmpty
              ? const Icon(Icons.person, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.user?.username ?? 'Usuario desconocido',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (post.timestamp != null)
              Text(
                DateFormat('dd MMM yyyy').format(post.timestamp!.toDate()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ],
    );
  }
}

class _StatusAndValuation extends StatelessWidget {
  final Post post;
  final int score;
  const _StatusAndValuation({required this.post, required this.score});

  String getValuation(int score) {
    if (score > 10) return "Ofertón";
    if (score > 5) return "Buena oferta";
    if (score >= -5) return "Oferta";
    if (score >= -10) return "Mala oferta";
    return "Estafa";
  }

  @override
  Widget build(BuildContext context) {
    final isNew =
        post.timestamp != null &&
        DateTime.now().difference(post.timestamp!.toDate()).inHours < 24;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          post.status.toUpperCase(),
          style: TextStyle(
            color: post.status == 'activa' ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (isNew)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            color: Theme.of(context).primaryColor,
            child: const Text(
              'NEW',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        Row(
          children: [
            Icon(
              Icons.thermostat,
              color: Theme.of(context).primaryColor,
              size: 20,
            ),
            const SizedBox(width: 4),
            Text(
              getValuation(score),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ],
    );
  }
}

class _PricesAndScore extends StatelessWidget {
  final Post post;
  final int score;
  const _PricesAndScore({required this.post, required this.score});

  @override
  Widget build(BuildContext context) {
    final Color scoreColor = score > 0
        ? Colors.green
        : (score < 0 ? Colors.red : Colors.grey);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '\$${post.discountPrice.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '\$${post.price.toStringAsFixed(2)}',
              style: const TextStyle(
                decoration: TextDecoration.lineThrough,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Text(
              score.toString(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: scoreColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              score > 0 ? Icons.arrow_upward : Icons.arrow_downward,
              color: scoreColor,
              size: 28,
            ),
          ],
        ),
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
        Icon(icon, size: 20, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final bool isAuthor;
  final int userVote;
  final bool isFavorite;
  final Function(int) onVote;
  final VoidCallback onFavorite;
  final VoidCallback onShare;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ActionButtons({
    required this.isAuthor,
    required this.userVote,
    required this.isFavorite,
    required this.onVote,
    required this.onFavorite,
    required this.onShare,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (isAuthor) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit),
            label: const Text('Editar'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete),
            label: const Text('Eliminar'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        IconButton(
          onPressed: () => onVote(1),
          icon: const Icon(Icons.thumb_up),
          color: userVote == 1 ? Colors.green : Colors.grey,
          tooltip: 'Votar positivo',
        ),
        IconButton(
          onPressed: () => onVote(-1),
          icon: const Icon(Icons.thumb_down),
          color: userVote == -1 ? Colors.red : Colors.grey,
          tooltip: 'Votar negativo',
        ),
        IconButton(
          onPressed: onFavorite,
          icon: Icon(isFavorite ? Icons.star : Icons.star_border),
          color: isFavorite ? Colors.amber : Colors.grey,
          tooltip: 'Marcar como favorito',
        ),
        IconButton(
          onPressed: onShare,
          icon: const Icon(Icons.share),
          color: Colors.grey,
          tooltip: 'Compartir',
        ),
      ],
    );
  }
}

class _CommentsSection extends StatelessWidget {
  final Post post;
  final User currentUser;
  const _CommentsSection({required this.post, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    final postRepo = Provider.of<PostRepository>(context, listen: false);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Comentarios', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          StreamBuilder<List<Comment>>(
            stream: postRepo.getCommentsForPost(post.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: Center(
                    child: Text('Aún no hay comentarios. ¡Sé el primero!'),
                  ),
                );
              }
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
      ),
    );
  }
}

class _CommentItem extends StatelessWidget {
  final Comment comment;
  const _CommentItem({required this.comment});

  @override
  Widget build(BuildContext context) {
    final imageUrl = comment.user?.profileImageUrl;

    return Card(
      elevation: 0,
      color: Colors.grey.shade100,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: imageUrl != null && imageUrl.isNotEmpty
                  ? NetworkImage(imageUrl)
                  : null,
              child: imageUrl == null || imageUrl.isEmpty
                  ? const Icon(Icons.person, size: 18, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comment.user?.username ?? 'Anónimo',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (comment.timestamp != null)
                    Text(
                      DateFormat(
                        'dd MMM yyyy, HH:mm',
                      ).format(comment.timestamp!.toDate()),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 6),
                  Text(comment.text),
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
  final TextEditingController commentController;
  final VoidCallback onSend;

  const _AddCommentSection({
    required this.commentController,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: commentController,
              decoration: const InputDecoration(
                labelText: 'Añadir un comentario...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 10.0,
                  horizontal: 15.0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: onSend,
            color: Theme.of(context).primaryColor,
            tooltip: 'Enviar comentario',
          ),
        ],
      ),
    );
  }
}

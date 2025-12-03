import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:myapp/src/application/main/main_notifier.dart';
import 'package:myapp/src/domain/entities/comment.dart';
import 'package:myapp/src/domain/entities/post.dart';
import 'package:myapp/src/domain/entities/user.dart';
import 'package:myapp/src/presentation/widgets/post_card.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _setupTabController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<MainNotifier>().loadUserProfile(widget.userId);
      }
    });
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userId != oldWidget.userId) {
      // The user has changed. We need to rebuild the state properly.
      // 1. Dispose the old tab controller.
      _tabController.dispose();
      // 2. Setup a new tab controller for the new user.
      _setupTabController();
      // 3. Load the new user's profile data.
      if (mounted) {
        context.read<MainNotifier>().loadUserProfile(widget.userId);
      }
    }
  }

  void _setupTabController() {
    final notifier = context.read<MainNotifier>();
    final isMyProfile = notifier.user.id == widget.userId;
    final tabCount = isMyProfile ? 3 : 2;
    _tabController = TabController(length: tabCount, vsync: this, initialIndex: 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    if (!mounted) return; 

    context.read<MainNotifier>().updateProfileImage(File(image.path));
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<MainNotifier>();
    final profileUser = notifier.profileUser;
    final currentUser = notifier.user;
    final isMyProfile = currentUser.id == widget.userId;
    final colorScheme = Theme.of(context).colorScheme;
    final iconTint = colorScheme.onPrimary;

    // Safeguard to ensure TabController is in sync if the profile type changes.
    final expectedTabCount = isMyProfile ? 3 : 2;
    if (_tabController.length != expectedTabCount) {
      _tabController.dispose();
      _setupTabController();
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.primary,
        leading: GoRouter.of(context).canPop()
            ? IconButton(icon: Icon(Icons.arrow_back, color: iconTint), onPressed: () => GoRouter.of(context).pop())
            : null,
        title: Text(
          profileUser != null ? 'Perfil de ${profileUser.username}' : 'Cargando...',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: iconTint,
              fontWeight: FontWeight.bold,
            ),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                 context.read<MainNotifier>().logout();
              }
              if (value == 'profile') {
                 final currentUserId = context.read<MainNotifier>().user.id;
                 context.go('/profile/$currentUserId');
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'username',
                enabled: false,
                child: Text('Hola, ${currentUser.username}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const PopupMenuDivider(),
              if (!isMyProfile)
                const PopupMenuItem<String>(
                  value: 'profile',
                  child: Text('Ver Mi Perfil'),
                ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Text('Cerrar Sesión'),
              ),
            ],
            icon: Icon(Icons.person, color: iconTint),
            tooltip: 'Perfil / Cerrar Sesión',
          ),
        ],
      ),
      body: profileUser == null
          ? const Center(child: CircularProgressIndicator())
          : NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return <Widget>[
                  SliverToBoxAdapter(
                    child: _buildProfileHeader(context, notifier, profileUser, isMyProfile),
                  ),
                  SliverPersistentHeader(
                    delegate: _SliverAppBarDelegate(
                      TabBar(
                        controller: _tabController,
                        tabs: _buildTabs(isMyProfile),
                      ),
                    ),
                    pinned: true,
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: _buildTabViews(notifier, isMyProfile, context),
              ),
            ),
    );
  }

  List<Tab> _buildTabs(bool isMyProfile) {
    final tabs = [
      const Tab(text: 'Posts'),
      const Tab(text: 'Comentarios'),
    ];
    if (isMyProfile) {
      tabs.add(const Tab(text: 'Favoritos'));
    }
    return tabs;
  }

  List<Widget> _buildTabViews(MainNotifier notifier, bool isMyProfile, BuildContext context) {
    final views = [
      _PostListView(posts: notifier.profileUserPosts, notifier: notifier),
      _CommentListView(
        comments: isMyProfile ? notifier.myComments : notifier.profileUserComments,
        onPostClick: (postId) {
          final post = context.read<MainNotifier>().getPostById(postId);
          if (post != null) {
            context.push('/post/${post.id}', extra: post);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Post no encontrado o no disponible.')),
            );
          }
        },
      ),
    ];
    if (isMyProfile) {
      views.add(_PostListView(posts: notifier.favoritePosts, notifier: notifier));
    }
    return views;
  }

  Widget _buildProfileHeader(BuildContext context, MainNotifier notifier, User profileUser, bool isMyProfile) {
    final isFollowing = notifier.user.following.contains(profileUser.id);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
           GestureDetector(
            onTap: isMyProfile ? _pickImage : null,
            child: CircleAvatar(
              radius: 60,
              backgroundImage: profileUser.profileImageUrl != null
                  ? CachedNetworkImageProvider(profileUser.profileImageUrl!)
                  : null,
              child: profileUser.profileImageUrl == null ? const Icon(Icons.account_circle, size: 120) : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(profileUser.username, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatColumn(count: notifier.profileUserPosts.length, title: "Posts"),
              _StatColumn(count: profileUser.followers.length, title: "Seguidores"),
              _StatColumn(count: profileUser.following.length, title: "Seguidos"),
            ],
          ),
          if (!isMyProfile) ...[
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (isFollowing) {
                  notifier.unfollowUser(profileUser.id);
                } else {
                  notifier.followUser(profileUser.id);
                }
              },
              child: Text(isFollowing ? 'Dejar de seguir' : 'Seguir'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}


class _StatColumn extends StatelessWidget {
  final int count;
  final String title;

  const _StatColumn({required this.count, required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(count.toString(), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        Text(title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey)),
      ],
    );
  }
}

class _PostListView extends StatelessWidget {
  final List<Post> posts;
  final MainNotifier notifier;

  const _PostListView({required this.posts, required this.notifier});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Center(child: Text('No hay posts para mostrar.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final isFavorite = notifier.user.favorites.contains(post.id);
        return PostCard(
          post: post,
          isFavorite: isFavorite,
          onToggleFavorite: () => notifier.toggleFavorite(post.id),
          onClick: () => context.push('/post/${post.id}', extra: post),
        );
      },
    );
  }
}

class _CommentListView extends StatelessWidget {
  final List<Comment> comments;
  final Function(String) onPostClick;

  const _CommentListView({required this.comments, required this.onPostClick});

  @override
  Widget build(BuildContext context) {
    if (comments.isEmpty) {
      return const Center(child: Text('No hay comentarios todavía.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: comments.length,
      itemBuilder: (context, index) {
        return _ProfileCommentItem(
          comment: comments[index],
          onClick: () => onPostClick(comments[index].postId),
        );
      },
    );
  }
}

class _ProfileCommentItem extends StatelessWidget {
  final Comment comment;
  final VoidCallback onClick;

  const _ProfileCommentItem({required this.comment, required this.onClick});

  @override
  Widget build(BuildContext context) {
    final notifier = context.read<MainNotifier>();
    final post = notifier.getPostById(comment.postId);
    final theme = Theme.of(context);
    final sdf = DateFormat('dd MMM yyyy', 'es_ES');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(77),
      child: InkWell(
        onTap: onClick,
        child: Column(
          children: [
            if (post != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: post.imageUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "En respuesta a:",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withAlpha(178),
                            ),
                          ),
                          Text(
                            post.description,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: comment.user?.profileImageUrl != null
                        ? CachedNetworkImageProvider(comment.user!.profileImageUrl!)
                        : null,
                    child: comment.user?.profileImageUrl == null ? const Icon(Icons.person, size: 20) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comment.user?.username ?? 'Anónimo',
                          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(comment.text, style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 4),
                        if (comment.timestamp != null)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              sdf.format(comment.timestamp!.toDate()),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface.withAlpha(153),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

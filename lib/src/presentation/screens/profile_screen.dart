import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:myapp/src/application/main/main_notifier.dart';
import 'package:myapp/src/data/services/image_picker_service.dart';
import 'package:myapp/src/domain/entities/comment.dart';
import 'package:myapp/src/domain/entities/post.dart';
import 'package:myapp/src/domain/entities/user.dart';
import 'package:myapp/src/presentation/widgets/post_card.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Initial setup for the TabController.
    _setupTabController();
    // Load user data after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MainNotifier>().loadUserProfile(widget.userId);
    });
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userId != oldWidget.userId) {
      // If the user ID changes, re-setup the tab controller and load new data.
      _setupTabController();
      context.read<MainNotifier>().loadUserProfile(widget.userId);
    }
  }

  void _setupTabController() {
    final isMyProfile = context.read<MainNotifier>().user.id == widget.userId;
    // The number of tabs depends on whether it's the current user's profile.
    _tabController = TabController(length: isMyProfile ? 3 : 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _changeProfileImage() async {
    final imagePicker = context.read<ImagePickerService>();
    final notifier = context.read<MainNotifier>();
    
    final File? imageFile = await imagePicker.pickImageFromGallery();

    if (imageFile != null) {
      // Let the notifier handle the business logic of updating the image.
      await notifier.updateProfileImage(imageFile);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the MainNotifier for state changes.
    final notifier = context.watch<MainNotifier>();
    final profileUser = notifier.profileUser;
    final currentUser = notifier.user;
    final isMyProfile = currentUser.id == widget.userId;

    if (profileUser == null) {
      // Show a loading indicator while the profile data is being fetched.
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isMyProfile ? 'Mi Perfil' : profileUser.username),
        leading: GoRouter.of(context).canPop() ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => GoRouter.of(context).pop()) : null,
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
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
          children: _buildTabViews(notifier, isMyProfile),
        ),
      ),
    );
  }

  List<Tab> _buildTabs(bool isMyProfile) {
    final tabs = [
      const Tab(icon: Icon(Icons.grid_on)),
      const Tab(icon: Icon(Icons.comment)),
    ];
    if (isMyProfile) {
      tabs.add(const Tab(icon: Icon(Icons.favorite)));
    }
    return tabs;
  }

  List<Widget> _buildTabViews(MainNotifier notifier, bool isMyProfile) {
    final currentUser = notifier.user;
    
    final views = [
      // Posts Tab
      _PostListView(posts: notifier.profileUserPosts, currentUser: currentUser, notifier: notifier),
      // Comments Tab
      _CommentListView(comments: notifier.profileUserComments),
    ];
    if (isMyProfile) {
      // Favorites Tab, only for the current user's profile
      views.add(_PostListView(posts: notifier.favoritePosts, currentUser: currentUser, notifier: notifier));
    }
    return views;
  }

  Widget _buildProfileHeader(BuildContext context, MainNotifier notifier, User profileUser, bool isMyProfile) {
    final postCount = notifier.profileUserPosts.length;
    final isFollowing = notifier.user.following.contains(profileUser.id);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          GestureDetector(
            onTap: isMyProfile ? _changeProfileImage : null,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: profileUser.profileImageUrl != null
                      ? CachedNetworkImageProvider(profileUser.profileImageUrl!)
                      : null,
                  child: profileUser.profileImageUrl == null ? const Icon(Icons.person, size: 50) : null,
                ),
                if (isMyProfile)
                  const CircleAvatar(
                    radius: 15,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.edit, size: 18, color: Colors.white),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(profileUser.username, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatColumn(count: postCount, title: "Posts"),
              _StatColumn(count: profileUser.followers.length, title: "Seguidores"),
              _StatColumn(count: profileUser.following.length, title: "Seguidos"),
            ],
          ),
          const SizedBox(height: 16),
          if (!isMyProfile)
            ElevatedButton(
              onPressed: () {
                if (isFollowing) {
                  notifier.unfollowUser(profileUser.id);
                } else {
                  notifier.followUser(profileUser.id);
                }
              },
              child: Text(isFollowing ? 'Dejar de Seguir' : 'Seguir'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
            ),
        ],
      ),
    );
  }
}

class _PostListView extends StatelessWidget {
  final List<Post> posts;
  final User currentUser;
  final MainNotifier notifier;

  const _PostListView({required this.posts, required this.currentUser, required this.notifier});

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const Center(child: Text('No hay posts para mostrar.'));
    }
    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final isFavorite = currentUser.favorites.contains(post.id);
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

  const _CommentListView({required this.comments});

  @override
  Widget build(BuildContext context) {
    if (comments.isEmpty) {
      return const Center(child: Text('No hay comentarios todavía.'));
    }
    return ListView.builder(
      itemCount: comments.length,
      itemBuilder: (context, index) {
        final comment = comments[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
             leading: CircleAvatar(
                backgroundImage: comment.user?.profileImageUrl != null
                    ? CachedNetworkImageProvider(comment.user!.profileImageUrl!)
                    : null,
                child: comment.user?.profileImageUrl == null ? const Icon(Icons.person) : null,
              ),
            title: Text(comment.user?.username ?? 'Anónimo'),
            subtitle: Text(comment.text),
            trailing: Text(DateFormat('dd MMM').format(comment.timestamp!.toDate())),
          ),
        );
      },
    );
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
        Text(count.toString(), style: Theme.of(context).textTheme.titleLarge),
        Text(title, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor, // Match background
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

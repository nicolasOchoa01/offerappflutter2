import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:myapp/src/data/repositories/auth_repository.dart';
import 'package:myapp/src/data/repositories/post_repository.dart';
import 'package:myapp/src/data/repositories/user_repository.dart';
import 'package:myapp/src/domain/entities/comment.dart';
import 'package:myapp/src/domain/entities/post.dart';
import 'package:myapp/src/domain/entities/user.dart';
import 'package:myapp/src/presentation/screens/post_detail_screen.dart';
import 'package:myapp/src/presentation/widgets/post_card.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  User? _currentUser;
  bool _isMyProfile = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final authRepo = context.read<AuthRepository>();
    if (authRepo.currentUser != null) {
      _isMyProfile = authRepo.currentUser!.uid == widget.userId;
      context.read<UserRepository>().getUserStream(authRepo.currentUser!.uid).listen((user) {
        if (mounted) {
          setState(() {
            _currentUser = user;
          });
        }
      });
    }
    _tabController = TabController(length: _isMyProfile ? 3 : 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _changeProfileImage() async {
    final userRepo = context.read<UserRepository>();
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null && _isMyProfile) {
      await userRepo.updateProfilePicture(widget.userId, image.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRepo = context.watch<UserRepository>();
    final postRepo = context.watch<PostRepository>();

    return StreamBuilder<User?>(
      stream: userRepo.getUserStream(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const Scaffold(body: Center(child: Text('Usuario no encontrado.')));
        }

        final profileUser = snapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: Text(_isMyProfile ? 'Mi Perfil' : 'Perfil de ${profileUser.username}'),
            centerTitle: true,
          ),
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: _buildProfileHeader(context, profileUser),
                ),
                SliverPersistentHeader(
                  delegate: _SliverAppBarDelegate(
                    TabBar(
                      controller: _tabController,
                      tabs: _isMyProfile
                          ? const [Tab(icon: Icon(Icons.grid_on)), Tab(icon: Icon(Icons.comment)), Tab(icon: Icon(Icons.favorite))]
                          : const [Tab(icon: Icon(Icons.grid_on)), Tab(icon: Icon(Icons.comment))],
                    ),
                  ),
                  pinned: true,
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: _isMyProfile
                  ? [
                      _buildPostsTab(postRepo, profileUser.id),
                      _buildCommentsTab(context, postRepo, profileUser.id),
                      _buildFavoritesTab(postRepo, profileUser),
                    ]
                  : [
                      _buildPostsTab(postRepo, profileUser.id),
                      _buildCommentsTab(context, postRepo, profileUser.id),
                    ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(BuildContext context, User profileUser) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          GestureDetector(
            onTap: _isMyProfile ? _changeProfileImage : null,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: profileUser.profileImageUrl != null ? NetworkImage(profileUser.profileImageUrl!) : null,
                  child: profileUser.profileImageUrl == null ? const Icon(Icons.person, size: 50) : null,
                ),
                if (_isMyProfile)
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
          StreamBuilder<List<Post>>(
            stream: context.read<PostRepository>().getPostsByUserStream(profileUser.id),
            builder: (context, postSnapshot) {
              final postCount = postSnapshot.data?.length ?? 0;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatColumn(count: postCount, title: "Posts"),
                  _StatColumn(count: profileUser.followers.length, title: "Seguidores"),
                  _StatColumn(count: profileUser.following.length, title: "Seguidos"),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          if (!_isMyProfile && _currentUser != null)
            StreamBuilder<User?>(
              stream: context.read<UserRepository>().getUserStream(_currentUser!.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                final isFollowing = snapshot.data!.following.contains(profileUser.id);

                return ElevatedButton(
                  onPressed: () {
                    final userRepo = context.read<UserRepository>();
                    if (isFollowing) {
                      userRepo.unfollowUser(_currentUser!.id, profileUser.id);
                    } else {
                      userRepo.followUser(_currentUser!.id, profileUser.id);
                    }
                  },
                  child: Text(isFollowing ? 'Dejar de Seguir' : 'Seguir'),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPostsTab(PostRepository postRepo, String userId) {
    return StreamBuilder<List<Post>>(
      stream: postRepo.getPostsByUserStream(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final posts = snapshot.data!;
        if (posts.isEmpty) return const Center(child: Text('No hay posts todavía.'));

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) => PostCard(post: posts[index], onClick: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailScreen(post: posts[index])));
          }),
        );
      },
    );
  }

  Widget _buildCommentsTab(BuildContext context, PostRepository postRepo, String userId) {
    return StreamBuilder<List<Comment>>(
      stream: postRepo.getCommentsByUserStream(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final comments = snapshot.data!;
        if (comments.isEmpty) return const Center(child: Text('No hay comentarios todavía.'));

        return ListView.builder(
          itemCount: comments.length,
          itemBuilder: (context, index) => ProfileCommentItem(
            comment: comments[index],
            postRepo: postRepo,
            onTap: (post) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailScreen(post: post)));
            },
          ),
        );
      },
    );
  }

  Widget _buildFavoritesTab(PostRepository postRepo, User user) {
    return StreamBuilder<List<Post>>(
      stream: postRepo.getFavoritePostsStream(user.favorites),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final posts = snapshot.data!;
        if (posts.isEmpty) return const Center(child: Text('No tienes posts favoritos.'));

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) => PostCard(post: posts[index], onClick: () {
             Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetailScreen(post: posts[index])));
          }),
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
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
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

class ProfileCommentItem extends StatelessWidget {
  final Comment comment;
  final PostRepository postRepo;
  final Function(Post) onTap;

  const ProfileCommentItem({super.key, required this.comment, required this.postRepo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Post?>(
        future: postRepo.getPostFuture(comment.postId),
        builder: (context, postSnapshot) {
            final post = postSnapshot.data;
            final sdf = DateFormat('dd MMM yyyy', 'es_ES');

            return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: InkWell(
                    onTap: post != null ? () => onTap(post) : null,
                    child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                if (post != null)
                                    Row(
                                        children: [
                                            Image.network(post.imageUrl, width: 40, height: 40, fit: BoxFit.cover),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                "En respuesta a: ${post.description}",
                                                style: Theme.of(context).textTheme.bodySmall,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                        ],
                                    ),
                                if (post != null) const Divider(),
                                Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                        CircleAvatar(
                                            radius: 20,
                                            backgroundImage: comment.user?.profileImageUrl != null
                                                ? NetworkImage(comment.user!.profileImageUrl!)
                                                : null,
                                            child: comment.user?.profileImageUrl == null
                                                ? const Icon(Icons.person)
                                                : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                            child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                    Text(comment.user?.username ?? 'Anónimo', style: Theme.of(context).textTheme.titleMedium),
                                                    const SizedBox(height: 4),
                                                    Text(comment.text, style: Theme.of(context).textTheme.bodyMedium),
                                                ],
                                            )
                                        )
                                    ],
                                ),
                                 if (comment.timestamp != null)
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Text(
                                        sdf.format(comment.timestamp!.toDate()),
                                        style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  )
                            ],
                        ),
                    ),
                ),
            );
        }
    );
  }
}

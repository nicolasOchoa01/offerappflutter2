import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/src/data/repositories/auth_repository.dart';
import 'package:myapp/src/data/repositories/post_repository.dart';
import 'package:myapp/src/domain/entities/comment.dart';
import 'package:myapp/src/domain/entities/post.dart';
import 'package:myapp/src/domain/entities/user.dart';

class MainNotifier with ChangeNotifier {
  final PostRepository _postRepository;
  final AuthRepository _authRepository;

  User _user;
  User get user => _user;

  List<Post> _posts = [];
  List<Post> get posts => _posts;

  List<Post> _allPosts = [];

  String _searchQuery = "";
  String get searchQuery => _searchQuery;

  final String _selectedCategory = "Todos";
  String get selectedCategory => _selectedCategory;

  int _selectedFeedTab = 0;
  int get selectedFeedTab => _selectedFeedTab;

  final String _currentSortOption = "Fecha (más recientes)";
  String get currentSortOption => _currentSortOption;

  DocumentSnapshot? _lastVisiblePost;
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool _allPostsLoaded = false;

  String? _selectedPostId;
  String? get selectedPostId => _selectedPostId;

  bool? _isDarkTheme;
  bool? get isDarkTheme => _isDarkTheme;

  Post? get selectedPost {
    if (_selectedPostId == null) return null;
    try {
      return _allPosts.firstWhere((p) => p.id == _selectedPostId);
    } catch (e) {
      return null; 
    }
  }

  List<Comment> _comments = [];
  List<Comment> get comments => _comments;

  User? _profileUser;
  User? get profileUser => _profileUser;

  List<Post> _profileUserPosts = [];
  List<Post> get profileUserPosts => _profileUserPosts;

  List<Post> _profileUserFavorites = [];
  List<Post> get profileUserFavorites => _profileUserFavorites;

  List<Comment> _profileUserComments = [];
  List<Comment> get profileUserComments => _profileUserComments;

  List<Comment> _myComments = [];
  List<Comment> get myComments => _myComments;

  StreamSubscription? _commentsSubscription;
  StreamSubscription? _profileCommentsSubscription;
  StreamSubscription? _myCommentsSubscription;

  List<Post> get myPosts => _allPosts.where((p) => p.user?.id == _user.id).toList();
  List<Post> get favoritePosts =>
      _allPosts.where((p) => _user.favorites.contains(p.id)).toList();

  Post? getPostById(String postId) {
    try {
      return _allPosts.firstWhere((p) => p.id == postId);
    } catch (e) {
      return null;
    }
  }

  Future<List<User>> getUsersByIds(List<String> userIds) {
    return _authRepository.getUsers(userIds);
  }

  MainNotifier(this._user, this._postRepository, this._authRepository) {
    refreshPosts();
    _authRepository.getUser(_user.id).then((fetchedUser) {
      if (fetchedUser != null) {
        _user = fetchedUser;
        notifyListeners();
      }
    });
    _myCommentsSubscription = _postRepository.getCommentsForUserStream(_user.id).listen((comments) {
      _myComments = comments;
      notifyListeners();
    });
  }

  Future<void> signOut() async {
    await _authRepository.logout();
  }

  void onThemeChange(bool? isDark) {
    _isDarkTheme = isDark;
    notifyListeners();
  }
  
  void updateSearchQuery(String newQuery) {
    _searchQuery = newQuery;
    _applyFilters();
  }

  Future<void> loadMorePosts() async {
    if (_isLoading || _allPostsLoaded) return;

    _isLoading = true;
    notifyListeners();

    try {
      final result = await _postRepository.getPosts(
        lastVisible: _lastVisiblePost,
        category: _selectedCategory,
      );
      final newPosts = result['posts'] as List<Post>;
      final newLastVisible = result['lastVisible'] as DocumentSnapshot?;

      if (newPosts.isNotEmpty) {
        _allPosts.addAll(newPosts);
        _lastVisiblePost = newLastVisible;
        _applyFilters();
      } else {
        _allPostsLoaded = true;
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error loading more posts: $e");
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void refreshPosts() {
    _posts = [];
    _allPosts = [];
    _lastVisiblePost = null;
    _allPostsLoaded = false;
    loadMorePosts();
  }

  void selectPost(String? postId) {
    _selectedPostId = postId;
    if (postId != null) {
      _loadComments(postId);
    } else {
      _commentsSubscription?.cancel();
    }
    notifyListeners();
  }

  void _loadComments(String postId) {
    _commentsSubscription?.cancel();
    _commentsSubscription = _postRepository.getCommentsStream(postId).listen((comments) {
      _comments = comments;
      notifyListeners();
    });
  }

  void onFeedTabSelected(int tabIndex) {
    _selectedFeedTab = tabIndex;
    _applyFilters();
  }

  Future<void> loadUserProfile(String userId) async {
    if (userId.isEmpty) return;

    _profileCommentsSubscription?.cancel();
    _profileUser = null;
    _profileUserPosts = [];
    _profileUserFavorites = [];
    _profileUserComments = [];
    notifyListeners();

    try {
      final profileToLoad = userId == _user.id ? _user : await _authRepository.getUser(userId);
      if (profileToLoad == null) return;

      _profileUser = profileToLoad;
      notifyListeners();

      _profileUserPosts = await _postRepository.getPostsForUser(profileToLoad.id);
      notifyListeners();

      if (profileToLoad.favorites.isNotEmpty) {
        _profileUserFavorites = await _postRepository.getFavoritePosts(profileToLoad.favorites);
        notifyListeners();
      }

      _profileCommentsSubscription = _postRepository.getCommentsForUserStream(profileToLoad.id).listen((comments) {
          _profileUserComments = comments;
          notifyListeners();
      });

    } catch(e) {
        if (kDebugMode) {
          print("Error loading user profile: $e");
        }
    }
  }


   Future<void> refreshCurrentUser() async {
    try {
      final refreshedUser = await _authRepository.getUser(_user.id);
      if (refreshedUser != null) {
        _user = refreshedUser;
        _applyFilters(); 
      }
    } catch (e) {
      if (kDebugMode) {
        print("Failed to refresh current user: $e");
      }
    }
  }

  Future<void> followUser(String followedUserId) async {
    try {
        await _authRepository.followUser(followerId: _user.id, followingId: followedUserId);
        await refreshCurrentUser();
        final refreshedProfileUser = await _authRepository.getUser(followedUserId);
        if(refreshedProfileUser != null) {
            _profileUser = refreshedProfileUser;
            notifyListeners();
        }
    } catch (e) {
        if (kDebugMode) {
            print("Failed to unfollow user: $e");
        }
    }
  }

  Future<void> unfollowUser(String followedUserId) async {
    try {
        await _authRepository.unfollowUser(followerId: _user.id, followingId: followedUserId);
        await refreshCurrentUser();
        final refreshedProfileUser = await _authRepository.getUser(followedUserId);
        if(refreshedProfileUser != null) {
            _profileUser = refreshedProfileUser;
            notifyListeners();
        }
    } catch (e) {
        if (kDebugMode) {
            print("Failed to unfollow user: $e");
        }
    }
  }

    Future<void> updateProfileImage(File imageFile) async {
      try {
        await _authRepository.updateUserProfileImage(uid: _user.id, imageFile: imageFile);
        await refreshCurrentUser();
      } catch (e) {
        if(kDebugMode) {
          print("Error updating profile image: $e");
        }
      }
    }

  Future<void> addComment(String postId, String text) async {
    try {
      await _postRepository.addComment(postId: postId, text: text, userId: _user.id);
      // The stream in loadUserProfile will handle the update automatically.
      // No need to call notifyListeners() here if streams are set up correctly.
    } catch (e) {
      if (kDebugMode) {
        print("Error adding comment: $e");
      }
    }
  }

  Future<void> addPost({
    required String description,
    required File imageFile,
    required String location,
    required double latitude,
    required double longitude,
    required String category,
    required double price,
    required double discountPrice,
    required String store,
  }) async {
    try {
      final newPost = Post(
        id: '', 
        userId: _user.id,
        description: description,
        imageUrl: '', 
        location: location,
        latitude: latitude,
        longitude: longitude,
        category: category,
        price: price,
        discountPrice: discountPrice,
        store: store,
        user: _user, 
        timestamp: Timestamp.now(),
        status: 'Activa',
        scores: [],
      );
      
      await _postRepository.addPost(post: newPost, imageFile: imageFile);
      
      refreshPosts();
    } catch (e) {
      if (kDebugMode) {
        print('Error adding post: $e');
      }
      rethrow;
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await _postRepository.deletePost(postId);
      _allPosts.removeWhere((p) => p.id == postId);
      _applyFilters();
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting post: $e');
      }
    }
  }

  Future<void> updatePostDetails(
    String postId,
    String description,
    double price,
    double discountPrice,
    String category,
    String store,
  ) async {
    try {
      await _postRepository.updatePostDetails(
        postId: postId,
        description: description,
        price: price,
        discountPrice: discountPrice,
        category: category,
        store: store,
      );
      final updatedPost = await _postRepository.getPostFuture(postId);
      if (updatedPost != null) {
        final index = _allPosts.indexWhere((p) => p.id == postId);
        if (index != -1) {
          _allPosts[index] = updatedPost;
          _applyFilters();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating post details: $e');
      }
    }
  }

  void toggleFavorite(String postId) {
    final isCurrentlyFavorite = _user.favorites.contains(postId);
    final originalFavorites = List<String>.from(_user.favorites);

    // Optimistically update the UI
    if (isCurrentlyFavorite) {
      _user.favorites.remove(postId);
    } else {
      _user.favorites.add(postId);
    }
    notifyListeners();

    // Update the backend and handle errors
    try {
      if (isCurrentlyFavorite) {
        _authRepository.removeFavorite(userId: _user.id, postId: postId);
      } else {
        _authRepository.addFavorite(userId: _user.id, postId: postId);
      }
    } catch (e) {
      // Revert UI on error
      _user = _user.copyWith(favorites: originalFavorites);
      notifyListeners();
    }

    // If the current user is viewing their own profile, refresh the favorite posts list
    if (_profileUser?.id == _user.id) {
      _postRepository.getFavoritePosts(_user.favorites).then((posts) {
        _profileUserFavorites = posts;
        notifyListeners();
      });
    }
  }

  Future<void> voteOnPost(String postId, int value) async {
    try {
      await _postRepository.updatePostScore(
        postId: postId,
        userId: _user.id,
        value: value,
      );
      final updatedPost = await _postRepository.getPostFuture(postId);
      if (updatedPost != null) {
        final postIndex = _allPosts.indexWhere((p) => p.id == postId);
        if (postIndex != -1) {
          _allPosts[postIndex] = updatedPost;
          _applyFilters(); 
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Failed to vote on post: $e");
      }
    }
  }

  void _applyFilters() {
    List<Post> filteredPosts = _allPosts;

    if (_selectedFeedTab == 1) {
      filteredPosts = filteredPosts.where((post) => _user.following.contains(post.user?.id)).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filteredPosts = filteredPosts.where((post) {
        return post.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            post.location.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    _posts = filteredPosts;
    notifyListeners();
  }

  @override
  void dispose() {
    _commentsSubscription?.cancel();
    _profileCommentsSubscription?.cancel();
    _myCommentsSubscription?.cancel();
    super.dispose();
  }
}

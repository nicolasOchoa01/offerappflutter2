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

  bool _isDisposed = false;

  // ENTITY STATE
  User _user;
  User get user => _user;

  // POSTS FEED STATE
  List<Post> _posts = [];
  List<Post> get posts => _posts;
  List<Post> _allPosts = [];

  // FILTERING AND SORTING STATE
  String _searchQuery = "";
  String get searchQuery => _searchQuery;

  String _selectedCategory = "Todos";
  String get selectedCategory => _selectedCategory;

  String _currentSortOption = "Fecha (más reciente)";
  String get currentSortOption => _currentSortOption;

  final Map<String, String> _sortOptionsMap = {
    'Fecha (más reciente)': 'timestamp_desc',
    'Precio (mayor a menor)': 'price_desc',
    'Precio (menor a mayor)': 'price_asc',
  };

  // PAGINATION STATE
  DocumentSnapshot? _lastVisiblePost;
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool _allPostsLoaded = false;

  // TABS AND NAVIGATION STATE
  int _selectedFeedTab = 0;
  int get selectedFeedTab => _selectedFeedTab;
  String? _selectedPostId;
  String? get selectedPostId => _selectedPostId;

  // THEME STATE
  bool? _isDarkTheme;
  bool? get isDarkTheme => _isDarkTheme;

  // DERIVED STATE (GETTERS)
  Post? get selectedPost {
    if (_selectedPostId == null) return null;
    try {
      return _allPosts.firstWhere((p) => p.id == _selectedPostId);
    } catch (e) {
      return null;
    }
  }
  List<Post> get myPosts => _allPosts.where((p) => p.user?.id == _user.id).toList();
  List<Post> get favoritePosts =>
      _allPosts.where((p) => _user.favorites.contains(p.id)).toList();

  // COMMENTS AND PROFILE STATE
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

  // STREAM SUBSCRIPTIONS
  StreamSubscription? _commentsSubscription;
  StreamSubscription? _profileCommentsSubscription;
  StreamSubscription? _myCommentsSubscription;

  // CONSTRUCTOR
  MainNotifier(this._user, this._postRepository, this._authRepository) {
    _authRepository.getUser(_user.id).then((fetchedUser) {
      if (!_isDisposed && fetchedUser != null) {
        _user = fetchedUser;
        _safeNotifyListeners();
      }
    });
    _myCommentsSubscription = _postRepository.getCommentsForUserStream(_user.id).listen((comments) {
      if (!_isDisposed) {
        _myComments = comments;
        _safeNotifyListeners();
      }
    });
  }

  // --- PUBLIC METHODS (UI ACTIONS) ---

  Future<void> logout() async {
    await _authRepository.logout();
  }

  void onThemeChange(bool? isDark) {
    _isDarkTheme = isDark;
    _safeNotifyListeners();
  }

  void updateSearchQuery(String newQuery) {
    _searchQuery = newQuery;
    _applyClientSideFilters();
  }

  Future<void> loadMorePosts() async {
    if (_isLoading || _allPostsLoaded) return;
    _isLoading = true;
    _safeNotifyListeners();

    try {
      final String sortValue = _sortOptionsMap[_currentSortOption] ?? 'timestamp_desc';
      
      final result = await _postRepository.getPosts(
        lastVisible: _lastVisiblePost,
        sortOption: sortValue,
        category: _selectedCategory,
      );

      final newPosts = result['posts'] as List<Post>;
      final newLastVisible = result['lastVisible'] as DocumentSnapshot?;

      if (newPosts.isNotEmpty) {
        _allPosts.addAll(newPosts);
        _lastVisiblePost = newLastVisible;
        _applyClientSideFilters();
      } else {
        _allPostsLoaded = true;
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error loading more posts: $e");
      }
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<void> refreshPosts() async {
    _posts = [];
    _allPosts = [];
    _lastVisiblePost = null;
    _allPostsLoaded = false;
    _safeNotifyListeners(); 
    await loadMorePosts();
  }

  void setSortOption(String sortOption) {
    if (_currentSortOption == sortOption) return;
    _currentSortOption = sortOption;

    // If sorting by something other than date (e.g., price), reset the category filter
    // to "Todos" to avoid composite queries that require a new index.
    if (sortOption != 'Fecha (más reciente)') {
      _selectedCategory = "Todos";
    }

    _safeNotifyListeners();
    refreshPosts();
  }

  void filterByCategory(String category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;

    // If filtering by a specific category, reset the sort option to the default (date)
    // to avoid composite queries that require a new index.
    if (category != "Todos") {
      _currentSortOption = "Fecha (más reciente)";
    }

    _safeNotifyListeners();
    refreshPosts();
  }

  void selectPost(String? postId) {
    _selectedPostId = postId;
    if (postId != null) {
      _loadComments(postId);
    } else {
      _commentsSubscription?.cancel();
    }
    _safeNotifyListeners();
  }

  void onFeedTabSelected(int tabIndex) {
    _selectedFeedTab = tabIndex;
    _applyClientSideFilters();
  }

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

  Future<void> addComment(String postId, String text) async {
    try {
      await _postRepository.addComment(postId: postId, text: text, userId: _user.id);
    } catch (e) {
      if (kDebugMode) {
        print("Error adding comment: $e");
      }
    }
  }

  Future<void> addPost({
    required String description,
    File? imageFile,
    Uint8List? imageBytes,
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
        id: '', userId: _user.id, description: description, imageUrl: '',
        location: location, latitude: latitude, longitude: longitude, category: category,
        price: price, discountPrice: discountPrice, store: store, user: _user,
        timestamp: Timestamp.now(), status: 'Activa', scores: [],
      );
      await _postRepository.addPost(post: newPost, imageFile: imageFile, imageBytes: imageBytes);
      refreshPosts();
    } catch (e) {
      if (kDebugMode) { print('Error adding post: $e'); }
      rethrow;
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await _postRepository.deletePost(postId);
      _allPosts.removeWhere((p) => p.id == postId);
      _applyClientSideFilters();
    } catch (e) {
      if (kDebugMode) { print('Error deleting post: $e'); }
    }
  }

  Future<void> updatePostDetails({
    required String postId, required String description, required double price,
    required double discountPrice, required String category, required String store, required String status,
  }) async {
    try {
      await _postRepository.updatePostDetails(postId: postId, description: description, price: price,
        discountPrice: discountPrice, category: category, store: store, status: status,);
      final updatedPost = await _postRepository.getPostFuture(postId);
      if (!_isDisposed && updatedPost != null) {
        final index = _allPosts.indexWhere((p) => p.id == postId);
        if (index != -1) {
          _allPosts[index] = updatedPost;
          _applyClientSideFilters();
        }
      }
    } catch (e) {
      if (kDebugMode) { print('Error updating post details: $e'); }
    }
  }

  void toggleFavorite(String postId) {
    final isCurrentlyFavorite = _user.favorites.contains(postId);
    final originalFavorites = List<String>.from(_user.favorites);
    if (isCurrentlyFavorite) { _user.favorites.remove(postId); } else { _user.favorites.add(postId); }
    _safeNotifyListeners();

    if (isCurrentlyFavorite) {
      _authRepository.removeFavorite(userId: _user.id, postId: postId).catchError((_) {
        if (!_isDisposed) { _user = _user.copyWith(favorites: originalFavorites); _safeNotifyListeners(); }
      });
    } else {
      _authRepository.addFavorite(userId: _user.id, postId: postId).catchError((_) {
        if (!_isDisposed) { _user = _user.copyWith(favorites: originalFavorites); _safeNotifyListeners(); }
      });
    }
  }

  Future<void> voteOnPost(String postId, int value) async {
    try {
      await _postRepository.updatePostScore(postId: postId, userId: _user.id, value: value,);
      final updatedPost = await _postRepository.getPostFuture(postId);
      if (!_isDisposed && updatedPost != null) {
        final postIndex = _allPosts.indexWhere((p) => p.id == postId);
        if (postIndex != -1) {
          _allPosts[postIndex] = updatedPost;
          _applyClientSideFilters();
        }
      }
    } catch (e) {
      if (kDebugMode) { print("Failed to vote on post: $e"); }
    }
  }

  Future<void> loadUserProfile(String userId) async {
    if (userId.isEmpty) return;
    _profileCommentsSubscription?.cancel();
    _profileUser = null; _profileUserPosts = []; _profileUserFavorites = []; _profileUserComments = [];
    _safeNotifyListeners();

    try {
      final profileToLoad = userId == _user.id ? _user : await _authRepository.getUser(userId);
      if (_isDisposed) return;
      _profileUser = profileToLoad;

      if (profileToLoad != null) {
        _profileUserPosts = await _postRepository.getPostsForUser(profileToLoad.id);
        if (_isDisposed) return;
        _profileUserFavorites = await _postRepository.getFavoritePosts(profileToLoad.favorites);
        if (_isDisposed) return;
        _profileCommentsSubscription = _postRepository.getCommentsForUserStream(profileToLoad.id).listen((comments) { // TYPO FIXED
          if (!_isDisposed) { _profileUserComments = comments; _safeNotifyListeners(); }
        });
      }
    } catch (e) {
      if (kDebugMode) { print("Error loading user profile: $e"); }
    }
    _safeNotifyListeners();
  }

  Future<void> refreshCurrentUser() async {
    try {
      final refreshedUser = await _authRepository.getUser(_user.id);
      if (!_isDisposed && refreshedUser != null) {
        _user = refreshedUser;
        _applyClientSideFilters();
      }
    } catch (e) {
      if (kDebugMode) { print("Failed to refresh current user: $e"); }
    }
  }

  Future<void> followUser(String followedUserId) async {
    try {
      await _authRepository.followUser(followerId: _user.id, followingId: followedUserId);
      await refreshCurrentUser();
      final refreshedProfileUser = await _authRepository.getUser(followedUserId);
      if (!_isDisposed && refreshedProfileUser != null) { _profileUser = refreshedProfileUser; _safeNotifyListeners(); }
    } catch (e) {
      if (kDebugMode) { print("Failed to unfollow user: $e"); }
    }
  }

  Future<void> unfollowUser(String followedUserId) async {
    try {
      await _authRepository.unfollowUser(followerId: _user.id, followingId: followedUserId);
      await refreshCurrentUser();
      final refreshedProfileUser = await _authRepository.getUser(followedUserId);
      if (!_isDisposed && refreshedProfileUser != null) { _profileUser = refreshedProfileUser; _safeNotifyListeners(); }
    } catch (e) {
      if (kDebugMode) { print("Failed to unfollow user: $e"); }
    }
  }

  Future<void> updateProfileImage(File imageFile) async {
    try {
      await _authRepository.updateUserProfileImage(uid: _user.id, imageFile: imageFile);
      await refreshCurrentUser();
    } catch (e) {
      if (kDebugMode) { print("Error updating profile image: $e"); }
    }
  }

  

  void _loadComments(String postId) {
    _commentsSubscription?.cancel();
    _commentsSubscription = _postRepository.getCommentsStream(postId).listen((comments) {
      if (!_isDisposed) { _comments = comments; _safeNotifyListeners(); }
    });
  }

  void _applyClientSideFilters() {
    if (_isDisposed) return;
    List<Post> filteredPosts = _allPosts;

    if (_selectedFeedTab == 1) {
      filteredPosts = filteredPosts.where((post) => _user.following.contains(post.user?.id)).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filteredPosts = filteredPosts.where((post) {
        return post.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            post.location.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (post.user?.username.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      }).toList();
    }

    _posts = filteredPosts;
    _safeNotifyListeners();
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      try { notifyListeners(); } catch (e) {
        if (kDebugMode) { print("Caught error during notifyListeners: $e"); }
      }
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _commentsSubscription?.cancel();
    _profileCommentsSubscription?.cancel();
    _myCommentsSubscription?.cancel();
    super.dispose();
  }
}

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

  // FIX: Made final as its value is never changed.
  final String _selectedCategory = "Todos";
  String get selectedCategory => _selectedCategory;

  int _selectedFeedTab = 0;
  int get selectedFeedTab => _selectedFeedTab;

  // FIX: Made final as its value is never changed.
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

  Post? get selectedPost => _selectedPostId != null
      ? _allPosts.firstWhere((p) => p.id == _selectedPostId)
      : null;

  List<Comment> _comments = [];
  List<Comment> get comments => _comments;

  User? _profileUser;
  User? get profileUser => _profileUser;

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
  
  List<Post> get profileUserPosts {
    if (_profileUser == null) return [];
    return _allPosts.where((p) => p.user?.id == _profileUser!.id).toList();
  }
  
  List<Post> get profileUserFavorites {
    if (_profileUser == null) return [];
    return _allPosts.where((p) => _profileUser!.favorites.contains(p.id)).toList();
  }

  MainNotifier(this._user, this._postRepository, this._authRepository) {
    refreshPosts();
    _authRepository.getUser(_user.id).then((fetchedUser) {
      if (fetchedUser != null) {
        _user = fetchedUser;
        notifyListeners();
      }
    });
    _myCommentsSubscription = _postRepository.getCommentsStream(_user.id).listen((comments) {
      _myComments = comments;
      notifyListeners();
    });
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
    _profileUserComments = [];
    notifyListeners();

    try {
      final profileToLoad = userId == _user.id ? _user : await _authRepository.getUser(userId);
      _profileUser = profileToLoad;

      if (profileToLoad != null) {
        _profileCommentsSubscription = _postRepository.getCommentsStream(userId).listen((comments) {
            _profileUserComments = comments;
            notifyListeners();
        });
      }
    } catch(e) {
        if (kDebugMode) {
          print("Error loading user profile: $e");
        }
    }
    notifyListeners();
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
            await _postRepository.addComment(postId: postId, text: text, userId: _user.id, user: _user);
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
        id: '', // Firestore generates this
        // FIX: Added the required userId parameter.
        userId: _user.id,
        description: description,
        imageUrl: '', // The repository will fill this after upload
        location: location,
        latitude: latitude,
        longitude: longitude,
        category: category,
        price: price,
        discountPrice: discountPrice,
        store: store,
        user: _user, // User from the notifier
        timestamp: Timestamp.now(),
        status: 'Activa',
        scores: [],
      );
      
      await _postRepository.addPost(post: newPost, imageFile: imageFile);
      
      // Refresh the post list to show the new post immediately.
      refreshPosts();
    } catch (e) {
      if (kDebugMode) {
        print('Error adding post: $e');
      }
      // Rethrow the error to be caught by the UI.
      rethrow;
    }
  }

    void toggleFavorite(String postId) {
      final isCurrentlyFavorite = _user.favorites.contains(postId);
      final originalFavorites = List<String>.from(_user.favorites);

      if (isCurrentlyFavorite) {
        _user.favorites.remove(postId);
      } else {
        _user.favorites.add(postId);
      }
      notifyListeners();

      if (isCurrentlyFavorite) {
        _authRepository.removeFavorite(userId: _user.id, postId: postId).catchError((_){
            _user = _user.copyWith(favorites: originalFavorites);
            notifyListeners();
        });
      } else {
        _authRepository.addFavorite(userId: _user.id, postId: postId).catchError((_){
            _user = _user.copyWith(favorites: originalFavorites);
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
      // After voting, fetch the updated post to reflect the new score
      final updatedPost = await _postRepository.getPostFuture(postId);
      if (updatedPost != null) {
        final postIndex = _allPosts.indexWhere((p) => p.id == postId);
        if (postIndex != -1) {
          _allPosts[postIndex] = updatedPost;
          _applyFilters(); // This will rebuild the list and notify listeners
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

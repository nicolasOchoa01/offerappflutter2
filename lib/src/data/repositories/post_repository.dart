import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:myapp/src/domain/entities/comment.dart';
import 'package:myapp/src/domain/entities/post.dart';
import 'package:myapp/src/domain/entities/user.dart';

class PostRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudinaryPublic _cloudinary = CloudinaryPublic('ml_default', 'dyloasili', cache: false);

  // Helper to fetch a User object
  Future<User?> _fetchUser(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.exists ? User.fromSnapshot(userDoc) : null;
    } catch (e) {
      print('Error fetching user: $e');
      return null;
    }
  }

  // Helper to construct a Post from a document, fetching the user
  Future<Post> _buildPostFromDoc(DocumentSnapshot doc) async {
    final post = Post.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    final user = await _fetchUser(post.userId);
    return post.copyWith(user: user);
  }

  // Helper to construct a Comment from a document, fetching the user
  Future<Comment> _buildCommentFromDoc(DocumentSnapshot doc) async {
    final comment = Comment.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    final user = await _fetchUser(comment.userId);
    return comment.copyWith(user: user);
  }

  Stream<List<Post>> getPostsStream() {
    return _firestore
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) => Future.wait(snapshot.docs.map(_buildPostFromDoc)));
  }

  Future<Map<String, dynamic>> getPosts({
      DocumentSnapshot? lastVisible, 
      int limit = 10, 
      String? category, 
      // 🔧 NUEVO: Parámetros para ordenar
      String orderByField = 'timestamp', // Campo por defecto
      bool descending = true, // Dirección por defecto
    }) async {
    var query = _firestore.collection('posts').orderBy('timestamp', descending: true).limit(limit);

    if (lastVisible != null) {
      query = query.startAfterDocument(lastVisible);
    }
    if (category != null && category != "Todos") {
      query = query.where('category', isEqualTo: category);
    }

    final snapshot = await query.get();
    final posts = await Future.wait(snapshot.docs.map(_buildPostFromDoc));

    return {
      'posts': posts,
      'lastVisible': snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
    };
  }

  Future<Post?> getPostFuture(String postId) async {
    final doc = await _firestore.collection('posts').doc(postId).get();
    if (!doc.exists) return null;
    return _buildPostFromDoc(doc);
  }

  Future<void> addPost({required Post post, required File imageFile}) async {
    final docRef = _firestore.collection('posts').doc();
    final imageUrl = await _uploadImageToCloudinary(imageFile);

    // Manually create the map to ensure no nested User object is saved.
    final postData = {
      'userId': post.userId,
      'description': post.description,
      'imageUrl': imageUrl, // Use the URL from storage
      'location': post.location,
      'latitude': post.latitude,
      'longitude': post.longitude,
      'category': post.category,
      'price': post.price,
      'discountPrice': post.discountPrice,
      'store': post.store,
      'timestamp': FieldValue.serverTimestamp(), // Use server timestamp for reliability
      'status': post.status,
      'scores': [],
    };

    await docRef.set(postData);
  }

  Future<void> deletePost(String postId) async {
    await _firestore.collection('posts').doc(postId).delete();
    // Note: Deleting from Cloudinary would require knowing the public_id, 
    // which we are not storing. If needed, this functionality would have to be added.
  }

    Future<void> updatePostDetails({
      required String postId, 
      required String description,
      required double price,
      required double discountPrice,
      required String category,
      required String store
    }) async {
    await _firestore.collection('posts').doc(postId).update({
      'description': description,
      'price': price,
      'discountPrice': discountPrice,
      'category': category,
      'store': store,
    });
  }

  Future<String> _uploadImageToCloudinary(File imageFile) async {
     try {
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(imageFile.path, resourceType: CloudinaryResourceType.Image),
      );
      return response.secureUrl;
    } catch (e) {
      throw Exception('Error al subir la imagen: ${e.toString()}');
    }
  }
  
  Stream<List<Comment>> getCommentsStream(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) => Future.wait(snapshot.docs.map(_buildCommentFromDoc)));
  }

  Stream<List<Comment>> getCommentsForUserStream(String userId) {
  return _firestore
      .collectionGroup('comments')
      .where('userId', isEqualTo: userId)
      .orderBy('timestamp', descending: true)
      .snapshots()
      .asyncMap((snapshot) => Future.wait(snapshot.docs.map(_buildCommentFromDoc)));
  }

  Future<void> addComment({required String postId, required String text, required String userId}) async {
    final commentRef = _firestore.collection('posts').doc(postId).collection('comments').doc();
    final user = await _fetchUser(userId);
    final comment = Comment(
      id: commentRef.id,
      postId: postId,
      userId: userId,
      text: text,
      timestamp: Timestamp.now(),
      user: user, // Attach the fetched user
    );
    await commentRef.set(comment.toMap());
  }

  Future<void> updatePostScore({required String postId, required String userId, required int value}) async {
    final postRef = _firestore.collection('posts').doc(postId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(postRef);
      if (!snapshot.exists) return;
      
      // We work with Maps as Firestore gives us, and then we will update the map
      List<dynamic> scoresRaw = List<dynamic>.from(snapshot.data()?['scores'] ?? []);
      List<Map<String, dynamic>> scores = scoresRaw.map((s) => Map<String, dynamic>.from(s as Map)).toList();

      int existingVoteIndex = scores.indexWhere((s) => s['userId'] == userId);
      
      if (existingVoteIndex != -1) {
        if (scores[existingVoteIndex]['value'] == value) {
          scores.removeAt(existingVoteIndex);
        } else {
          scores[existingVoteIndex]['value'] = value;
        }
      } else {
        scores.add({'userId': userId, 'value': value});
      }
      
      transaction.update(postRef, {'scores': scores});
    });
  }

  Future<List<Post>> getPostsForUser(String userId) async {
    // This query fetches ALL posts for a specific user, ordered by date.
    // It does not use any in-memory list and is not paginated.
    final snapshot = await _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .get();
    // We then build the list of Post objects from the documents.
    return Future.wait(snapshot.docs.map(_buildPostFromDoc));
  }

  Future<List<Post>> getFavoritePosts(List<String> postIds) async {
    if (postIds.isEmpty) return [];

    List<Post> favoritePosts = [];
    // Firestore 'in' query is limited to 30 items per query.
    // We loop through the postIds in chunks of 30.
    for (var i = 0; i < postIds.length; i += 30) {
      final sublist = postIds.sublist(i, i + 30 > postIds.length ? postIds.length : i + 30);
      final snapshot = await _firestore
          .collection('posts')
          .where(FieldPath.documentId, whereIn: sublist)
          .get();
      
      final posts = await Future.wait(snapshot.docs.map((doc) async {
        final post = await _buildPostFromDoc(doc);
        return post;
      }));
      favoritePosts.addAll(posts);
    }
    
    // Sort by timestamp descending, as Firestore 'in' queries don't guarantee order.
    favoritePosts.sort((a, b) {
      if (a.timestamp == null && b.timestamp == null) return 0;
      if (a.timestamp == null) return 1; 
      if (b.timestamp == null) return -1;
      return b.timestamp!.compareTo(a.timestamp!);
    });

    return favoritePosts;
  }
}

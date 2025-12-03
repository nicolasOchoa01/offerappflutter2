import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:myapp/src/domain/entities/comment.dart';
import 'package:myapp/src/domain/entities/post.dart';
import 'package:myapp/src/domain/entities/user.dart';

class PostRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudinaryPublic _cloudinary = CloudinaryPublic('dyloasili', 'ml_default', cache: false);

  Future<User?> _fetchUser(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.exists ? User.fromSnapshot(userDoc) : null;
    } catch (e, s) {
      developer.log('Error fetching user', name: 'PostRepository', error: e, stackTrace: s);
      return null;
    }
  }

  Future<Post> _buildPostFromDoc(DocumentSnapshot doc) async {
    final post = Post.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    final user = await _fetchUser(post.userId);
    return post.copyWith(user: user);
  }

  Future<Comment> _buildCommentFromDoc(DocumentSnapshot doc) async {
    final comment = Comment.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    final user = await _fetchUser(comment.userId);
    return comment.copyWith(user: user);
  }

  Future<Map<String, dynamic>> getPosts({
    DocumentSnapshot? lastVisible,
    int limit = 10,
    String sortOption = 'timestamp_desc',
    String? category, // <-- PARAMETER RESTORED
  }) async {
    Query query = _firestore.collection('posts');

    // Apply category filter first (if it's not "Todos")
    if (category != null && category != "Todos") {
      query = query.where('category', isEqualTo: category);
    }

    // Handle sorting
    final parts = sortOption.split('_');
    final field = parts[0];
    final direction = parts[1];

    String orderByField;
    bool descending;

    switch (field) {
      case 'score':
        orderByField = 'totalScore';
        break;
      case 'price':
        orderByField = 'discountPrice';
        break;
      default: // timestamp
        orderByField = 'timestamp';
    }
    descending = direction == 'desc';

    query = query.orderBy(orderByField, descending: descending);

    // Handle pagination
    if (lastVisible != null) {
      query = query.startAfterDocument(lastVisible);
    }

    query = query.limit(limit);

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

  Future<void> addPost({required Post post, File? imageFile, Uint8List? imageBytes}) async {
    if (imageFile == null && imageBytes == null) {
      throw Exception("Se requiere una imagen para crear el post.");
    }

    final docRef = _firestore.collection('posts').doc();
    String imageUrl;

    if (kIsWeb) {
      if (imageBytes == null) throw Exception("Los bytes de la imagen son requeridos para la web.");
      imageUrl = await _uploadImageBytesToCloudinary(imageBytes, docRef.id);
    } else {
      if (imageFile == null) throw Exception("El archivo de imagen es requerido para móvil.");
      imageUrl = await _uploadImageFileToCloudinary(imageFile);
    }

    final postData = {
      'userId': post.userId,
      'description': post.description,
      'imageUrl': imageUrl,
      'location': post.location,
      'latitude': post.latitude,
      'longitude': post.longitude,
      'category': post.category,
      'price': post.price,
      'discountPrice': post.discountPrice,
      'store': post.store,
      'timestamp': FieldValue.serverTimestamp(),
      'status': post.status,
      'scores': [],
      'totalScore': 0, // Initialize totalScore
    };

    await docRef.set(postData);
  }

  Future<void> deletePost(String postId) async {
    await _firestore.collection('posts').doc(postId).delete();
  }

  Future<void> updatePostDetails({
    required String postId,
    required String description,
    required double price,
    required double discountPrice,
    required String category,
    required String store,
    required String status,
  }) async {
    await _firestore.collection('posts').doc(postId).update({
      'description': description,
      'price': price,
      'discountPrice': discountPrice,
      'category': category,
      'store': store,
      'status': status,
    });
  }

  Future<String> _uploadImageFileToCloudinary(File imageFile) async {
    try {
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(imageFile.path, resourceType: CloudinaryResourceType.Image),
      );
      return response.secureUrl;
    } catch (e) {
      throw Exception('Error al subir la imagen: ${e.toString()}');
    }
  }

  Future<String> _uploadImageBytesToCloudinary(Uint8List imageBytes, String publicId) async {
    try {
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromBytesData(imageBytes, identifier: publicId, resourceType: CloudinaryResourceType.Image),
        uploadPreset: 'ml_default',
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
      user: user,
    );
    await commentRef.set(comment.toMap());
  }

  Future<void> updatePostScore({required String postId, required String userId, required int value}) async {
    final postRef = _firestore.collection('posts').doc(postId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(postRef);
      if (!snapshot.exists) return;

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

      // Recalculate and update totalScore
      int totalScore = scores.fold(0, (sum, item) => sum + (item['value'] as int));

      transaction.update(postRef, {
        'scores': scores,
        'totalScore': totalScore,
      });
    });
  }

  Future<List<Post>> getPostsForUser(String userId) async {
    final snapshot = await _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .get();
    return Future.wait(snapshot.docs.map(_buildPostFromDoc));
  }

    Future<List<Post>> getFavoritePosts(List<String> postIds) async {
    if (postIds.isEmpty) return [];

    // Firestore 'in' query limit is 30
    List<Post> favoritePosts = [];
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
    
    // Sort locally by timestamp after fetching
    favoritePosts.sort((a, b) {
      if (a.timestamp == null && b.timestamp == null) return 0;
      if (a.timestamp == null) return 1; 
      if (b.timestamp == null) return -1;
      return b.timestamp!.compareTo(a.timestamp!);
    });

    return favoritePosts;
  }
}

import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:myapp/src/domain/entities/comment.dart';
import 'package:myapp/src/domain/entities/post.dart';
import 'package:myapp/src/domain/entities/score.dart';

class PostRepository {
  final FirebaseFirestore _firestore;
  final CloudinaryPublic _cloudinary;

  PostRepository({
    FirebaseFirestore? firestore,
    CloudinaryPublic? cloudinary,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _cloudinary = cloudinary ??
            CloudinaryPublic('CLOUDINARY_CLOUD_NAME', 'unsigned-upload-preset',
                cache: false);

  CollectionReference<Post> get _postsCollection =>
      _firestore.collection('posts').withConverter<Post>(
            fromFirestore: (snapshot, _) =>
                Post.fromMap(snapshot.data()!, snapshot.id),
            toFirestore: (post, _) => post.toMap(),
          );

  Stream<Post> getPostStream(String postId) {
    return _postsCollection
        .doc(postId)
        .snapshots()
        .map((snapshot) => snapshot.data()!);
  }

  Stream<List<Post>> getPostsStream({String? category}) {
    Query<Post> query = _postsCollection.orderBy('timestamp', descending: true);

    if (category != null && category != "Todos") {
      query = query.where('category', isEqualTo: category);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<void> addPost({required Post post, required File imageFile}) async {
    try {
      final imageUrl = await _uploadImageToCloudinary(imageFile);
      final newPost = post.copyWith(imageUrl: imageUrl, timestamp: Timestamp.now());
      await _postsCollection.add(newPost);
    } catch (e) {
      throw Exception('Error al añadir la publicación: ${e.toString()}');
    }
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

  Future<void> updatePostScore(
      {required String postId, required String userId, required int value}) async {
    final postRef = _postsCollection.doc(postId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(postRef);
      if (!snapshot.exists) {
        throw Exception("La publicación no fue encontrada.");
      }

      final post = snapshot.data()!;
      if (post.status != "activa") {
        throw Exception("La publicación no está activa, no se puede cambiar la puntuación.");
      }

      final newScores = List<Score>.from(post.scores);
      final existingScoreIndex = newScores.indexWhere((s) => s.userId == userId);

      if (existingScoreIndex != -1) {
        if (newScores[existingScoreIndex].value == value) {
          newScores.removeAt(existingScoreIndex);
        } else {
          newScores[existingScoreIndex] = newScores[existingScoreIndex].copyWith(value: value);
        }
      } else {
        newScores.add(Score(userId: userId, value: value));
      }

      transaction.update(postRef, {'scores': newScores.map((s) => s.toMap()).toList()});

      final totalScore = newScores.fold<int>(0, (total, item) => total + item.value);
      if (totalScore < -15) {
        transaction.update(postRef, {'status': 'vencida'});
      }
    });
  }

  Future<void> addCommentToPost({required String postId, required Comment comment}) async {
    final commentWithTimestamp = comment.copyWith(timestamp: Timestamp.now());
    await _postsCollection.doc(postId).collection('comments').add(commentWithTimestamp.toMap());
  }

  Stream<List<Comment>> getCommentsForPost(String postId) {
    return _postsCollection
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Comment.fromMap(doc.data(), doc.id)).toList());
  }

  Stream<List<Comment>> getCommentsByUser(String userId) {
    return _firestore
        .collectionGroup('comments')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Comment.fromMap(doc.data(), doc.id)).toList());
  }

  Future<(List<Post>, DocumentSnapshot?)> getPosts({
    DocumentSnapshot? lastVisiblePost,
    String? category,
  }) async {
    const limit = 10;
    Query<Post> query = _postsCollection;

    if (category != null && category != "Todos") {
      query = query.where('category', isEqualTo: category);
    }

    query = query.orderBy('timestamp', descending: true).limit(limit);

    if (lastVisiblePost != null) {
      query = query.startAfterDocument(lastVisiblePost);
    }

    final snapshot = await query.get();
    final posts = snapshot.docs.map((doc) => doc.data()).toList();
    final newLastVisible = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

    return (posts, newLastVisible);
  }

  Future<Post?> getPostById(String postId) async {
    final doc = await _postsCollection.doc(postId).get();
    return doc.data();
  }

  Future<void> deletePost(String postId) async {
    final postRef = _postsCollection.doc(postId);
    final batch = _firestore.batch();

    var commentsSnapshot = await postRef.collection('comments').get();
    for (var doc in commentsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(postRef);

    await batch.commit();
  }

  Future<void> expireOldPosts() async {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final cutoffDate = Timestamp.fromDate(thirtyDaysAgo);

    final querySnapshot = await _postsCollection
        .where('timestamp', isLessThan: cutoffDate)
        .where('status', isEqualTo: 'activa')
        .get();

    final batch = _firestore.batch();
    for (final document in querySnapshot.docs) {
      batch.update(document.reference, {'status': 'vencida'});
    }
    await batch.commit();
  }

  Future<void> updatePostStatus(String postId, String newStatus) async {
    await _postsCollection.doc(postId).update({'status': newStatus});
  }

  Future<void> updatePostDetails({
    required String postId,
    required String description,
    required double price,
    required double discountPrice,
    required String category,
    required String store,
  }) async {
    final updates = {
      'description': description,
      'price': price,
      'discountPrice': discountPrice,
      'category': category,
      'store': store,
    };
    await _postsCollection.doc(postId).update(updates);
  }

  Future<List<Post>> getFilteredPosts({
    String status = "Todos",
    String category = "Todos",
    String sortOption = "Fecha (más recientes)",
  }) async {
    Query<Post> query = _postsCollection;

    if (status != "Todos") {
      query = query.where('status', isEqualTo: status.toLowerCase());
    }
    if (category != "Todos") {
      query = query.where('category', isEqualTo: category);
    }

    switch (sortOption) {
      case "Precio (menor a mayor)":
        query = query.orderBy('price', descending: false);
        break;
      case "Precio (mayor a menor)":
        query = query.orderBy('price', descending: true);
        break;
      case "Fecha (más recientes)":
      default:
        query = query.orderBy('timestamp', descending: true);
    }

    final snapshot = await query.get();
    var posts = snapshot.docs.map((doc) => doc.data()).toList();

    if (sortOption == "Puntaje") {
      posts.sort((a, b) {
        final scoreA = a.scores.fold<int>(0, (total, s) => total + s.value);
        final scoreB = b.scores.fold<int>(0, (total, s) => total + s.value);
        return scoreB.compareTo(scoreA);
      });
    }

    return posts;
  }
}

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:myapp/src/domain/entities/comment.dart';
import 'package:myapp/src/domain/entities/post.dart';
import 'package:myapp/src/domain/entities/score.dart';
import 'package:myapp/src/domain/entities/user.dart';

class PostRepository {
  final FirebaseFirestore _firestore;
  final CloudinaryPublic _cloudinary;

  PostRepository({
    FirebaseFirestore? firestore,
    CloudinaryPublic? cloudinary,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _cloudinary = cloudinary ?? CloudinaryPublic('dextwzsqv', 'unsigned-upload-preset', cache: false);

  CollectionReference<Post> get _postsCollection =>
      _firestore.collection('posts').withConverter<Post>(
            fromFirestore: (snapshot, _) => Post.fromMap(snapshot.data()!, snapshot.id),
            toFirestore: (post, _) => post.toMap(),
          );

  Future<String> _uploadImageToCloudinary(File imageFile) async {
    try {
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(imageFile.path, resourceType: CloudinaryResourceType.Image),
      );
      return response.secureUrl;
    } catch (e) {
      throw Exception('Error al subir la imagen a Cloudinary: ${e.toString()}');
    }
  }

  Future<void> addPost({required Post post, required File imageFile}) async {
    try {
      final imageUrl = await _uploadImageToCloudinary(imageFile);
      final newPost = post.copyWith(imageUrl: imageUrl);
      await _postsCollection.add(newPost);
    } catch (e) {
      throw Exception('Error al añadir el post: ${e.toString()}');
    }
  }

  Future<void> updatePostScore({required String postId, required String userId, required int value}) async {
    try {
      final postRef = _postsCollection.doc(postId);
      await _firestore.runTransaction((transaction) async {
        final postSnapshot = await transaction.get(postRef);
        final post = postSnapshot.data();
        if (post == null) throw Exception("Post no encontrado");

        if (post.status != "activa") {
          throw Exception("El post no está activo, no se puede cambiar la puntuación.");
        }

        final newScores = List<Score>.from(post.scores);
        final existingScoreIndex = newScores.indexWhere((s) => s.userId == userId);

        if (existingScoreIndex != -1) {
          if (newScores[existingScoreIndex].value == value) {
            newScores.removeAt(existingScoreIndex); // User removes their vote
          } else {
            newScores[existingScoreIndex] = Score(userId: userId, value: value); // User changes vote
          }
        } else {
          newScores.add(Score(userId: userId, value: value)); // New vote
        }

        transaction.update(postRef, {'scores': newScores.map((s) => s.toMap()).toList()});

        final totalScore = newScores.fold<int>(0, (total, score) => total + score.value);
        if (totalScore < -15) {
          transaction.update(postRef, {'status': "vencida"});
        }
      });
    } catch (e) {
      throw Exception('Error al actualizar la puntuación: ${e.toString()}');
    }
  }

  Future<void> addComment(
      {required String postId, required String text, required String userId, required User user}) async {
    try {
      final comment = Comment(
        id: '', // Firestore will generate it
        postId: postId,
        userId: userId,
        user: user,
        text: text,
        timestamp: Timestamp.now(),
      );
      await _postsCollection
          .doc(postId)
          .collection('comments')
          .add(comment.toMap());
    } catch (e) {
      throw Exception('Error al añadir el comentario: ${e.toString()}');
    }
  }


  Stream<List<Comment>> getCommentsStream(String postId) {
    return _postsCollection
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Comment.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  Stream<List<Comment>> getCommentsForPost(String postId) {
     return getCommentsStream(postId);
  }

   Future<void> addCommentToPost({required String postId, required Comment comment}) async {
    try {
       await _postsCollection
          .doc(postId)
          .collection('comments')
          .add(comment.toMap());
    } catch (e) {
        throw Exception('Error al añadir el comentario: ${e.toString()}');
    }
  }
  
  Future<Post?> getPostFuture(String postId) async {
    try {
      final doc = await _postsCollection.doc(postId).get();
      return doc.data();
    } catch (e) {
      developer.log('Error fetching post: $e', name: 'PostRepository');
      return null;
    }
  }


  Future<void> deletePost(String postId) async {
    try {
      final commentsQuery = await _postsCollection.doc(postId).collection('comments').get();
      final WriteBatch batch = _firestore.batch();

      for (var doc in commentsQuery.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      await _postsCollection.doc(postId).delete();
    } catch (e) {
      throw Exception('Error al eliminar el post: ${e.toString()}');
    }
  }

    Future<Map<String, dynamic>> getPosts({
    DocumentSnapshot? lastVisible,
    String? category,
  }) async {
    var query = _postsCollection.orderBy('timestamp', descending: true);

    if (category != null && category != "Todos") {
      query = query.where('category', isEqualTo: category);
    }

    if (lastVisible != null) {
      query = query.startAfterDocument(lastVisible);
    }

    final snapshot = await query.limit(10).get();
    final posts = snapshot.docs.map((doc) => doc.data()).toList();
    final newLastVisible = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

    return {
      'posts': posts,
      'lastVisible': newLastVisible,
    };
  }

   Future<void> updatePostDetails(
      {required String postId,
      required String description,
      required double price,
      required double discountPrice,
      required String category,
      required String store}) async {
    try {
      final updates = {
        "description": description,
        "price": price,
        "discountPrice": discountPrice,
        "category": category,
        "store": store
      };
      await _postsCollection.doc(postId).update(updates);
    } catch (e) {
      throw Exception("Error al actualizar los detalles del post: ${e.toString()}");
    }
  }

  Future<void> updatePostStatus({required String postId, required String newStatus}) async {
    try {
      await _postsCollection.doc(postId).update({'status': newStatus});
    } catch (e) {
      throw Exception("Error al actualizar el estado del post: ${e.toString()}");
    }
  }
}

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

// ... código anterior
// post_repository.dart
// ...
// post_repository.dart

// ... (código anterior)

  Future<Map<String, dynamic>> getPosts({
    DocumentSnapshot? lastVisible, 
    int limit = 10, 
      String? category,
      String orderByField = 'timestamp', 
      bool descending = true,
      // 🆕 NUEVOS PARÁMETROS DE FILTRO
      double? minPrice,
      double? maxPrice,
      String? promoType, // e.g., '2x1', '50% OFF', 'Liquidación'
      String? status, // e.g., 'ACTIVA' o 'LIQUIDACION' (o como lo manejes)
      String? store, // Asumo que el filtro por marca es por 'store'
    }) async {

    // 1. Definición de la consulta base
    var query = _firestore.collection('posts').limit(limit);

    // 2. Aplicar filtros WHERE
    // Filtro de categoría
    if (category != null && category != "Todos") {
      query = query.where('category', isEqualTo: category);
    }
    // Filtro por tienda/marca
    if (store != null && store != "Todas") {
      query = query.where('store', isEqualTo: store);
    }
    // Filtro por Tipo de Promoción (Si el campo existe y es filtrable)
    if (promoType != null && promoType != "Todos") {
      // Se asume que tienes un campo en Post llamado 'promoType' con el valor '2x1', '50% OFF', etc.
    query = query.where('promoType', isEqualTo: promoType);
    }
    // Filtro por estado del post (Liquidación/Activa)
    if (status != null && status != "Todos") {
      query = query.where('status', isEqualTo: status);
    }

    // 3. Aplicar ordenamiento y rango de precios (requiere el mismo campo)
    // Si estamos ordenando por precio, aplicamos el rango aquí.
    if (orderByField == 'discountPrice') {
    // Si se usa rango de precios, el orderByField DEBE SER 'discountPrice'
      if (minPrice != null) {
      query = query.where('discountPrice', isGreaterThanOrEqualTo: minPrice);
      }
    if (maxPrice != null) {
      query = query.where('discountPrice', isLessThanOrEqualTo: maxPrice);
    }
     // Aplicamos el ordenamiento por precio
      query = query.orderBy('discountPrice', descending: descending);
      // Si tenemos un índice compuesto, podemos agregar otro ordenamiento, 
      // pero por ahora, respetamos la limitación de un solo campo para where y order

  } else {
    // Si no estamos ordenando por precio, ordenamos por el campo elegido.
    // IMPORTANTE: Si usas rango de precios y no ordenas por 'discountPrice', 
    // Firestore te requerirá crear un índice compuesto, y el orderByField 
    // DEBE coincidir con los campos de tu filtro 'where' (si los hay). 
    // Para simplificar, asumimos que si hay rango, ordenamos por precio.
    query = query.orderBy(orderByField, descending: descending);
    }


   // 4. Paginación
  if (lastVisible != null) {
    query = query.startAfterDocument(lastVisible);
    }

    final snapshot = await query.get();
    final posts = await Future.wait(snapshot.docs.map(_buildPostFromDoc));

    return {
      'posts': posts,
      'lastVisible': snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
    };
  }

// ... (resto del código)

// ... resto del código

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

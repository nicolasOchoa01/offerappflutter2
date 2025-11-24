import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:myapp/src/domain/entities/user.dart';

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository({FirebaseFirestore? firestore}) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<User> get _usersCollection => _firestore.collection('users').withConverter<User>(
    fromFirestore: (snapshot, _) => User.fromMap(snapshot.data()!),
    toFirestore: (user, _) => user.toMap(),
  );

  Stream<User?> getUserStream(String userId) {
    return _usersCollection.doc(userId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return snapshot.data();
      }
      return null;
    });
  }

  Future<void> toggleFavorite(String userId, String postId) async {
    final userRef = _usersCollection.doc(userId);

    try {
      final doc = await userRef.get();
      if (doc.exists) {
        final user = doc.data()!;
        List<String> favorites = List.from(user.favorites);

        if (favorites.contains(postId)) {
          userRef.update({
            'favorites': FieldValue.arrayRemove([postId])
          });
        } else {
          userRef.update({
            'favorites': FieldValue.arrayUnion([postId])
          });
        }
      } else {
        log("El usuario con ID $userId no fue encontrado.", name: 'UserRepository');
      }
    } catch (e, s) {
      log("Error al actualizar los favoritos", error: e, stackTrace: s, name: 'UserRepository');
      throw Exception('Error al actualizar los favoritos.');
    }
  }
}

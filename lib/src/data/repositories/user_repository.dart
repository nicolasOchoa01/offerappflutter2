import 'dart:developer';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:myapp/src/domain/entities/user.dart';

class UserRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  UserRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  CollectionReference<User> get _usersCollection =>
      _firestore.collection('users').withConverter<User>(
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

  Future<void> updateProfilePicture(String userId, String imagePath) async {
    try {
      final file = File(imagePath);
      // Create a reference to the location you want to upload to in Firebase Storage
      final ref = _storage.ref('profile_pictures/$userId');

      // Upload the file
      final uploadTask = await ref.putFile(file);

      // Get the download URL
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Update the user's profileImageUrl in Firestore
      await _usersCollection.doc(userId).update({'profileImageUrl': downloadUrl});
    } catch (e, s) {
      log("Error al actualizar la foto de perfil", error: e, stackTrace: s, name: 'UserRepository');
      throw Exception('Error al actualizar la foto de perfil.');
    }
  }

  Future<void> followUser(String currentUserId, String targetUserId) async {
    try {
      final currentUserRef = _usersCollection.doc(currentUserId);
      final targetUserRef = _usersCollection.doc(targetUserId);

      await _firestore.runTransaction((transaction) async {
        // Add target to current user's following list
        transaction.update(currentUserRef, {
          'following': FieldValue.arrayUnion([targetUserId])
        });
        // Add current user to target's followers list
        transaction.update(targetUserRef, {
          'followers': FieldValue.arrayUnion([currentUserId])
        });
      });
    } catch (e, s) {
      log("Error al seguir al usuario", error: e, stackTrace: s, name: 'UserRepository');
      throw Exception('Error al seguir al usuario.');
    }
  }

  Future<void> unfollowUser(String currentUserId, String targetUserId) async {
    try {
      final currentUserRef = _usersCollection.doc(currentUserId);
      final targetUserRef = _usersCollection.doc(targetUserId);

      await _firestore.runTransaction((transaction) async {
        // Remove target from current user's following list
        transaction.update(currentUserRef, {
          'following': FieldValue.arrayRemove([targetUserId])
        });
        // Remove current user from target's followers list
        transaction.update(targetUserRef, {
          'followers': FieldValue.arrayRemove([currentUserId])
        });
      });
    } catch (e, s) {
      log("Error al dejar de seguir al usuario", error: e, stackTrace: s, name: 'UserRepository');
      throw Exception('Error al dejar de seguir al usuario.');
    }
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

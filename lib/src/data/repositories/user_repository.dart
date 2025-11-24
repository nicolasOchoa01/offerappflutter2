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
            fromFirestore: (snapshot, _) => User.fromSnapshot(snapshot),
            toFirestore: (user, _) => user.toMap(),
          );

  Stream<User?> getUserStream(String userId) {
    if (userId.isEmpty) {
      return Stream.value(null);
    }
    return _usersCollection.doc(userId).snapshots().map((snapshot) {
      if (snapshot.exists) {
        return snapshot.data();
      }
      return null;
    });
  }

  Future<void> createUser(User user) async {
    await _usersCollection.doc(user.id).set(user);
  }

  Future<void> updateUser(User user) async {
    await _usersCollection.doc(user.id).update(user.toMap());
  }

  Future<void> updateProfilePicture(String userId, String imagePath) async {
    final file = File(imagePath);
    final ref = _storage.ref('profile_pictures/$userId.jpg');
    await ref.putFile(file);
    final url = await ref.getDownloadURL();
    await _usersCollection.doc(userId).update({'profileImageUrl': url});
  }

  Future<void> followUser(String currentUserId, String userIdToFollow) async {
    await _firestore.runTransaction((transaction) async {
      transaction.update(_usersCollection.doc(currentUserId), {
        'following': FieldValue.arrayUnion([userIdToFollow])
      });
      transaction.update(_usersCollection.doc(userIdToFollow), {
        'followers': FieldValue.arrayUnion([currentUserId])
      });
    });
  }

  Future<void> unfollowUser(String currentUserId, String userIdToUnfollow) async {
    await _firestore.runTransaction((transaction) async {
      transaction.update(_usersCollection.doc(currentUserId), {
        'following': FieldValue.arrayRemove([userIdToUnfollow])
      });
      transaction.update(_usersCollection.doc(userIdToUnfollow), {
        'followers': FieldValue.arrayRemove([currentUserId])
      });
    });
  }

  Future<void> toggleFavorite(String userId, String postId, bool isCurrentlyFavorited) async {
    await _usersCollection.doc(userId).update({
      'favorites': isCurrentlyFavorited
          ? FieldValue.arrayRemove([postId])
          : FieldValue.arrayUnion([postId]),
    });
  }
}

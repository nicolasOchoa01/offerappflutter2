import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:myapp/src/core/utils/firebase_auth_error_handler.dart';
import 'package:myapp/src/data/services/firebase_auth_service.dart';
import 'package:myapp/src/domain/entities/user.dart';

class AuthRepository {
  final firebase_auth.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final CloudinaryPublic _cloudinary;
  final FirebaseAuthService _authService;

  AuthRepository({
    firebase_auth.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    CloudinaryPublic? cloudinary,
    FirebaseAuthService? authService,
  })  : _auth = auth ?? firebase_auth.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _cloudinary = cloudinary ??
            CloudinaryPublic('dyloasili', 'ml_default', cache: false),
        _authService = authService ?? FirebaseAuthService();

  CollectionReference<User> get _usersCollection =>
      _firestore.collection('users').withConverter<User>(
            fromFirestore: (snapshot, _) => User.fromSnapshot(snapshot),
            toFirestore: (user, _) => user.toMap(),
          );

  firebase_auth.User? get currentUser => _auth.currentUser;

  Future<firebase_auth.User?> registerUser(
      {required String email, required String password, required String username}) async {
    try {
      final usernameQuery = await _usersCollection
          .where('username', isEqualTo: username)
          .get();
      if (usernameQuery.docs.isNotEmpty) {
        throw firebase_auth.FirebaseAuthException(code: 'username-already-in-use');
      }

      final result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      final firebaseUser = result.user;
      if (firebaseUser == null) {
        throw Exception(
            'Error de registro: no se pudo obtener la información del usuario.');
      }

      final user = User(
        id: firebaseUser.uid,
        username: username,
        email: email,
      );
      await _usersCollection.doc(firebaseUser.uid).set(user);

      return firebaseUser;
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw Exception(FirebaseAuthErrorHandler.getErrorMessage(e));
    } catch (e) {
      throw Exception(FirebaseAuthErrorHandler.getGeneralErrorMessage(e as Exception));
    }
  }

  Future<firebase_auth.User?> loginUser(
      {required String identifier, required String password}) async {
    try {
      String email = identifier;
      if (!identifier.contains('@')) {
        final query = await _usersCollection
            .where('username', isEqualTo: identifier)
            .limit(1)
            .get();
        if (query.docs.isEmpty) {
          throw firebase_auth.FirebaseAuthException(code: 'username-not-found');
        }
        final user = query.docs.first.data();
        email = user.email;
      }

      final result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return result.user;
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw Exception(FirebaseAuthErrorHandler.getErrorMessage(e));
    } catch (e) {
      throw Exception(FirebaseAuthErrorHandler.getGeneralErrorMessage(e as Exception));
    }
  }

  Future<User?> getUser(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  Future<List<User>> getUsers(List<String> userIds) async {
    if (userIds.isEmpty) {
      return [];
    }
    try {
      final querySnapshot = await _usersCollection.where(FieldPath.documentId, whereIn: userIds).get();
      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      return [];
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

  Future<String> updateUserProfileImage({required String uid, required File imageFile}) async {
    try {
      final imageUrl = await _uploadImageToCloudinary(imageFile);
      await _usersCollection.doc(uid).update({'profileImageUrl': imageUrl});
      return imageUrl;
    } catch (e) {
      throw Exception('Error al actualizar la imagen de perfil: ${e.toString()}');
    }
  }

  Future<void> resetPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw Exception(FirebaseAuthErrorHandler.getErrorMessage(e));
    } catch (e) {
      throw Exception(FirebaseAuthErrorHandler.getGeneralErrorMessage(e as Exception));
    }
  }

  Future<void> logout() async => await _auth.signOut();

  Future<void> followUser({required String followerId, required String followingId}) async {
    try {
      final followerRef = _usersCollection.doc(followerId);
      final followingRef = _usersCollection.doc(followingId);

      await _firestore.runTransaction((transaction) async {
        transaction.update(followerRef, {'following': FieldValue.arrayUnion([followingId])});
        transaction.update(followingRef, {'followers': FieldValue.arrayUnion([followerId])});
      });
    } catch (e) {
      throw Exception('Error al seguir al usuario: ${e.toString()}');
    }
  }

  Future<void> unfollowUser({required String followerId, required String followingId}) async {
    try {
      final followerRef = _usersCollection.doc(followerId);
      final followingRef = _usersCollection.doc(followingId);

      await _firestore.runTransaction((transaction) async {
        transaction.update(followerRef, {'following': FieldValue.arrayRemove([followingId])});
        transaction.update(followingRef, {'followers': FieldValue.arrayRemove([followerId])});
      });
    } catch (e) {
      throw Exception('Error al dejar de seguir al usuario: ${e.toString()}');
    }
  }

  Future<void> addFavorite({required String userId, required String postId}) async {
    try {
      await _usersCollection.doc(userId).update({'favorites': FieldValue.arrayUnion([postId])});
    } catch (e) {
      throw Exception('Error al añadir a favoritos: ${e.toString()}');
    }
  }

  Future<void> removeFavorite({required String userId, required String postId}) async {
    try {
      await _usersCollection.doc(userId).update({'favorites': FieldValue.arrayRemove([postId])});
    } catch (e) {
      throw Exception('Error al quitar de favoritos: ${e.toString()}');
    }
  }

  Future<void> updateFCMToken({required String userId, required String token}) async {
    try {
      await _authService.updateFCMToken(userId, token);
    } catch (e) {
      // The service itself might handle logging, but we can rethrow or handle as needed.
      throw Exception('Error al actualizar el token FCM: ${e.toString()}');
    }
  }
}

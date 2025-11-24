import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:myapp/src/domain/entities/user.dart' as app_user;

class AuthRepository {
  final auth.FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final CloudinaryPublic _cloudinary;

  AuthRepository({
    auth.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    CloudinaryPublic? cloudinary,
  })  : _firebaseAuth = firebaseAuth ?? auth.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        // TODO: Reemplaza 'CLOUDINARY_CLOUD_NAME' con tu Cloud Name de Cloudinary.
        // TODO: Reemplaza 'unsigned-upload-preset' con el nombre de tu "Upload Preset" de Cloudinary.
        //       Este debe ser un preset de subida SIN FIRMA (unsigned).
        _cloudinary = cloudinary ?? CloudinaryPublic('CLOUDINARY_CLOUD_NAME', 'unsigned-upload-preset', cache: false);

  // Colección de usuarios con un conversor para la clase User
  CollectionReference<app_user.User> get _usersCollection =>
      _firestore.collection('users').withConverter<app_user.User>(
            fromFirestore: (snapshot, _) => app_user.User.fromMap(snapshot.data()!),
            toFirestore: (user, _) => user.toMap(),
          );

  // Obtener el usuario actual de Firebase
  auth.User? get currentUser => _firebaseAuth.currentUser;

  // Stream para escuchar los cambios en el estado de autenticación
  Stream<auth.User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Registrar un nuevo usuario
  Future<void> registerUser({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final usernameQuery = await _usersCollection
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (usernameQuery.docs.isNotEmpty) {
        throw Exception('El nombre de usuario ya está en uso.');
      }

      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        throw Exception('Error de registro: no se pudo obtener la información del usuario.');
      }

      final newUser = app_user.User(
        uid: firebaseUser.uid,
        username: username,
        email: email,
      );
      await _usersCollection.doc(firebaseUser.uid).set(newUser);
    } on auth.FirebaseAuthException catch (e) {
      throw Exception(_handleFirebaseAuthError(e));
    } catch (e) {
      rethrow;
    }
  }

  // Iniciar sesión con email o nombre de usuario
  Future<void> loginUser({
    required String identifier,
    required String password,
  }) async {
    try {
      String email = identifier;
      if (!identifier.contains('@')) {
        final query = await _usersCollection
            .where('username', isEqualTo: identifier)
            .limit(1)
            .get();
        if (query.docs.isEmpty) {
          throw Exception('Nombre de usuario no encontrado.');
        }
        final user = query.docs.first.data();
        email = user.email;
      }
      await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
    } on auth.FirebaseAuthException catch (e) {
      throw Exception(_handleFirebaseAuthError(e));
    } catch (e) {
      rethrow;
    }
  }

  // Obtener un usuario por su UID
  Future<app_user.User?> getUser(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  // Obtener una lista de usuarios por sus UIDs
  Future<List<app_user.User>> getUsers(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    try {
      final querySnapshot = await _usersCollection.where(FieldPath.documentId, whereIn: userIds).get();
      return querySnapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      return [];
    }
  }

  // Actualizar la imagen de perfil del usuario
  Future<String> updateUserProfileImage({required String uid, required File imageFile}) async {
    try {
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(imageFile.path, resourceType: CloudinaryResourceType.Image),
      );
      final imageUrl = response.secureUrl;
      await _firestore.collection('users').doc(uid).update({'profileImageUrl': imageUrl});
      return imageUrl;
    } catch (e) {
      throw Exception('Error al actualizar la imagen de perfil: ${e.toString()}');
    }
  }

  // Enviar correo para restablecer la contraseña
  Future<void> resetPassword(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on auth.FirebaseAuthException catch (e) {
      throw Exception(_handleFirebaseAuthError(e));
    }
  }

  // Cerrar sesión
  Future<void> logout() async {
    await _firebaseAuth.signOut();
  }

  // Seguir a un usuario
  Future<void> followUser(String followerId, String followingId) async {
    final followerRef = _firestore.collection('users').doc(followerId);
    final followingRef = _firestore.collection('users').doc(followingId);

    await _firestore.runTransaction((transaction) async {
      transaction.update(followerRef, {'following': FieldValue.arrayUnion([followingId])});
      transaction.update(followingRef, {'followers': FieldValue.arrayUnion([followerId])});
    });
  }

  // Dejar de seguir a un usuario
  Future<void> unfollowUser(String followerId, String followingId) async {
    final followerRef = _firestore.collection('users').doc(followerId);
    final followingRef = _firestore.collection('users').doc(followingId);

    await _firestore.runTransaction((transaction) async {
      transaction.update(followerRef, {'following': FieldValue.arrayRemove([followingId])});
      transaction.update(followingRef, {'followers': FieldValue.arrayRemove([followerId])});
    });
  }

  // Añadir una publicación a favoritos
  Future<void> addFavorite(String userId, String postId) async {
    await _firestore.collection('users').doc(userId).update({'favorites': FieldValue.arrayUnion([postId])});
  }

  // Quitar una publicación de favoritos
  Future<void> removeFavorite(String userId, String postId) async {
    await _firestore.collection('users').doc(userId).update({'favorites': FieldValue.arrayRemove([postId])});
  }

  // Actualizar el token de FCM
  Future<void> updateFCMToken(String userId, String token) async {
    try {
        await _firestore.collection('users').doc(userId).update({'fcmToken': token});
    } catch (e) {
        print('Error updating FCM token: $e');
        throw Exception('Failed to update FCM token.');
    }
  }

  // Manejador simple de errores de FirebaseAuth
  String _handleFirebaseAuthError(auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'La contraseña es demasiado débil.';
      case 'email-already-in-use':
        return 'El correo electrónico ya está en uso.';
      case 'user-not-found':
        return 'No se encontró ningún usuario con ese correo electrónico.';
      case 'wrong-password':
        return 'Contraseña incorrecta.';
      case 'invalid-email':
         return 'El formato del correo electrónico es inválido.';
      default:
        return 'Ocurrió un error de autenticación. Por favor, inténtelo de nuevo.';
    }
  }
}

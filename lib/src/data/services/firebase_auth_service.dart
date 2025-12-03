import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  FirebaseAuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  // Stream que notifica sobre los cambios en el estado de autenticación del usuario.
  // Es el mecanismo principal para saber si el usuario ha iniciado o cerrado sesión.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Obtiene el usuario actualmente autenticado.
  User? get currentUser => _auth.currentUser;

  // Cierra la sesión del usuario actual.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      // En una app real, considera registrar este error en un servicio de monitoreo.
      print('Error al cerrar sesión en FirebaseAuthService: $e');
      // Relanzar el error permite que las capas superiores (como el repositor) lo manejen.
      rethrow;
    }
  }

  // Actualiza el token de FCM (Firebase Cloud Messaging) para notificaciones push.
  Future<void> updateFCMToken(String userId, String? token) async {
    if (token == null) return; // No hacer nada si el token es nulo

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .update({'fcmToken': token});
    } catch (e) {
      print('Error al actualizar el token FCM: $e');
      rethrow; 
    }
  }
}

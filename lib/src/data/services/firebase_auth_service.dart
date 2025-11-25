import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseAuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> updateFCMToken(String userId, String token) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .update({'fcmToken': token});
    } catch (e) {
      // En una aplicación real, podrías querer manejar este error de forma más robusta.
      // Por ejemplo, registrar el error en un servicio de monitoreo.
      print('Error al actualizar el token FCM: $e');
      rethrow; // Relanzar para que el llamador pueda manejarlo si es necesario.
    }
  }
}

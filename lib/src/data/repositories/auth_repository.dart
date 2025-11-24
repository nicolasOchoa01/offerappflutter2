import 'dart:async';
import 'dart:developer';
import 'package:myapp/src/domain/entities/user.dart';

// Repositorio de marcador de posición para la autenticación.
// En una aplicación real, esto interactuaría con Firebase Auth, Google Sign-In, etc.
class AuthRepository {
  // Stream que emite el estado del usuario actual.
  // Por ahora, emite un usuario de prueba después de un breve retraso.
  Stream<User?> get onAuthStateChanged {
    return Stream.value(
      const User(
        uid: 'dummy_uid',
        username: 'DummyUser',
        email: 'user@example.com',
        profileImageUrl: 'https://i.pravatar.cc/150?u=dummy_uid',
        favorites: [], // Inicialmente sin favoritos
      ),
    );
  }

  // Devuelve el usuario actual (sincrónicamente, solo para este ejemplo)
  User? get currentUser {
    return const User(
      uid: 'dummy_uid',
      username: 'DummyUser',
      email: 'user@example.com',
      profileImageUrl: 'https://i.pravatar.cc/150?u=dummy_uid',
      favorites: [],
    );
  }

  // Método para iniciar sesión (simulado)
  Future<void> signIn() async {
    // Lógica de inicio de sesión simulada
    log('Iniciando sesión...', name: 'AuthRepository');
  }

  // Método para cerrar sesión (simulado)
  Future<void> signOut() async {
    // Lógica de cierre de sesión simulada
    log('Cerrando sesión...', name: 'AuthRepository');
  }
}

import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthErrorHandler {
  static String getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'El formato del correo electrónico es incorrecto.';
      case 'user-not-found':
        return 'No se encontró ningún usuario con estas credenciales.';
      case 'wrong-password':
        return 'La contraseña es incorrecta.';
      case 'email-already-in-use':
        return 'El correo electrónico ya está registrado por otro usuario.';
      case 'weak-password':
        return 'La contraseña es demasiado débil. Debe tener al menos 6 caracteres.';
      case 'user-disabled':
        return 'La cuenta de usuario ha sido deshabilitada.';
      case 'too-many-requests':
        return 'Demasiados intentos fallidos. Inténtalo de nuevo más tarde.';
      case 'operation-not-allowed':
        return 'El inicio de sesión con correo y contraseña no está habilitado.';
      // Custom exception from our repository logic
      case 'username-already-in-use':
         return 'El nombre de usuario ya está en uso.';
      case 'username-not-found':
         return 'Nombre de usuario no encontrado.';
      default:
        return 'Ocurrió un error inesperado. Por favor, inténtalo de nuevo.';
    }
  }

  // You can also add a method for other types of exceptions if needed
  static String getGeneralErrorMessage(Exception e) {
     if (e is FirebaseAuthException) {
      return getErrorMessage(e);
    }
    // Handle custom exception messages thrown from the repository
    final message = e.toString();
    if (message.startsWith("Exception: ")) {
      return message.substring(11); // Remove "Exception: " part
    }
    return 'Ocurrió un error inesperado. Por favor, inténtalo de nuevo.';
  }
}

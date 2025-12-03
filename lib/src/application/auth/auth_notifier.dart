import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:myapp/src/application/auth/auth_state.dart';
import 'package:myapp/src/data/repositories/auth_repository.dart';
import 'package:myapp/src/domain/entities/user.dart';

class AuthNotifier with ChangeNotifier {
  final AuthRepository _repository;
  final FirebaseMessaging _firebaseMessaging;

  AuthState _state = AuthLoading(); // Start in a loading state
  AuthState get state => _state;

  StreamSubscription? _authSubscription;

  AuthNotifier(this._repository, this._firebaseMessaging) {
    // Subscribe to the authentication state stream from the repository
    _authSubscription = _repository.authStateChanges.listen(_onAuthStateChanged);
  }

  // This method is the core of the new logic. It reacts to Firebase changes.
  void _onAuthStateChanged(firebase_auth.User? firebaseUser) async {
    if (firebaseUser == null) {
      _state = AuthIdle();
    } else {
      final user = await _repository.getUser(firebaseUser.uid);
      if (user != null) {
        _state = AuthSuccess(user);
        // We can save the FCM token here as well upon successful login
        _saveFCMToken(user.id);
      } else {
        // This case is unlikely but good to handle: Firebase user exists,
        // but our own user document doesn't.
        _state = AuthError("El usuario de Firebase está autenticado, pero no se encontró el perfil en la base de datos.");
        // Log out the user to prevent inconsistent state.
        await logout();
      }
    }
    notifyListeners();
  }

  Future<void> login(String identifier, String password) async {
    _state = AuthLoading();
    notifyListeners();
    try {
      // The stream will handle the AuthSuccess state automatically
      await _repository.loginUser(identifier: identifier, password: password);
    } catch (e) {
      _state = AuthError(e.toString());
      notifyListeners();
    }
  }

  Future<void> register(String email, String password, String username) async {
    _state = AuthLoading();
    notifyListeners();
    try {
      // The stream will handle the AuthSuccess state automatically
      await _repository.registerUser(email: email, password: password, username: username);
    } catch (e) {
      _state = AuthError(e.toString());
      notifyListeners();
    }
  }

  Future<void> resetPassword(String email) async {
    _state = AuthLoading();
    notifyListeners();
    try {
      await _repository.resetPassword(email: email);
      _state = PasswordResetSuccess("Se ha enviado un correo para restablecer tu contraseña.");
    } catch (e) {
      _state = AuthError(e.toString());
    }
    notifyListeners();
  }

  // Resets the state for UI purposes, e.g., after showing an error.
  void resetAuthState() {
    _state = AuthIdle();
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _repository.logout();
      // The stream will automatically set the state to AuthIdle.
    } catch (e) {
      _state = AuthError(e.toString());
      notifyListeners();
    }
  }

  void setUiError(String message) {
    _state = AuthError(message);
    notifyListeners();
  }

  Future<void> _saveFCMToken(String userId) async {
    try {
      // Request permission for notifications (important for iOS)
      await _firebaseMessaging.requestPermission();
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _repository.updateFCMToken(userId: userId, token: token);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Fallo al obtener o guardar el token FCM: $e");
      }
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

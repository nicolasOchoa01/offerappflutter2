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

  AuthState _state = AuthLoading(); 
  AuthState get state => _state;

  StreamSubscription? _authSubscription;

  AuthNotifier(this._repository, this._firebaseMessaging) {
    _authSubscription = _repository.authStateChanges.listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(firebase_auth.User? firebaseUser) async {
    if (firebaseUser == null) {
      _state = AuthIdle();
    } else {
      final user = await _repository.getUser(firebaseUser.uid);
      if (user != null) {
        _state = AuthSuccess(user);
        _saveFCMToken(user.id);
      } else {
        
        _state = AuthError("El usuario de Firebase está autenticado, pero no se encontró el perfil en la base de datos.");
        await logout();
      }
    }
    notifyListeners();
  }

  Future<void> login(String identifier, String password) async {
    _state = AuthLoading();
    notifyListeners();
    try {
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

  void resetAuthState() {
    _state = AuthIdle();
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _repository.logout();
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

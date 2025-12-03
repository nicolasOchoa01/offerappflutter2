import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:myapp/src/application/auth/auth_state.dart';
import 'package:myapp/src/data/repositories/auth_repository.dart';
import 'package:myapp/src/data/services/session_manager.dart';
import 'package:myapp/src/domain/entities/user.dart';

class AuthNotifier with ChangeNotifier {
  final AuthRepository _repository;
  final SessionManager _sessionManager;
  final FirebaseMessaging _firebaseMessaging;

  AuthState _state = AuthIdle();
  AuthState get state => _state;

  Stream<bool> get isLoggedIn => _sessionManager.isLoggedInFlow;

  AuthNotifier(
      this._repository, this._sessionManager, this._firebaseMessaging) {
    _sessionManager.isLoggedInFlow.listen((loggedIn) async {
      if (loggedIn) {
        final user = await _repository.getUser(_repository.currentUser!.uid);
        if (user != null) {
          _state = AuthSuccess(user);
        } else {
          _sessionManager.clearSession();
        }
      } else {
        _state = AuthIdle();
      }
      notifyListeners();
    });
  }

  Future<void> login(String identifier, String password) async {
    _state = AuthLoading();
    notifyListeners();
    try {
      final firebaseUser = await _repository.loginUser(
          identifier: identifier, password: password);
      if (firebaseUser != null) {
        final user = await _repository.getUser(firebaseUser.uid);
        if (user != null) {
          await _sessionManager.saveSessionState(true);
          await _saveFCMToken();
          _state = AuthSuccess(user);
        } else {
          _state = AuthError("No se pudo cargar el perfil del usuario.");
        }
      } else {
        _state = AuthError("Error al iniciar sesión");
      }
    } catch (e) {
      _state = AuthError(e.toString());
    }
    notifyListeners();
  }

  Future<void> register(
      String email, String password, String username) async {
    _state = AuthLoading();
    notifyListeners();
    try {
      final firebaseUser = await _repository.registerUser(
          email: email, password: password, username: username);
      if (firebaseUser != null) {
        final user = await _repository.getUser(firebaseUser.uid);
        if (user != null) {
          await _sessionManager.saveSessionState(true);
          await _saveFCMToken();
          _state = AuthSuccess(user);
        } else {
          _state = AuthError("No se pudo cargar el perfil del usuario.");
        }
      } else {
        _state = AuthError("Error al registrar");
      }
    } catch (e) {
      _state = AuthError(e.toString());
    }
    notifyListeners();
  }

  Future<void> resetPassword(String email) async {
    _state = AuthLoading();
    notifyListeners();
    try {
      await _repository.resetPassword(email: email);
      _state = PasswordResetSuccess(
          "Se ha enviado un correo para restablecer tu contraseña.");
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
    await _repository.logout();
    await _sessionManager.clearSession();
    _state = AuthIdle();
    notifyListeners();
  }

  void setUiError(String message) {
    _state = AuthError(message);
    notifyListeners();
  }

  Future<void> _saveFCMToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        final userId = _repository.currentUser?.uid;
        if (userId != null) {
          await _repository.updateFCMToken(userId: userId, token: token);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Fallo al obtener el token FCM: $e");
      }
    }
  }
}

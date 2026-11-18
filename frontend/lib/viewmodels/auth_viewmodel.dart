import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../services/api_client.dart';

enum AuthStatus { initializing, unauthenticated, authenticated }

/// ViewModel responsável pelo gerenciamento de estado de autenticação e sessão.
class AuthViewModel extends ChangeNotifier {
  final AuthRepository _repository;

  AuthStatus _status = AuthStatus.initializing;
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  AuthViewModel(this._repository);

  AuthStatus get status => _status;
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated && _currentUser != null;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  Future<void> initializeSession() async {
    _status = AuthStatus.initializing;
    notifyListeners();

    final user = await _repository.restoreSession();
    if (user != null) {
      _currentUser = user;
      _status = AuthStatus.authenticated;
    } else {
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login({required String email, required String senha}) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final result = await _repository.login(email: email.trim(), senha: senha);
      _currentUser = result.user;
      _status = AuthStatus.authenticated;
      _successMessage = result.message;
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Erro inesperado ao autenticar: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String nome,
    required String email,
    required String senha,
    String? cargo,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      _successMessage = await _repository.register(
        nome: nome.trim(),
        email: email.trim(),
        senha: senha,
        cargo: cargo?.trim(),
      );
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Erro inesperado ao cadastrar usuário: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshProfile() async {
    try {
      _currentUser = await _repository.refreshUser();
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    }
  }

  /// Atualiza dados pessoais, foto e preferências do próprio usuário.
  Future<bool> updateProfile(Map<String, dynamic> campos) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      _currentUser = await _repository.updateProfile(campos);
      _successMessage = 'Perfil atualizado';
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> requestPasswordRecovery({required String email}) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      _successMessage = await _repository.forgotPassword(email: email.trim());
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> confirmPasswordReset({
    required String token,
    required String novaSenha,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      _successMessage = await _repository.resetPassword(token: token, novaSenha: novaSenha);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _repository.logout();
    } catch (_) {
      await _repository.clearLocalSession();
    } finally {
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      _isLoading = false;
      _errorMessage = null;
      _successMessage = null;
      notifyListeners();
    }
  }

  void handleSessionExpired() {
    if (_status == AuthStatus.authenticated) {
      _repository.clearLocalSession();
      _currentUser = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Sua sessão expirou ou foi encerrada. Faça login novamente.';
      notifyListeners();
    }
  }
}

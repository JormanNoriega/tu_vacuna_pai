import 'package:flutter/foundation.dart';

import '../domain/entities/auth_exception.dart';
import '../domain/entities/auth_user.dart';
import '../domain/use_cases/sign_in.dart';

class AuthController extends ChangeNotifier {
  AuthController({required this._signIn});

  final SignIn _signIn;
  AuthUser? _user;
  bool _isLoading = false;
  String? _error;

  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get userName => _user?.name ?? '';

  Future<bool> signIn({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _user = await _signIn(email: email, password: password);
      return true;
    } on AuthException catch (error) {
      _error = error.message;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  void signOut() {
    _user = null;
    notifyListeners();
  }
}

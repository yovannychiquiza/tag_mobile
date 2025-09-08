import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class AuthStore extends ChangeNotifier {
  static final AuthStore _instance = AuthStore._internal();
  factory AuthStore() => _instance;
  AuthStore._internal();

  bool _isAuthenticated = false;
  bool _isLoading = false;
  Map<String, dynamic>? _user;
  String? _token;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get user => _user;
  String? get token => _token;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _isAuthenticated = await AuthService.isAuthenticated();
      if (_isAuthenticated) {
        _token = await AuthService.getToken();
        _user = await AuthService.getUser();
      }
    } catch (e) {
      _isAuthenticated = false;
      _token = null;
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await AuthService.login(username, password);
      if (success) {
        _isAuthenticated = true;
        _token = await AuthService.getToken();
        _user = await AuthService.getUser();
      }
      return success;
    } catch (e) {
      _isAuthenticated = false;
      _token = null;
      _user = null;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await AuthService.logout();
    } finally {
      _isAuthenticated = false;
      _token = null;
      _user = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearAuth() {
    _isAuthenticated = false;
    _token = null;
    _user = null;
    notifyListeners();
  }
}
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class UserAuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  bool _isLoggedIn = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _isLoggedIn;
  bool get isAdmin => _currentUser?.isAdmin ?? false;
  bool get isManager => _currentUser?.isManager ?? false;

  void login() {
    _isLoggedIn = true;
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    clear();
  }

  Future<void> loadCurrentUser(String userId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await AuthService().getUserData(userId);
      if (data != null) {
        _currentUser = UserModel.fromFirestore(data, userId);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile(String name) async {
    try {
      await AuthService().updateUserProfile(name: name);
      if (_currentUser != null) {
        _currentUser = UserModel(
          id: _currentUser!.id,
          name: name,
          email: _currentUser!.email,
          role: _currentUser!.role,
          createdAt: _currentUser!.createdAt,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clear() {
    _currentUser = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}

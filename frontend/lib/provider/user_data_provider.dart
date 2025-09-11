import 'package:flutter/material.dart';
import 'package:frontend/controllers/user_details_controller.dart';
import 'package:frontend/models/user_model.dart';

class UserProvider extends ChangeNotifier {
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchUserDetails(String emailId, String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      User fetchedUser = await UserDetailController.getUserDetails(emailId, token);
      _user = fetchedUser;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearUser() {
    _user = null;
    notifyListeners();
  }
}

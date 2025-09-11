import 'package:frontend/models/user_model.dart';

class LoginResponse {
  final String token;
  final User user;
  final String message;

  LoginResponse({required this.token, required this.user, required this.message});

  factory LoginResponse.fromJson(Map<String, dynamic> json){
    return LoginResponse(token: json['token'] ?? '',
        user: User.fromJson(json['user']),
        message: json['message'] ?? '',
    );
  }
}
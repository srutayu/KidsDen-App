
import 'package:frontend/constants/url.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend/models/login_response.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


class AuthController {
  static final _baseURL = URL.baseURL;

  static Future<bool>register(String name, String email, String password, String role) async {
    final url = Uri.parse('$_baseURL/auth/register');
    final response = await http.post(url,
      headers: {'Content-Type':'application/json'},
      body: jsonEncode({
        "name":name, "email":email,"password":password, "role":role
      })
    );
    // Map<String, dynamic> jsonMap = json.decode(response.body);

    if(response.statusCode == 201){
      return true;
    } else {
      throw Exception(
        response.body.isNotEmpty ? response.body : "Registration failed",
      );
    }
  }

  static Future<LoginResponse?>login(String email, String password) async {
    final url = Uri.parse('$_baseURL/auth/login');
    final response = await http.post(url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"email": email, "password": password})
    );

    if (response.statusCode == 200) {
      Map<String, dynamic> jsonMap = json.decode(response.body);
      if (jsonMap.containsKey('token') && jsonMap.containsKey('user')) {
        return LoginResponse.fromJson(jsonMap);
      } else if (jsonMap.containsKey('message')) {
        // Handle error message (e.g., user already logged in)
    debugPrint('Login error: ${jsonMap['message']}');
        // You can throw an exception or return null, or wrap in a result type
        return null;
      }
    }
    else if (response.statusCode == 401) {
      Map<String, dynamic> jsonMap = json.decode(response.body);
      final errorMessage = jsonMap['message'] ?? 'Login failed';
      throw Exception(errorMessage);
    }

  debugPrint('Unexpected response or error: ${response.statusCode} ${response.body}');
    return null;
  }

  static Future<bool>logout(String token) async {
    final url = Uri.parse('$_baseURL/auth/logout');
    final response = await http.post(url,
    headers: {
      'Content-Type':'application/json',
      'Authorization': 'Bearer $token'
    });
    // print(token);
    Map<String, dynamic> jsonMap = json.decode(response.body);
    if(response.statusCode == 200){
      return true;
    } else {
      print("Logout Error: ${jsonMap['message']}");
      return false;
    }
  }
  
  static Future<bool> checkIfAproved(email) async {
    final url = Uri.parse('$_baseURL/auth/check-approval?email=$email');
    final response = await http.get(url,
        headers: {'Content-Type': 'application/json'},
    );

    if(response.statusCode == 200){
      final data = jsonDecode(response.body);
      bool isApproved = data['isApproved'];
      return isApproved;
    } else {
      throw Exception("Failed to load approval status");
    }
  }

  static Future<String> getRole(String token) async {
    final url = Uri.parse('$_baseURL/get-role');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token', 
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final role = (data['role']);
      return role;
    }
    else {
      throw Exception("Failed to fetch login date");
    }
  }
}
